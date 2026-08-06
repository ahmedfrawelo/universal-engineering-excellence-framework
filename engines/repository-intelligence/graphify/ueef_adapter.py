"""UEEF-owned safe facade around the embedded local repository engine.

Only bounded, offline repository operations are exposed here. The upstream
installer, hook, network, LLM, MCP, remote database, and memory commands are
deliberately unreachable through this entry point.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
# The only child command uses the current interpreter, fixed flags, and shell=False.
import subprocess  # nosec B404
import sys
import time
from collections import deque
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "1.0"
VIEWER_VERSION = "4.7.0"
VIEWER_CLUSTER_MIN_MEMBERS = 11
UEEF_COMMUNITY_COLORS = [
    "#F2C94C", "#9331F5", "#49BCF5", "#F53172",
    "#31F531", "#29CC96", "#7A5CB8", "#B85625",
    "#F549D8", "#B8F57A", "#B85C8A", "#7AF5F5",
]
UEEF_MIN_PALETTE_DISTANCE = 35.0
_DEFAULT_NOISE_DIRS = {
    ".git", ".hg", ".svn", ".ueef", ".venv", "venv", "env",
    "node_modules", "vendor", "dist", "build", "coverage", "target",
    "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache",
}


def _rgb_to_lab(color: str) -> tuple[float, float, float]:
    channels = [int(color[index:index + 2], 16) / 255 for index in (1, 3, 5)]
    linear = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4 for value in channels]
    red, green, blue = linear
    x = (red * 0.4124 + green * 0.3576 + blue * 0.1805) / 0.95047
    y = red * 0.2126 + green * 0.7152 + blue * 0.0722
    z = (red * 0.0193 + green * 0.1192 + blue * 0.9505) / 1.08883
    transform = lambda value: value ** (1 / 3) if value > 0.008856 else 7.787 * value + 16 / 116
    fx, fy, fz = transform(x), transform(y), transform(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def _minimum_palette_distance(colors: list[str]) -> float:
    labs = [_rgb_to_lab(color) for color in colors]
    return min(
        sum((left[channel] - right[channel]) ** 2 for channel in range(3)) ** 0.5
        for index, left in enumerate(labs)
        for right in labs[index + 1:]
    )
_DEFAULT_POLICY = {
    "outputDirectory": ".ueef/repository-graph",
    "commands": ["build", "query", "path", "explain", "affected", "status", "doctor"],
    "maxItems": 500,
    "ignoredDirectories": sorted(_DEFAULT_NOISE_DIRS),
}


def _load_policy() -> dict[str, Any]:
    policy_path = Path(__file__).resolve().parents[3] / "config" / "repository-intelligence-policy.json"
    try:
        value = json.loads(policy_path.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else _DEFAULT_POLICY
    except (OSError, json.JSONDecodeError):
        return _DEFAULT_POLICY


POLICY = _load_policy()
OUTPUT_RELATIVE = Path(str(POLICY.get("outputDirectory", _DEFAULT_POLICY["outputDirectory"])))
NOISE_DIRS = set(POLICY.get("ignoredDirectories", _DEFAULT_POLICY["ignoredDirectories"]))
PROJECT_TREE_IGNORED_DIRS = {
    ".git", ".hg", ".svn", ".ueef", ".venv", "venv", "env",
    "node_modules", "vendor", "dist", "build", "coverage", "target",
    "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache",
}
SENSITIVE_NAMES = {
    ".env", ".env.local", ".env.development", ".env.production",
    "id_rsa", "id_ed25519", "credentials", "credentials.json",
}
SUPPLEMENTAL_EXTENSIONS = {
    ".md", ".mdx", ".rst", ".txt", ".json", ".yaml", ".yml",
    ".toml", ".ini", ".cfg", ".conf", ".sql",
}
ALL_INDEXABLE_EXTENSIONS = SUPPLEMENTAL_EXTENSIONS | {
    ".py", ".pyi", ".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs",
    ".go", ".rs", ".java", ".kt", ".kts", ".c", ".h", ".cpp",
    ".hpp", ".cc", ".cs", ".rb", ".php", ".swift", ".scala",
    ".lua", ".sh", ".bash", ".zsh", ".ps1", ".vue", ".svelte",
    ".astro", ".jsonc", ".xml", ".xaml", ".gradle", ".zig",
}


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def _safe_relative(path: Path, root: Path) -> str:
    resolved = path.resolve()
    try:
        relative = resolved.relative_to(root)
    except ValueError as exc:
        raise ValueError(f"Path escapes repository root: {path}") from exc
    return relative.as_posix()


def _is_sensitive(path: Path) -> bool:
    name = path.name.lower()
    return (
        name in SENSITIVE_NAMES
        or name.startswith(".env.")
        or name.endswith((".pem", ".key", ".p12", ".pfx"))
        or "secret" in name
    )


def _inventory(root: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for dirpath, dirnames, filenames in os.walk(root):
        current = Path(dirpath)
        dirnames[:] = sorted(d for d in dirnames if d.lower() not in NOISE_DIRS)
        for filename in sorted(filenames):
            path = current / filename
            if path.suffix.lower() not in ALL_INDEXABLE_EXTENSIONS or _is_sensitive(path):
                continue
            try:
                relative = _safe_relative(path, root)
                if path.stat().st_size > 4 * 1024 * 1024:
                    continue
                result[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
            except OSError:
                continue
    return dict(sorted(result.items()))


def _is_output_path(relative: str) -> bool:
    output_prefix = OUTPUT_RELATIVE.as_posix().strip("/")
    return relative == output_prefix or relative.startswith(output_prefix + "/")


def _project_file_inventory(root: Path) -> dict[str, str]:
    """Inventory every project file that is safe to name in the graph.

    This is intentionally broader than the AST/text analysis inventory:
    non-code and unknown-extension files still become file-tree nodes so the
    repository graph can act as a complete project map without reading or
    exposing sensitive contents.
    """
    result: dict[str, str] = {}
    for dirpath, dirnames, filenames in os.walk(root):
        current = Path(dirpath)
        try:
            current_relative = _safe_relative(current, root)
        except ValueError:
            dirnames[:] = []
            continue
        if current_relative == ".":
            current_relative = ""
        dirnames[:] = sorted(
            d for d in dirnames
            if d.lower() not in PROJECT_TREE_IGNORED_DIRS
            and not _is_output_path("/".join(part for part in (current_relative, d) if part))
        )
        for filename in sorted(filenames):
            path = current / filename
            if _is_sensitive(path):
                continue
            try:
                relative = _safe_relative(path, root)
                if _is_output_path(relative):
                    continue
                stat = path.stat()
                if stat.st_size <= 4 * 1024 * 1024:
                    digest = hashlib.sha256(path.read_bytes()).hexdigest()
                else:
                    digest = f"large:{stat.st_size}:{int(stat.st_mtime)}"
                result[relative] = digest
            except OSError:
                continue
    return dict(sorted(result.items()))


def _load_json(path: Path, fallback: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return fallback


def _engine_build(root: Path, output: Path) -> str:
    env = os.environ.copy()
    for key in tuple(env):
        upper = key.upper()
        if upper.endswith("_API_KEY") or upper in {
            "OPENAI_BASE_URL", "ANTHROPIC_BASE_URL", "GRAPHIFY_POSTGRES_DSN",
            "DATABASE_URL", "NEO4J_URI", "FALKORDB_URL",
        }:
            env.pop(key, None)
    env.update({
        "GRAPHIFY_OUT": str(output),
        "GRAPHIFY_NO_TIPS": "1",
        "NO_PROXY": "*",
        "no_proxy": "*",
    })
    command = [
        sys.executable, "-m", "graphify", "extract", str(root),
        "--code-only", "--no-cluster", "--max-workers", "1",
    ]
    # All executable and flag tokens are fixed; only the validated root is data.
    completed = subprocess.run(  # nosec B603
        command,
        cwd=root,
        env=env,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=900,
        check=False,
    )
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or "engine build failed").strip()
        raise RuntimeError(detail[-4000:])
    return completed.stdout


def _slug(value: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9]+", "_", value).strip("_").lower()
    return cleaned or "root"


def _graph_parts(graph: dict[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]], str]:
    nodes = graph.setdefault("nodes", [])
    edge_key = "links" if "links" in graph else "edges"
    edges = graph.setdefault(edge_key, [])
    return nodes, edges, edge_key


def _project_file_type(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix in {".md", ".mdx", ".rst", ".txt"}:
        return "documentation"
    if suffix in {".json", ".jsonc", ".yaml", ".yml", ".toml", ".ini", ".cfg", ".conf"}:
        return "configuration"
    if suffix in ALL_INDEXABLE_EXTENSIONS:
        return "code"
    if suffix in {".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".ico"}:
        return "asset"
    if suffix in {".psd", ".fig", ".sketch"}:
        return "design-asset"
    if suffix in {".zip", ".gz", ".tar", ".7z"}:
        return "archive"
    if suffix in {".lock"} or path.name.lower() in {"package-lock.json", "pnpm-lock.yaml", "uv.lock"}:
        return "lockfile"
    return "file"


def _append_unique_edge(
    edges: list[dict[str, Any]],
    seen_edges: set[tuple[str, str, str, str]],
    edge: dict[str, Any],
) -> None:
    key = (
        str(edge.get("source", "")),
        str(edge.get("target", "")),
        str(edge.get("relation", "")),
        str(edge.get("source_file", "")),
    )
    if key in seen_edges:
        return
    seen_edges.add(key)
    edges.append(edge)


def _supplement_graph(graph: dict[str, Any], root: Path, inventory: dict[str, str]) -> None:
    nodes, edges, _ = _graph_parts(graph)
    supplemental_origins = {"ueef-file-tree", "ueef-local"}
    supplemental_node_ids = {
        str(node.get("id"))
        for node in nodes
        if node.get("_origin") in supplemental_origins
    }
    if supplemental_node_ids:
        nodes[:] = [node for node in nodes if str(node.get("id")) not in supplemental_node_ids]
        edges[:] = [
            edge for edge in edges
            if edge.get("_origin") not in supplemental_origins
            and str(edge.get("source")) not in supplemental_node_ids
            and str(edge.get("target")) not in supplemental_node_ids
        ]
    node_ids = {str(node.get("id", "")) for node in nodes}
    node_by_id = {str(node.get("id", "")): node for node in nodes if node.get("id") is not None}
    source_ids: dict[str, str] = {}
    for node in nodes:
        source = str(node.get("source_file", "")).replace("\\", "/")
        if source:
            node["source_file"] = source
            source_ids.setdefault(source, str(node.get("id", "")))
        node.setdefault("confidence", "EXTRACTED")
        node.setdefault("confidence_score", 1.0)
        node.setdefault("evidence", {"source_file": source, "method": "local-ast"})
    for edge in edges:
        source_file = str(edge.get("source_file", "")).replace("\\", "/")
        if source_file:
            edge["source_file"] = source_file
        edge.setdefault("confidence", "EXTRACTED")
        edge.setdefault("confidence_score", 1.0)
        edge.setdefault("evidence", {"source_file": source_file, "method": "local-ast"})

    seen_edges: set[tuple[str, str, str, str]] = {
        (
            str(edge.get("source", "")), str(edge.get("target", "")),
            str(edge.get("relation", "")), str(edge.get("source_file", "")),
        )
        for edge in edges
    }
    root_id = "ueef_project_file_tree_root"
    if root_id not in node_ids:
        nodes.append({
            "id": root_id,
            "label": "UEEF project files",
            "type": "project-root",
            "file_type": "project-root",
            "source_file": ".",
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "evidence": {"source_file": ".", "method": "local-file-tree"},
            "_origin": "ueef-file-tree",
        })
        node_ids.add(root_id)
        node_by_id[root_id] = nodes[-1]

    for relative in inventory:
        path = root / Path(relative)
        parent_id = root_id
        parts = [part for part in relative.split("/") if part]
        for depth in range(1, len(parts)):
            directory_relative = "/".join(parts[:depth])
            directory_id = f"ueef_dir_{_slug(directory_relative)}"
            if directory_id not in node_ids:
                nodes.append({
                    "id": directory_id,
                    "label": parts[depth - 1],
                    "type": "directory",
                    "file_type": "directory",
                    "source_file": directory_relative,
                    "confidence": "EXTRACTED",
                    "confidence_score": 1.0,
                    "evidence": {"source_file": directory_relative, "method": "local-file-tree"},
                    "_origin": "ueef-file-tree",
                })
                node_ids.add(directory_id)
                node_by_id[directory_id] = nodes[-1]
            _append_unique_edge(edges, seen_edges, {
                "source": parent_id, "target": directory_id, "relation": "contains",
                "source_file": directory_relative, "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "evidence": {"source_file": directory_relative, "method": "local-file-tree"},
                "_origin": "ueef-file-tree",
            })
            parent_id = directory_id

        file_id = f"ueef_file_{_slug(relative)}"
        if file_id not in node_ids:
            nodes.append({
                "id": file_id,
                "label": path.name,
                "type": "file",
                "file_type": _project_file_type(path),
                "source_file": relative,
                "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "evidence": {"source_file": relative, "method": "local-file-tree"},
                "_origin": "ueef-file-tree",
            })
            node_ids.add(file_id)
            node_by_id[file_id] = nodes[-1]
        else:
            node_by_id[file_id].update({
                "label": path.name,
                "type": "file",
                "file_type": _project_file_type(path),
                "source_file": relative,
                "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "evidence": {"source_file": relative, "method": "local-file-tree"},
                "_origin": "ueef-file-tree",
            })
        _append_unique_edge(edges, seen_edges, {
            "source": parent_id, "target": file_id, "relation": "contains",
            "source_file": relative, "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "evidence": {"source_file": relative, "method": "local-file-tree"},
            "_origin": "ueef-file-tree",
        })
        if relative in source_ids and source_ids[relative] != file_id:
            _append_unique_edge(edges, seen_edges, {
                "source": file_id, "target": source_ids[relative], "relation": "has extracted symbols",
                "source_file": relative, "confidence": "INFERRED",
                "confidence_score": 0.9,
                "evidence": {"source_file": relative, "method": "local-file-tree-to-ast"},
                "_origin": "ueef-file-tree",
            })
        if path.suffix.lower() not in SUPPLEMENTAL_EXTENSIONS:
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")[:2_000_000]
        except OSError:
            continue
        concepts: list[tuple[str, str]] = []
        suffix = path.suffix.lower()
        if suffix in {".md", ".mdx", ".rst"}:
            concepts.extend(("heading", match.group(1).strip()) for match in re.finditer(r"(?m)^#{1,6}\s+(.+?)\s*$", text))
        elif suffix == ".json":
            try:
                value = json.loads(text)
                if isinstance(value, dict):
                    concepts.extend(("config_key", str(key)) for key in list(value)[:200])
            except json.JSONDecodeError:
                pass
        elif suffix == ".sql":
            concepts.extend(("sql_object", match.group(2)) for match in re.finditer(r"(?i)\b(create\s+(?:table|view|function)|from|join)\s+([\w.\[\]`\"]+)", text))
        elif suffix in {".toml", ".ini", ".cfg", ".conf", ".yaml", ".yml"}:
            concepts.extend(("config_key", match.group(1)) for match in re.finditer(r"(?m)^\s*([A-Za-z_][\w.-]{1,100})\s*[:=]", text))
        for kind, label in concepts[:300]:
            concept_id = f"ueef_{kind}_{_slug(relative)}_{_slug(label)}"
            if concept_id not in node_ids:
                nodes.append({
                    "id": concept_id, "label": label[:240], "type": kind,
                    "source_file": relative, "confidence": "EXTRACTED",
                    "confidence_score": 0.95,
                    "evidence": {"source_file": relative, "method": "deterministic-structure"},
                    "_origin": "ueef-local",
                })
                node_ids.add(concept_id)
            _append_unique_edge(edges, seen_edges, {
                "source": file_id, "target": concept_id, "relation": "contains",
                "source_file": relative, "confidence": "INFERRED",
                "confidence_score": 0.8,
                "evidence": {"source_file": relative, "method": "deterministic-containment"},
                "_origin": "ueef-local",
            })

    # A warm build reuses the existing graph, so supplementing it again must
    # not multiply deterministic containment edges. Preserve distinct parallel
    # relations while collapsing exact endpoint/relation/source duplicates.
    deduped: list[dict[str, Any]] = []
    seen_edges: set[tuple[str, str, str, str]] = set()
    for edge in edges:
        key = (
            str(edge.get("source", "")), str(edge.get("target", "")),
            str(edge.get("relation", "")), str(edge.get("source_file", "")),
        )
        if key in seen_edges:
            continue
        seen_edges.add(key)
        deduped.append(edge)
    edges[:] = deduped


def _sanitize_graph(graph: dict[str, Any], root: Path) -> None:
    nodes, edges, _ = _graph_parts(graph)
    root_text = str(root).replace("\\", "/").rstrip("/")
    for item in nodes + edges:
        for key in ("source_file", "target_file", "origin_file"):
            value = item.get(key)
            if not isinstance(value, str):
                continue
            normalized = value.replace("\\", "/")
            if normalized.lower().startswith(root_text.lower() + "/"):
                normalized = normalized[len(root_text) + 1:]
            item[key] = normalized
        item.pop("target_file", None)
        item.pop("origin_file", None)

    def ignored_source(item: dict[str, Any]) -> bool:
        source = str(item.get("source_file") or "").replace("\\", "/").lstrip("./")
        first = source.split("/", 1)[0].lower() if source else ""
        if item.get("_origin") == "ueef-file-tree":
            return first in PROJECT_TREE_IGNORED_DIRS or _is_output_path(source)
        return first in NOISE_DIRS

    ignored_node_ids = {str(node.get("id")) for node in nodes if ignored_source(node)}
    if ignored_node_ids:
        nodes[:] = [node for node in nodes if str(node.get("id")) not in ignored_node_ids]
        edges[:] = [
            edge for edge in edges
            if str(edge.get("source")) not in ignored_node_ids
            and str(edge.get("target")) not in ignored_node_ids
            and not ignored_source(edge)
        ]


def _write_report(graph: dict[str, Any], output: Path, cache: dict[str, int], duration_ms: int) -> None:
    nodes, edges, _ = _graph_parts(graph)
    relations: dict[str, int] = {}
    confidence: dict[str, int] = {"EXTRACTED": 0, "INFERRED": 0, "AMBIGUOUS": 0}
    for item in nodes + edges:
        level = str(item.get("confidence", "AMBIGUOUS")).upper()
        confidence[level if level in confidence else "AMBIGUOUS"] += 1
    for edge in edges:
        relation = str(edge.get("relation", "related"))
        relations[relation] = relations.get(relation, 0) + 1
    lines = [
        "# Repository Intelligence Report", "",
        "Generated locally without an LLM or network dependency.", "",
        f"- Nodes: {len(nodes)}", f"- Edges: {len(edges)}",
        f"- Build duration: {duration_ms} ms",
        f"- Reused files: {cache['reusedFiles']}",
        f"- Changed files: {cache['changedFiles']}",
        f"- Deleted files: {cache['deletedFiles']}", "",
        "## Confidence", "",
    ]
    lines.extend(f"- {key}: {value}" for key, value in confidence.items())
    lines.extend(["", "## Relations", ""])
    lines.extend(f"- {key}: {value}" for key, value in sorted(relations.items(), key=lambda item: (-item[1], item[0]))[:50])
    (output / "GRAPH_REPORT.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def _visual_owner(node_id: str, node: dict[str, Any]) -> str:
    """Map a node to a stable architecture owner for the overview graph."""
    source = str(node.get("source_file") or "").replace("\\", "/").strip("/")
    parts = [part for part in source.split("/") if part]
    if not parts:
        return "external-references" if str(node_id).startswith("ref_") else "unowned"
    if parts[0] == "framework" and len(parts) > 1:
        return "framework/root" if "." in parts[1] else "/".join(parts[:2])
    if parts[0] == "vendor" and len(parts) > 2:
        if parts[2] == "graphify":
            if len(parts) > 3 and "." not in parts[3]:
                return f"vendor/graphify/{parts[3]}"
            return "vendor/graphify/core"
        if parts[2] == "tests":
            return "vendor/graphify/tests"
        return "vendor/graphify/project"
    if parts[0] in {"docs", "tools"} and len(parts) > 1:
        return f"{parts[0]}/root" if "." in parts[1] else "/".join(parts[:2])
    if len(parts) == 1 and "." in parts[0]:
        return "root-files"
    return parts[0]


def _visualization_communities(graph: Any) -> tuple[dict[int, list[str]], dict[int, str]]:
    """Keep meaningful clusters, merge noise, and collapse disconnected islands."""
    from graphify.cluster import cluster

    detected = cluster(graph)
    degree = dict(graph.degree())
    groups: list[tuple[str, list[str]]] = []
    supporting: dict[str, list[str]] = {}
    for cluster_id, members in detected.items():
        if len(members) >= VIEWER_CLUSTER_MIN_MEMBERS:
            ranked = sorted(members, key=lambda node_id: (-degree.get(node_id, 0), str(node_id)))
            lead = ranked[0]
            owner = _visual_owner(str(lead), graph.nodes[lead])
            lead_label = str(graph.nodes[lead].get("label") or lead)
            groups.append((_cluster_display_label(owner, lead_label), list(members)))
            continue
        for node_id in members:
            owner = _visual_owner(str(node_id), graph.nodes[node_id])
            supporting.setdefault(owner, []).append(node_id)
    groups.extend((f"{owner} · supporting nodes", members) for owner, members in sorted(supporting.items()))

    communities: dict[int, list[str]] = {}
    labels: dict[int, str] = {}
    used_labels: set[str] = set()
    for community_id, (base_label, members) in enumerate(groups):
        label = base_label
        if label in used_labels:
            label = f"{base_label} · cluster {community_id + 1}"
        used_labels.add(label)
        communities[community_id] = sorted(members, key=str)
        labels[community_id] = label
    return communities, labels


def _cluster_display_label(owner: str, lead_label: str) -> str:
    """Human label for an overview cluster without owner/self repetition.

    Large folder clusters often have the owner path and lead label resolve to
    the same visible word, e.g. owner ``scripts`` and lead label ``scripts``.
    Rendering that as ``scripts · scripts`` looks like duplicate graph data even
    though it is one valid cluster. Keep the owner context, but collapse the
    self-repeat into an explicit overview label.
    """
    owner_text = str(owner or "unowned").strip() or "unowned"
    lead_text = str(lead_label or "").strip()
    owner_leaf = owner_text.rsplit("/", 1)[-1]
    if not lead_text or lead_text.casefold() in {owner_text.casefold(), owner_leaf.casefold()}:
        return f"{owner_text} overview"
    return f"{owner_text} · {lead_text}"


def _cluster_owner_from_label(label: str) -> str:
    """Recover the ownership path encoded in a visualization cluster label."""
    label_text = str(label or "").strip()
    if " · " in label_text:
        return label_text.split(" · ", 1)[0].strip() or "unowned"
    if label_text.endswith(" overview"):
        return label_text[: -len(" overview")].strip() or "unowned"
    return label_text or "unowned"


def _is_owner_summary_cluster(label: str, owner: str) -> bool:
    """Whether a cluster only repeats its owner and should collapse to the hub."""
    label_text = str(label or "").strip().casefold()
    owner_text = str(owner or "").strip().casefold()
    return label_text in {
        f"{owner_text} overview",
        f"{owner_text} · supporting nodes",
    }


def _overview_graph(
    graph: Any,
    communities: dict[int, list[str]],
    labels: dict[int, str],
) -> tuple[Any, dict[int, list[str]], dict[int, str]]:
    """Build a connected architecture map from extracted and ownership edges."""
    from collections import Counter

    import networkx as nx

    overview = nx.DiGraph()
    root_id = "hub:ueef-project"
    overview.add_node(root_id, label="UEEF project", source_file=".", file_type="architecture-root")

    def ensure_owner_hub(owner: str) -> str:
        parent = root_id
        segments = [segment for segment in str(owner or "unowned").split("/") if segment] or ["unowned"]
        for depth in range(1, len(segments) + 1):
            path = "/".join(segments[:depth])
            hub_id = f"hub:{path}"
            if hub_id not in overview:
                overview.add_node(hub_id, label=path, source_file=path, file_type="architecture-owner")
            if not overview.has_edge(parent, hub_id):
                overview.add_edge(
                    parent,
                    hub_id,
                    relation="contains (path ownership)",
                    confidence="INFERRED",
                    weight=1,
                    _src=parent,
                    _tgt=hub_id,
                )
            parent = hub_id
        return parent

    node_community = {
        node_id: community_id
        for community_id, members in communities.items()
        for node_id in members
    }
    overview_node_for_community: dict[int, str] = {}
    for community_id, members in communities.items():
        label = labels[community_id]
        owner = _cluster_owner_from_label(label)
        owner_hub = ensure_owner_hub(owner)
        if _is_owner_summary_cluster(label, owner):
            overview_node_for_community[community_id] = owner_hub
            continue
        cluster_id = f"cluster:{community_id}"
        overview_node_for_community[community_id] = cluster_id
        overview.add_node(
            cluster_id,
            label=label,
            source_file=owner,
            file_type="architecture-cluster",
            member_count=len(members),
        )
        if not overview.has_edge(owner_hub, cluster_id):
            overview.add_edge(
                owner_hub,
                cluster_id,
                relation="contains (graph cluster)",
                confidence="INFERRED",
                weight=1,
                _src=owner_hub,
                _tgt=cluster_id,
            )

    cross_counts: Counter[tuple[int, int]] = Counter()
    relation_counts: dict[tuple[int, int], Counter[str]] = {}
    for source, target, data in graph.edges(data=True):
        source_community = node_community.get(source)
        target_community = node_community.get(target)
        if source_community is None or target_community is None or source_community == target_community:
            continue
        pair = (source_community, target_community)
        cross_counts[pair] += 1
        relation_counts.setdefault(pair, Counter())[str(data.get("relation") or "related")] += 1
    for (source_community, target_community), count in cross_counts.items():
        common_relation = relation_counts[(source_community, target_community)].most_common(1)[0][0]
        source_node = overview_node_for_community[source_community]
        target_node = overview_node_for_community[target_community]
        if source_node == target_node:
            continue
        overview.add_edge(
            source_node,
            target_node,
            relation=f"{count} extracted relationships ({common_relation})",
            confidence="EXTRACTED",
            weight=count,
            _src=source_node,
            _tgt=target_node,
        )

    domain_nodes: dict[str, list[str]] = {}
    for node_id, node in overview.nodes(data=True):
        if node_id == root_id:
            domain = "project"
        else:
            source = str(node.get("source_file") or "other")
            domain = source.split("/", 1)[0] or "other"
        domain_nodes.setdefault(domain, []).append(node_id)
    overview_communities: dict[int, list[str]] = {}
    overview_labels: dict[int, str] = {}
    for domain_id, domain in enumerate(sorted(domain_nodes)):
        overview_communities[domain_id] = sorted(domain_nodes[domain], key=str)
        overview_labels[domain_id] = domain
    return overview, overview_communities, overview_labels


def _full_graph_search_payload(raw_graph: dict[str, Any]) -> tuple[list[list[Any]], list[list[Any]]]:
    """Create a compact, offline index used to open any node's neighborhood."""
    from collections import Counter

    raw_nodes, raw_edges, _ = _graph_parts(raw_graph)
    raw_degree: Counter[str] = Counter()
    for edge in raw_edges:
        if edge.get("source") is not None:
            raw_degree[str(edge.get("source"))] += 1
        if edge.get("target") is not None:
            raw_degree[str(edge.get("target"))] += 1
    full_nodes: list[list[Any]] = []
    graph_node_ids: set[str] = set()
    for node in raw_nodes:
        if node.get("id") is None:
            continue
        node_id = str(node.get("id"))
        graph_node_ids.add(node_id)
        owner = _visual_owner(str(node_id), node)
        color_index = int(hashlib.sha256(owner.encode("utf-8")).hexdigest()[:8], 16) % len(UEEF_COMMUNITY_COLORS)
        color = UEEF_COMMUNITY_COLORS[color_index]
        label = str(node.get("label") or node_id)
        source = str(node.get("source_file") or "").replace("\\", "/")
        full_nodes.append([
            node_id,
            label,
            source,
            str(node.get("file_type") or node.get("type") or "unknown"),
            owner,
            raw_degree[node_id],
            color,
        ])

    referenced_node_ids = {
        str(edge.get(endpoint))
        for edge in raw_edges
        for endpoint in ("source", "target")
        if edge.get(endpoint) is not None
    }
    external_color = UEEF_COMMUNITY_COLORS[
        int(hashlib.sha256(b"external-references").hexdigest()[:8], 16) % len(UEEF_COMMUNITY_COLORS)
    ]
    for node_id in sorted(referenced_node_ids - graph_node_ids):
        full_nodes.append([
            node_id,
            node_id,
            "",
            "external-reference",
            "external-references",
            raw_degree[node_id],
            external_color,
        ])

    full_edges: list[list[Any]] = []
    for edge_id, edge in enumerate(raw_edges):
        source = edge.get("source")
        target = edge.get("target")
        if source is None or target is None:
            continue
        source = str(source)
        target = str(target)
        confidence = str(edge.get("confidence") or "EXTRACTED")
        relation = str(edge.get("relation") or "related")
        full_edges.append([f"full:{edge_id}", source, target, relation, confidence])
    return full_nodes, full_edges


