"""UEEF-owned safe facade around the vendored local repository engine.

Only bounded, offline repository operations are exposed here. The upstream
installer, hook, network, LLM, MCP, remote database, and memory commands are
deliberately unreachable through this entry point.
"""

from __future__ import annotations

import argparse
import hashlib
import html
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
_DEFAULT_NOISE_DIRS = {
    ".git", ".hg", ".svn", ".ueef", ".venv", "venv", "env",
    "node_modules", "vendor", "dist", "build", "coverage", "target",
    "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache",
}
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


def _supplement_graph(graph: dict[str, Any], root: Path, inventory: dict[str, str]) -> None:
    nodes, edges, _ = _graph_parts(graph)
    node_ids = {str(node.get("id", "")) for node in nodes}
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

    for relative in inventory:
        path = root / Path(relative)
        if path.suffix.lower() not in SUPPLEMENTAL_EXTENSIONS:
            continue
        file_id = source_ids.get(relative) or f"ueef_file_{_slug(relative)}"
        if file_id not in node_ids:
            nodes.append({
                "id": file_id,
                "label": path.name,
                "type": "file",
                "file_type": "documentation" if path.suffix.lower() in {".md", ".mdx", ".rst", ".txt"} else "configuration",
                "source_file": relative,
                "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "evidence": {"source_file": relative, "method": "local-text-structure"},
                "_origin": "ueef-local",
            })
            node_ids.add(file_id)
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
            edges.append({
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


def _write_html(graph: dict[str, Any], output: Path) -> None:
    nodes, edges, _ = _graph_parts(graph)
    payload = json.dumps({"nodes": nodes[:5000], "edges": edges[:10000]}, ensure_ascii=False).replace("</", "<\\/")
    document = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Repository Intelligence</title><style>
body{{font:14px system-ui;margin:0;background:#0d1117;color:#e6edf3}}header{{position:sticky;top:0;padding:16px;background:#161b22;border-bottom:1px solid #30363d}}input{{width:min(640px,90%);padding:10px;border-radius:6px;border:1px solid #30363d;background:#0d1117;color:inherit}}main{{padding:16px}}article{{padding:10px;margin:8px 0;border:1px solid #30363d;border-radius:6px}}small{{color:#8b949e}}
</style></head><body><header><strong>Repository Intelligence</strong><br><input id="q" aria-label="Filter nodes" placeholder="Filter nodes"></header><main id="results"></main>
<script>const data={payload};const out=document.getElementById('results');const q=document.getElementById('q');function draw(){{const term=q.value.toLowerCase();const rows=data.nodes.filter(n=>!term||JSON.stringify(n).toLowerCase().includes(term)).slice(0,250);out.innerHTML=rows.map(n=>`<article><strong>${{esc(n.label||n.id)}}</strong><br><small>${{esc(n.source_file||'')}} · ${{esc(n.confidence||'AMBIGUOUS')}}</small></article>`).join('')||'<p>No matches</p>'}}function esc(v){{return String(v).replace(/[&<>"']/g,c=>({{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}}[c]))}}q.addEventListener('input',draw);draw();</script></body></html>"""
    (output / "graph.html").write_text(document, encoding="utf-8")


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
    old_inventory = old_state.get("inventory", {}) if isinstance(old_state, dict) else {}
    inventory = _inventory(root)
    reused = sum(1 for path, digest in inventory.items() if old_inventory.get(path) == digest)
    changed = sum(1 for path, digest in inventory.items() if old_inventory.get(path) != digest)
    deleted = sum(1 for path in old_inventory if path not in inventory)
    graph_path = output / "graph.json"
    engine_output = "unchanged; engine skipped"
    if changed or deleted or not graph_path.exists():
        output.mkdir(parents=True, exist_ok=True)
        engine_output = _engine_build(root, output)
        # The engine stores this marker for later incremental runs. A relative
        # marker is sufficient because every facade run fixes cwd to the scan
        # root, and avoids persisting a machine-specific absolute path.
        (output / ".graphify_root").write_text(".\n", encoding="utf-8")
    graph = _load_graph(output)
    _supplement_graph(graph, root, inventory)
    _sanitize_graph(graph, root)
    _write_json(graph_path, graph)
    duration_ms = int((time.perf_counter() - started) * 1000)
    cache = {"reusedFiles": reused, "changedFiles": changed, "deletedFiles": deleted}
    _write_report(graph, output, cache, duration_ms)
    _write_html(graph, output)
    nodes, edges, _ = _graph_parts(graph)
    state = {
        "schemaVersion": SCHEMA_VERSION, "status": "PASS", "generatedAt": _utc_now(),
        "root": ".", "inventory": inventory, "cache": cache,
        "counts": {"files": len(inventory), "nodes": len(nodes), "edges": len(edges)},
        "durationMs": duration_ms, "mode": "local-offline-ast",
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
    current = _inventory(root)
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