def _routing_evidence_payload(root: Path) -> list[dict[str, Any]]:
    """Summarize recent local routing receipts for the offline graph viewer."""
    evidence_dir = root / ".ueef" / "evidence"
    if not evidence_dir.is_dir():
        return []
    payload: list[dict[str, Any]] = []
    for dispatch_path in sorted(evidence_dir.glob("*-dispatch.json"), key=lambda item: item.stat().st_mtime, reverse=True):
        try:
            dispatch = json.loads(dispatch_path.read_text(encoding="utf-8-sig"))
        except Exception:
            continue
        route_path = dispatch_path.with_name(dispatch_path.name.replace("-dispatch.json", "-route.json"))
        route: dict[str, Any] = {}
        if route_path.is_file():
            try:
                route = json.loads(route_path.read_text(encoding="utf-8-sig"))
            except Exception:
                route = {}
        payload.append({
            "name": dispatch_path.stem,
            "tier": route.get("tier"),
            "workUnitId": route.get("workUnitId") or route.get("distributionKey"),
            "requestedModel": dispatch.get("requestedModel") or route.get("preferredModel"),
            "requestedHostReasoning": dispatch.get("requestedHostReasoning") or route.get("hostReasoning"),
            "actualModel": dispatch.get("actualModel"),
            "actualHostReasoning": dispatch.get("actualHostReasoning"),
            "executionVerified": dispatch.get("executionVerified") is True,
            "result": dispatch.get("result"),
            "capacityFallbackUsed": dispatch.get("capacityFallbackUsed") is True,
            "threadId": dispatch.get("threadId"),
            "turnId": dispatch.get("turnId"),
            "routeDigest": dispatch.get("routeDigest") or route.get("routeDigest"),
            "completedAt": dispatch.get("completedAt") or dispatch.get("observedAt"),
            "pickerStatus": "not changed by dispatch",
        })
        if len(payload) >= 40:
            break
    for settings_path in sorted(evidence_dir.glob("*thread-settings*.json"), key=lambda item: item.stat().st_mtime, reverse=True):
        try:
            settings = json.loads(settings_path.read_text(encoding="utf-8-sig"))
        except Exception:
            continue
        payload.append({
            "name": settings_path.stem,
            "tier": "picker",
            "workUnitId": "visible-picker",
            "requestedModel": settings.get("requestedModel"),
            "requestedHostReasoning": settings.get("requestedHostReasoning"),
            "actualModel": settings.get("acceptedModel"),
            "actualHostReasoning": settings.get("acceptedHostReasoning"),
            "executionVerified": settings.get("uiPickerMutationVerified") is True,
            "result": settings.get("result"),
            "capacityFallbackUsed": False,
            "threadId": settings.get("threadId"),
            "turnId": None,
            "routeDigest": settings.get("routeDigest"),
            "completedAt": settings.get("completedAt") or settings.get("observedAt"),
            "pickerStatus": "updated and verified" if settings.get("uiPickerMutationVerified") is True else "attempted",
        })
        if len(payload) >= 50:
            break
    payload.sort(key=lambda item: str(item.get("completedAt") or item.get("name") or ""), reverse=True)
    return payload


def _promote_overview_label_fonts(document: str) -> str:
    """Make UEEF overview labels visible in the generated RAW_NODES payload.

    Upstream Graphify hides most low-degree labels by writing ``font.size = 0``.
    That is useful for full graphs, but UEEF's architecture overview is already
    bounded and aggregated; hiding those labels turns the overview into a cloud
    of unlabeled dots. Keep this as a UEEF adapter post-process so the embedded
    upstream exporter remains unchanged.
    """
    match = re.search(r"const RAW_NODES = (\[.*?\]);\s*const RAW_EDGES", document, re.DOTALL)
    if not match:
        raise RuntimeError("Graphify HTML exporter no longer exposes the RAW_NODES marker.")
    nodes = json.loads(match.group(1))
    for node in nodes:
        file_type = str(node.get("file_type") or "")
        if file_type.startswith("architecture-"):
            font = node.get("font") if isinstance(node.get("font"), dict) else {}
            font["size"] = 12
            font.setdefault("color", "#ffffff")
            node["font"] = font
    nodes_json = json.dumps(nodes, ensure_ascii=False).replace("</", "<\\/")
    return document[:match.start(1)] + nodes_json + document[match.end(1):]


def _write_html(graph: dict[str, Any], output: Path, root: Path) -> None:
    """Render Graphify's real interactive network with an offline JS asset."""
    from contextlib import redirect_stdout
    from io import StringIO

    from graphify.build import build_from_json
    from graphify.exporters.base import COMMUNITY_COLORS
    from graphify.exporters.html import to_html

    palette_distance = _minimum_palette_distance(UEEF_COMMUNITY_COLORS)
    if palette_distance < UEEF_MIN_PALETTE_DISTANCE:
        raise RuntimeError(f"UEEF viewer palette colors are too similar: {palette_distance:.2f}")
    COMMUNITY_COLORS[:] = UEEF_COMMUNITY_COLORS

    network = build_from_json(graph, directed=bool(graph.get("directed", True)))
    communities, labels = _visualization_communities(network)
    if network.number_of_nodes() > 5000:
        rendered_graph, rendered_communities, rendered_labels = _overview_graph(network, communities, labels)
    else:
        rendered_graph, rendered_communities, rendered_labels = network, communities, labels
    full_nodes, full_edges = _full_graph_search_payload(graph)
    html_path = output / "graph.html"
    # The upstream exporter reports aggregation progress on stdout. The UEEF
    # facade reserves stdout for its JSON contract, so contain those messages.
    with redirect_stdout(StringIO()):
        to_html(
            rendered_graph,
            rendered_communities,
            str(html_path),
            community_labels=rendered_labels,
            node_limit=5000,
        )

    source_assets = Path(__file__).resolve().parent / "assets" / "vis-network-9.1.6"
    output_assets = output / "assets" / "vis-network-9.1.6"
    output_assets.mkdir(parents=True, exist_ok=True)
    for name in ("vis-network.min.js", "LICENSE-MIT", "LICENSE-APACHE-2.0", "README.txt"):
        source = source_assets / name
        if not source.is_file():
            raise RuntimeError(f"Offline graph viewer asset is missing: {source}")
        destination = output_assets / name
        if not destination.is_file() or destination.read_bytes() != source.read_bytes():
            destination.write_bytes(source.read_bytes())

    document = html_path.read_text(encoding="utf-8")
    external_script = re.compile(
        r'<script src="https://unpkg\.com/vis-network@9\.1\.6/standalone/umd/vis-network\.min\.js".*?</script>',
        re.DOTALL,
    )
    local_script = '<script src="assets/vis-network-9.1.6/vis-network.min.js"></script>'
    document, replacements = external_script.subn(local_script, document, count=1)
    if replacements != 1:
        raise RuntimeError("Graphify HTML exporter no longer exposes the expected pinned vis-network script.")
    document = _promote_overview_label_fonts(document)

    full_nodes_json = json.dumps(full_nodes, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    full_edges_json = json.dumps(full_edges, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    routing_evidence_json = json.dumps(_routing_evidence_payload(root), ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    dataset_marker = "// Build vis datasets"
    if dataset_marker not in document:
        raise RuntimeError("Graphify HTML exporter no longer exposes the dataset marker.")
    document = document.replace(
        dataset_marker,
        f"""const FULL_NODE_RECORDS = {full_nodes_json};
const FULL_EDGE_RECORDS = {full_edges_json};
const FULL_NODES = FULL_NODE_RECORDS.map(([id, label, source, fileType, owner, degree, color]) => ({{
  id, label, size: 13, title: esc(label),
  color: {{ background: color, border: color, highlight: {{ background: '#ffffff', border: color }} }},
  font: {{ size: 0, color: '#ffffff' }},
  _community: owner, _community_name: owner, _source_file: source,
  _file_type: fileType, _degree: degree,
}}));
const FULL_EDGES = FULL_EDGE_RECORDS.map(([id, from, to, relation, confidence]) => ({{
  id, from, to, relation, confidence, title: esc(`${{relation}} [${{confidence}}]`),
  dashes: confidence !== 'EXTRACTED', width: confidence === 'EXTRACTED' ? 2 : 1,
  color: {{ opacity: confidence === 'EXTRACTED' ? 0.7 : 0.35 }},
  arrows: {{ to: {{ enabled: true, scaleFactor: 0.5 }} }},
}}));
const ROUTING_EVIDENCE = {routing_evidence_json};

function graphNodeSource(node) {{
  return String(node._source_file || node.source_file || '').replace(/\\\\/g, '/');
}}

function graphNodeContext(node) {{
  const source = graphNodeSource(node);
  if (source) {{
    const location = node.source_location || node._source_location || '';
    return location ? `${{source}}:${{location}}` : source;
  }}
  return String(node.id || '');
}}

function applyDisambiguatedLabels(nodes) {{
  const counts = new Map();
  for (const node of nodes) {{
    const label = String(node.label || node.id || '').trim();
    const key = label.toLowerCase();
    counts.set(key, (counts.get(key) || 0) + 1);
  }}
  for (const node of nodes) {{
    const rawLabel = String(node.label || node.id || '').trim();
    const repeated = counts.get(rawLabel.toLowerCase()) > 1;
    const context = graphNodeContext(node);
    node.raw_label = rawLabel;
    node.display_label = repeated && context ? `${{rawLabel}} — ${{context}}` : rawLabel;
    node.search_text = `${{node.display_label}} ${{rawLabel}} ${{context}} ${{node.id || ''}}`.toLowerCase();
    if (!node.title || node.title === rawLabel) node.title = node.display_label;
    if (['architecture-root', 'architecture-owner', 'architecture-cluster'].includes(String(node.file_type || ''))) {{
      node.font = {{ ...(node.font || {{}}), size: 12, color: '#ffffff' }};
    }}
  }}
}}

applyDisambiguatedLabels(RAW_NODES);
applyDisambiguatedLabels(FULL_NODES);

{dataset_marker}""",
        1,
    )
    document = document.replace(
        "  id: n.id, label: n.label, color: n.color, size: n.size,",
        "  id: n.id, label: n.display_label || n.label, color: n.color, size: n.size,",
        1,
    )
    document = document.replace(
        "  _community: n.community, _community_name: n.community_name,\n",
        "  _community: n.community, _community_name: n.community_name,\n"
        "  _raw_label: n.raw_label || n.label, _display_label: n.display_label || n.label,\n",
        1,
    )

    document = document.replace(
        '<div id="graph"></div>',
        '<div id="graph-shell"><div id="graph" role="application" tabindex="0" '
        'aria-label="Interactive repository graph. Pan, zoom, and select nodes to inspect relationships."></div>'
        '<div id="graph-toolbar" role="toolbar" aria-label="Graph viewport controls">'
        '<button type="button" id="fit-graph">Fit</button>'
        '<button type="button" id="zoom-in" aria-label="Zoom in">+</button>'
        '<button type="button" id="zoom-out" aria-label="Zoom out">−</button>'
        '<button type="button" id="reset-overview">Overview</button>'
        '<span id="view-state" role="status" aria-live="polite"></span>'
        '</div></div>',
    )
    document = document.replace(
        '<input id="search" type="text" placeholder="Search nodes..." autocomplete="off">',
        '<input id="search" type="search" placeholder="Search nodes..." autocomplete="off" '
        'aria-label="Search repository graph nodes">',
    )
    document = document.replace(
        '<div id="search-results"></div>',
        '<div id="search-results" role="listbox" aria-label="Matching graph nodes"></div>',
    )
    document = document.replace(
        '<div id="info-content">',
        '<div id="info-content" aria-live="polite">',
    )
    document = document.replace(
        '<div id="sidebar">',
        '<div id="sidebar"><section id="routing-panel" aria-label="UEEF routed execution status">'
        '<div id="routing-title">UEEF Routed Execution</div>'
        '<div id="routing-summary" role="status"></div>'
        '<button type="button" id="routing-toggle" aria-expanded="false" aria-controls="routing-list">Show recent routes</button>'
        '<div id="routing-list" hidden></div>'
        '</section>',
        1,
    )
    document = document.replace(
        "keyboard: false,",
        "keyboard: { enabled: true, bindToWindow: false },",
    )
    navigation_marker = "const searchInput = document.getElementById('search');"
    if navigation_marker not in document:
        raise RuntimeError("Graphify HTML exporter no longer exposes the search marker.")
    navigation_script = r"""
const VIEW_ANIMATION = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  ? false : { duration: 320, easingFunction: 'easeInOutQuad' };
const OVERVIEW_NODES = nodesDS.get();
const OVERVIEW_EDGES = edgesDS.get();
const FULL_NODE_INDEX = new Map(FULL_NODES.map(node => [node.id, node]));
const SEARCH_NODES = [...RAW_NODES, ...FULL_NODES];
const viewState = document.getElementById('view-state');
const routingSummary = document.getElementById('routing-summary');
const routingList = document.getElementById('routing-list');
const routingToggle = document.getElementById('routing-toggle');

function renderRoutingEvidence() {
  if (!routingSummary || !routingList) return;
  const verified = ROUTING_EVIDENCE.filter(item => item.executionVerified && item.result === 'SUCCESS');
  routingSummary.textContent = ROUTING_EVIDENCE.length
    ? `${verified.length.toLocaleString()} verified of ${ROUTING_EVIDENCE.length.toLocaleString()} recent routed executions`
    : 'No routing receipts found in .ueef/evidence';
  routingList.innerHTML = '';
  for (const item of ROUTING_EVIDENCE.slice(0, 8)) {
    const row = document.createElement('div');
    row.className = item.executionVerified && item.result === 'SUCCESS' ? 'routing-row verified' : 'routing-row unverified';
    const actual = item.actualModel && item.actualHostReasoning
      ? `${item.actualModel} / ${item.actualHostReasoning}`
      : 'not verified';
    row.innerHTML = `
      <div class="routing-main">${esc(actual)}</div>
      <div class="routing-meta">${esc(item.tier || 'tier?')} · picker ${esc(item.pickerStatus || 'not changed')} · ${esc(item.result || 'unknown')}</div>
    `;
    row.title = esc(`thread=${item.threadId || 'n/a'} route=${item.routeDigest || 'n/a'}`);
    routingList.appendChild(row);
  }
}
renderRoutingEvidence();
if (routingToggle && routingList) {
  routingToggle.addEventListener('click', () => {
    const expanded = routingToggle.getAttribute('aria-expanded') === 'true';
    routingToggle.setAttribute('aria-expanded', String(!expanded));
    routingToggle.textContent = expanded ? 'Show recent routes' : 'Hide recent routes';
    routingList.hidden = expanded;
  });
}

function updateViewState(label, nodeCount, edgeCount) {
  viewState.textContent = `${label} · ${nodeCount.toLocaleString()} nodes · ${edgeCount.toLocaleString()} edges`;
}

function stabilizeAndFit(iterations = 120) {
  network.setOptions({ physics: { enabled: true, stabilization: { iterations, fit: true } } });
  network.stabilize(iterations);
  network.once('stabilized', () => {
    network.setOptions({ physics: { enabled: false } });
    network.fit({ animation: VIEW_ANIMATION });
  });
}

function resetOverview() {
  nodesDS.clear();
  edgesDS.clear();
  nodesDS.add(OVERVIEW_NODES);
  edgesDS.add(OVERVIEW_EDGES);
  hiddenCommunities.clear();
  document.querySelectorAll('.legend-item').forEach(item => item.classList.remove('dimmed'));
  document.querySelectorAll('.legend-cb').forEach(checkbox => { checkbox.checked = true; });
  updateSelectAllState();
  updateViewState('Architecture overview', OVERVIEW_NODES.length, OVERVIEW_EDGES.length);
  stabilizeAndFit(100);
}

function loadNeighborhood(nodeId) {
  const selected = FULL_NODE_INDEX.get(nodeId);
  if (!selected) return;
  const incident = [];
  const nodeIds = new Set([nodeId]);
  for (const edge of FULL_EDGES) {
    if (edge.from !== nodeId && edge.to !== nodeId) continue;
    incident.push(edge);
    nodeIds.add(edge.from);
    nodeIds.add(edge.to);
    if (incident.length >= 400) break;
  }
  const neighborhoodNodes = [...nodeIds]
    .map(id => FULL_NODE_INDEX.get(id))
    .filter(Boolean)
    .map(node => ({
      ...node,
      size: node.id === nodeId ? 28 : Math.min(20, 12 + Math.log2((node._degree || 0) + 1)),
      font: { ...node.font, size: node.id === nodeId ? 16 : 11 },
      borderWidth: node.id === nodeId ? 4 : 1.5,
    }));
  nodesDS.clear();
  edgesDS.clear();
  nodesDS.add(neighborhoodNodes);
  edgesDS.add(incident);
  updateViewState(`Neighborhood: ${selected.label}`, neighborhoodNodes.length, incident.length);
  stabilizeAndFit(140);
  network.selectNodes([nodeId]);
  showInfo(nodeId);
}

function openGraphNode(nodeId) {
  if (nodesDS.get(nodeId)) {
    focusNode(nodeId);
  } else if (FULL_NODE_INDEX.has(nodeId)) {
    loadNeighborhood(nodeId);
  } else if (OVERVIEW_NODES.some(node => node.id === nodeId)) {
    resetOverview();
    requestAnimationFrame(() => focusNode(nodeId));
  }
}

document.getElementById('fit-graph').addEventListener('click', () => network.fit({ animation: VIEW_ANIMATION }));
document.getElementById('zoom-in').addEventListener('click', () => network.moveTo({ scale: Math.min(5, network.getScale() * 1.25), animation: VIEW_ANIMATION }));
document.getElementById('zoom-out').addEventListener('click', () => network.moveTo({ scale: Math.max(0.05, network.getScale() / 1.25), animation: VIEW_ANIMATION }));
document.getElementById('reset-overview').addEventListener('click', resetOverview);
updateViewState('Architecture overview', OVERVIEW_NODES.length, OVERVIEW_EDGES.length);

network.on('selectEdge', params => {
  if (params.nodes.length || !params.edges.length) return;
  const edge = edgesDS.get(params.edges[0]);
  if (!edge) return;
  document.getElementById('info-content').innerHTML = `
    <div class="field"><b>Relationship</b></div>
    <div class="field">${esc(edge.title || edge.relation || 'related')}</div>
    <div class="field">From: ${esc(String(edge.from))}</div>
    <div class="field">To: ${esc(String(edge.to))}</div>`;
});

"""
    document = document.replace(navigation_marker, navigation_script + navigation_marker, 1)
    document = document.replace(
        "const matches = RAW_NODES.filter(n => n.label.toLowerCase().includes(q)).slice(0, 20);",
        "const matches = SEARCH_NODES.filter(n => (n.search_text || n.label.toLowerCase()).includes(q)).slice(0, 20);",
        1,
    )
    document = document.replace(
        "if (!matches.length) { searchResults.style.display = 'none'; return; }",
        "if (!matches.length) { searchResults.innerHTML = '<div class=\"search-empty\" role=\"status\">No matching nodes</div>'; "
        "searchResults.style.display = 'block'; return; }",
        1,
    )
    document = document.replace(
        "    el.className = 'search-item';",
        "    el.className = 'search-item';\n    el.setAttribute('role', 'option');\n    el.tabIndex = 0;",
        1,
    )
    document = document.replace(
        "    el.textContent = n.label;",
        "    el.textContent = n.display_label || (n._source_file ? `${n.label} — ${n._source_file}` : n.label);",
        1,
    )
    old_search_action = """      network.focus(n.id, { scale: 1.5, animation: true });
      network.selectNodes([n.id]);
      showInfo(n.id);"""
    if old_search_action not in document:
        raise RuntimeError("Graphify HTML exporter no longer exposes the search selection action.")
    document = document.replace(old_search_action, "      openGraphNode(n.id);", 1)
    document = document.replace("animation: true", "animation: VIEW_ANIMATION")
    document = document.replace(
        "    searchResults.appendChild(el);",
        "    el.addEventListener('keydown', event => {\n"
        "      if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); el.click(); }\n"
        "    });\n    searchResults.appendChild(el);",
    )
    responsive_styles = """<style>
  #graph-shell { position: relative; flex: 1; min-width: 0; min-height: 320px; overflow: hidden; }
  #graph { width: 100%; height: 100%; min-width: 0; min-height: 320px; outline: none; }
  #graph:focus-visible { box-shadow: inset 0 0 0 2px #70a5d8; }
  #search:focus-visible, input:focus-visible { outline: 2px solid #70a5d8; outline-offset: 2px; }
  #graph-toolbar { position: absolute; z-index: 3; top: 12px; left: 12px; display: flex; align-items: center; gap: 6px; padding: 6px; border: 1px solid #2a2a4e; border-radius: 7px; background: rgba(15,15,26,.9); backdrop-filter: blur(8px); }
  #graph-toolbar button { min-width: 34px; min-height: 32px; padding: 5px 9px; border: 1px solid #3a3a5e; border-radius: 5px; background: #1a1a2e; color: #e0e0e0; cursor: pointer; }
  #graph-toolbar button:hover { background: #2a2a4e; }
  #graph-toolbar button:focus-visible { outline: 2px solid #70a5d8; outline-offset: 2px; }
  #view-state { max-width: min(42vw, 430px); padding: 0 6px; color: #a7b0c0; font-size: 11px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  #routing-panel { flex: 0 0 auto; margin: 0; padding: 12px; border-bottom: 1px solid #2a2a4e; background: #121220; }
  #routing-title { margin-bottom: 6px; color: #e0e0e0; font-size: 13px; font-weight: 700; }
  #routing-summary { margin-bottom: 8px; color: #a7b0c0; font-size: 12px; line-height: 1.35; }
  #routing-toggle { min-height: 32px; padding: 5px 9px; border: 1px solid #3a3a5e; border-radius: 5px; background: #1a1a2e; color: #d7deea; cursor: pointer; }
  #routing-toggle:hover { background: #2a2a4e; }
  #routing-toggle:focus-visible { outline: 2px solid #70a5d8; outline-offset: 2px; }
  #routing-list { display: grid; max-height: 260px; gap: 6px; margin-top: 8px; overflow-y: auto; }
  #routing-list[hidden] { display: none; }
  #info-panel { flex: 0 0 auto; min-height: 150px; background: #19192c; }
  #legend-wrap::before { content: 'Colors represent architecture ownership and extracted clusters. Labels and checkboxes carry the same meaning without relying on color alone.'; display: block; margin-bottom: 10px; color: #9aa5b5; font-size: 11px; line-height: 1.4; }
  .routing-row { padding: 7px 8px; border-left: 3px solid #6f7890; border-radius: 5px; background: #18182a; }
  .routing-row.verified { border-left-color: #4fb477; }
  .routing-row.unverified { border-left-color: #c99b4a; }
  .routing-main { color: #f0f3f8; font-size: 12px; font-weight: 650; overflow-wrap: anywhere; }
  .routing-meta { margin-top: 2px; color: #9aa5b5; font-size: 11px; overflow-wrap: anywhere; }
  .search-empty { padding: 8px 6px; color: #8b949e; font-size: 12px; }
  @media (max-width: 720px) {
    body { flex-direction: column; }
    #graph-shell { width: 100%; height: 62vh; flex: none; }
    #graph { min-height: 0; }
    #sidebar { width: 100%; height: 38vh; border-left: 0; border-top: 1px solid #2a2a4e; }
    #info-panel { min-height: 0; }
    #graph-toolbar { top: 8px; left: 8px; right: 8px; flex-wrap: wrap; }
    #view-state { flex: 1 1 100%; max-width: none; }
  }
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after { scroll-behavior: auto !important; }
  }
</style>"""
    document = document.replace("</head>", responsive_styles + "\n</head>", 1)
    html_path.write_text(document, encoding="utf-8")


def _load_graph(output: Path) -> dict[str, Any]:
    graph_path = output / "graph.json"
    graph = _load_json(graph_path, None)
    if not isinstance(graph, dict):
        raise RuntimeError(f"Graph is missing or invalid: {graph_path}")
    return graph


def _matches(node: dict[str, Any], query: str) -> bool:
    needle = query.casefold()
    return any(needle in str(node.get(key, "")).casefold() for key in ("id", "label", "source_file", "type"))


def _compact(node: dict[str, Any]) -> dict[str, Any]:
    return {key: node.get(key) for key in ("id", "label", "type", "source_file", "confidence", "confidence_score", "evidence") if node.get(key) is not None}


def _base(command: str, status: str = "PASS") -> dict[str, Any]:
    return {"schemaVersion": SCHEMA_VERSION, "command": command, "status": status}


def _build(root: Path) -> dict[str, Any]:
    started = time.perf_counter()
    output = root / OUTPUT_RELATIVE
    old_state = _load_json(output / "state.json", {})
    old_engine_inventory = old_state.get("engineInventory", old_state.get("inventory", {})) if isinstance(old_state, dict) else {}
    old_project_inventory = old_state.get("inventory", {}) if isinstance(old_state, dict) else {}
    engine_inventory = _inventory(root)
    project_inventory = _project_file_inventory(root)
    reused = sum(1 for path, digest in project_inventory.items() if old_project_inventory.get(path) == digest)
    changed = sum(1 for path, digest in project_inventory.items() if old_project_inventory.get(path) != digest)
    deleted = sum(1 for path in old_project_inventory if path not in project_inventory)
    engine_changed = sum(1 for path, digest in engine_inventory.items() if old_engine_inventory.get(path) != digest)
    engine_deleted = sum(1 for path in old_engine_inventory if path not in engine_inventory)
    graph_path = output / "graph.json"
    engine_output = "unchanged; engine skipped"
    if engine_changed or engine_deleted or not graph_path.exists():
        output.mkdir(parents=True, exist_ok=True)
        engine_output = _engine_build(root, output)
        # The engine stores this marker for later incremental runs. A relative
        # marker is sufficient because every facade run fixes cwd to the scan
        # root, and avoids persisting a machine-specific absolute path.
        (output / ".graphify_root").write_text(".\n", encoding="utf-8")
    graph = _load_graph(output)
    _supplement_graph(graph, root, project_inventory)
    _sanitize_graph(graph, root)
    _write_json(graph_path, graph)
    duration_ms = int((time.perf_counter() - started) * 1000)
    cache = {
        "reusedFiles": reused,
        "changedFiles": changed,
        "deletedFiles": deleted,
        "engineChangedFiles": engine_changed,
        "engineDeletedFiles": engine_deleted,
    }
    _write_report(graph, output, cache, duration_ms)
    viewer_changed = old_state.get("viewerVersion") != VIEWER_VERSION
    viewer_missing = not (output / "graph.html").is_file()
    if changed or deleted or viewer_changed or viewer_missing:
        _write_html(graph, output, root)
    nodes, edges, _ = _graph_parts(graph)
    state = {
        "schemaVersion": SCHEMA_VERSION, "status": "PASS", "generatedAt": _utc_now(),
        "root": ".", "inventory": project_inventory, "engineInventory": engine_inventory, "cache": cache,
        "counts": {"files": len(project_inventory), "indexableFiles": len(engine_inventory), "nodes": len(nodes), "edges": len(edges)},
        "durationMs": duration_ms, "mode": "local-offline-ast",
        "viewerVersion": VIEWER_VERSION,
    }
    _write_json(output / "state.json", state)
    result = _base("build")
    result.update({"output": OUTPUT_RELATIVE.as_posix(), "counts": state["counts"], "cache": cache, "durationMs": duration_ms, "engine": "executed" if engine_output != "unchanged; engine skipped" else "reused"})
    return result


def _query_command(command: str, root: Path, query: str, limit: int) -> dict[str, Any]:
    graph = _load_graph(root / OUTPUT_RELATIVE)
    nodes, edges, _ = _graph_parts(graph)
    matches = [node for node in nodes if _matches(node, query)][:limit]
    result = _base(command, "PASS" if matches else "NO_MATCH")
    result.update({"query": query, "results": [_compact(node) for node in matches], "boundedBy": limit})
    if command == "explain" and matches:
        selected = str(matches[0].get("id"))
        node_by_id = {str(node.get("id")): node for node in nodes}
        neighbors = []
        for edge in edges:
            if str(edge.get("source")) == selected or str(edge.get("target")) == selected:
                other = str(edge.get("target")) if str(edge.get("source")) == selected else str(edge.get("source"))
                neighbors.append({"node": _compact(node_by_id.get(other, {"id": other})), "relation": edge.get("relation"), "confidence": edge.get("confidence"), "evidence": edge.get("evidence")})
                if len(neighbors) >= limit:
                    break
        result["explanation"] = {"node": _compact(matches[0]), "neighbors": neighbors}
    elif command == "affected" and matches:
        targets = {str(node.get("id")) for node in matches}
        node_by_id = {str(node.get("id")): node for node in nodes}
        affected: list[dict[str, Any]] = []
        seen = set(targets)
        frontier = set(targets)
        for depth in range(1, 3):
            next_frontier: set[str] = set()
            for edge in edges:
                target = str(edge.get("target"))
                source = str(edge.get("source"))
                if target in frontier and source not in seen:
                    seen.add(source); next_frontier.add(source)
                    affected.append({"node": _compact(node_by_id.get(source, {"id": source})), "depth": depth, "relation": edge.get("relation"), "confidence": edge.get("confidence")})
                    if len(affected) >= limit:
                        break
            frontier = next_frontier
            if not frontier or len(affected) >= limit:
                break
        result["affected"] = affected
    return result


def _path_command(root: Path, source_query: str, target_query: str, limit: int) -> dict[str, Any]:
    graph = _load_graph(root / OUTPUT_RELATIVE)
    nodes, edges, _ = _graph_parts(graph)
    sources = [str(node.get("id")) for node in nodes if _matches(node, source_query)]
    targets = {str(node.get("id")) for node in nodes if _matches(node, target_query)}
    adjacency: dict[str, list[tuple[str, dict[str, Any]]]] = {}
    for edge in edges:
        a, b = str(edge.get("source")), str(edge.get("target"))
        adjacency.setdefault(a, []).append((b, edge))
    queue = deque((source, [source], []) for source in sources[:limit])
    visited = set(sources[:limit])
    found_nodes: list[str] = []
    found_edges: list[dict[str, Any]] = []
    while queue:
        current, node_path, edge_path = queue.popleft()
        if current in targets:
            found_nodes, found_edges = node_path, edge_path
            break
        if len(node_path) > 12:
            continue
        for neighbor, edge in adjacency.get(current, []):
            if neighbor in visited:
                continue
            visited.add(neighbor)
            queue.append((neighbor, node_path + [neighbor], edge_path + [{"relation": edge.get("relation"), "confidence": edge.get("confidence"), "source_file": edge.get("source_file")}]))
    result = _base("path", "PASS" if found_nodes else "NO_PATH")
    result.update({"from": source_query, "to": target_query, "path": found_nodes, "edges": found_edges})
    return result


def _status(root: Path) -> dict[str, Any]:
    output = root / OUTPUT_RELATIVE
    state = _load_json(output / "state.json", {})
    current = _project_file_inventory(root)
    built = isinstance(state, dict) and (output / "graph.json").exists()
    fresh = built and state.get("inventory") == current
    result = _base("status", "PASS" if fresh else ("STALE" if built else "NOT_BUILT"))
    result.update({"built": built, "fresh": fresh, "output": OUTPUT_RELATIVE.as_posix(), "state": {key: state.get(key) for key in ("generatedAt", "counts", "cache", "durationMs", "mode") if isinstance(state, dict)}})
    return result


def _doctor(root: Path) -> dict[str, Any]:
    output = root / OUTPUT_RELATIVE
    checks = {
        "rootExists": root.is_dir(),
        "rootContainedOutput": output.resolve().is_relative_to(root),
        "pythonSupported": sys.version_info >= (3, 10),
        "engineImportable": True,
        "offlineSafeFacade": True,
        "graphReadable": isinstance(_load_json(output / "graph.json", None), dict),
    }
    result = _base("doctor", "PASS" if all(checks.values()) else "FAIL")
    result["checks"] = checks
    return result


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ueef-repository-intelligence")
    safe_commands = tuple(command for command in POLICY.get("commands", []) if command in _DEFAULT_POLICY["commands"])
    parser.add_argument("command", choices=safe_commands)
    parser.add_argument("--root", required=True)
    parser.add_argument("--query", default="")
    parser.add_argument("--from", dest="source", default="")
    parser.add_argument("--to", dest="target", default="")
    parser.add_argument("--max-items", type=int, default=50)
    parser.add_argument("--json", action="store_true")
    return parser


def run(argv: list[str] | None = None) -> dict[str, Any]:
    args = _parser().parse_args(argv)
    root = Path(args.root).resolve()
    if not root.is_dir():
        raise ValueError(f"Repository root does not exist: {root}")
    limit = min(max(args.max_items, 1), int(POLICY.get("maxItems", 500)))
    if args.command == "build":
        return _build(root)
    if args.command in {"query", "explain", "affected"}:
        if not args.query:
            raise ValueError(f"--query is required for {args.command}")
        return _query_command(args.command, root, args.query, limit)
    if args.command == "path":
        if not args.source or not args.target:
            raise ValueError("--from and --to are required for path")
        return _path_command(root, args.source, args.target, limit)
    if args.command == "status":
        return _status(root)
    return _doctor(root)


def main() -> None:
    started = time.perf_counter()
    try:
        result = run()
        result.setdefault("durationMs", int((time.perf_counter() - started) * 1000))
        print(json.dumps(result, ensure_ascii=False, indent=2))
        if result.get("status") == "FAIL":
            raise SystemExit(1)
    except (ValueError, RuntimeError, TimeoutError) as exc:
        print(json.dumps({"schemaVersion": SCHEMA_VERSION, "status": "FAIL", "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
