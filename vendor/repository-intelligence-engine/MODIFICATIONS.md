# UEEF modifications

This directory contains a complete tracked snapshot of the upstream repository at
commit `00efd6e7969837ae4a9f11d8d504dcd3b20b09df`, excluding only its Git metadata.
The original Apache-2.0 license, MIT license, and NOTICE remain beside the source.

UEEF changes after import:

- Added `UEEF-VENDOR.json` to make the source revision and containment policy machine-readable.
- Added `UPSTREAM-FILES.json`, a 776-entry path/blob/SHA-256/size inventory used to verify that every unmodified imported file remains byte-exact.
- Added this modification log.
- Added `graphify/ueef_adapter.py`, a bounded local-only facade. It exposes build,
  query, path, explain, affected, status, and doctor; it cannot dispatch upstream
  installers, hooks, MCP, LLM, cloud, URL ingestion, remote database, or memory commands.
- Connected the UEEF facade to Graphify's upstream interactive `vis-network`
  exporter instead of emitting a flat node list. The pinned `vis-network` 9.1.6
  browser bundle and both license choices live under `graphify/assets/` so the
  generated viewer remains fully local and does not depend on the upstream CDN.
- Added the `ueef-repository-intelligence` console entry point.
- Normalized relative `source_file` values to POSIX separators in `graphify/extract.py`
  so artifacts are portable and the upstream Astro relative-input regression passes on Windows.
- Updated the affected JavaScript alias-resolution regression expectations to use
  `Path.as_posix()`, matching the portable persisted-path contract on every host.
- Made the real FalkorDB integration suite opt-in through `GRAPHIFY_TEST_FALKORDB=1`.
  A locally installed SDK no longer causes the default offline suite to wait for a
  network service that UEEF does not expose.
- Marked atomic-write POSIX permission and umask assertions as Windows-skipped;
  NTFS does not provide the tested POSIX mode contract.
- Treat unresolved slash-rooted POSIX `source_file` values as absolute even on
  Windows, preventing machine-dependent re-keyed IDs.
- Made the C-preprocessor absolute-path regression platform-neutral by using
  `Path.is_absolute()` rather than assuming a POSIX slash prefix.
- Marked symlink traversal tests as Windows-skipped when symlink creation needs
  privileges not available to the ordinary local UEEF runtime.
- Applied the same platform guard to the extractor's symlink fixtures.
- Disabled the unsafe stat-only file-hash fast path on Windows: rapid same-size
  writes can have identical NTFS timestamps and otherwise reuse stale hashes.
- Corrected the hook guard's Windows interpretation of slash-rooted POSIX paths
  so out-of-project reads cannot be treated as in-project relative paths.
- Made the worktree hook integration test skip only when its required POSIX
  shell is unavailable on the host.
- Marked the image-vision out-of-root symlink fixture as Windows-skipped when
  symlink creation requires unavailable local privileges.
- Normalized image reference paths to POSIX form so cross-platform semantic
  payloads and artifacts do not persist Windows separators.
- Corrected the install regression's UTF-8 dash expectations; the generated
  skill is UTF-8 text, not a host-codepage-dependent fixture.
- Quoted the generated Codex hook executable and parsed it with shell-aware
  test logic, allowing installations below Windows paths that contain spaces.
- Made the Gemini reference-install test assert its documented platform-specific
  global skill location instead of assuming the POSIX path on Windows.
- Isolated Hermes's Windows round-trip fixture from the host `LOCALAPPDATA`
  location while still exercising its actual platform destination rule.
- Read the Unicode merge-chunk artifact as UTF-8 in its regression test rather
  than through Windows's locale-dependent default encoding.
- Reserved path-length headroom for Obsidian exports (and used a bounded
  extended-length Windows write path) so capped note filenames also work below
  long temporary or workspace paths and remain usable by normal path readers.
- Made the OpenAI-SDK retry-cap tests explicitly conditional on their optional
  backend dependency, preserving an offline/default UEEF test environment.
- Made the vendored skill generator pass only the exact enclosing workspace as
  Git's safe directory when checking its upstream baseline; this keeps Git's
  ownership protection active while allowing the repository-contained audit.
- Made the historical v8 skill-coverage regression skip only when its required
  upstream Git baseline is absent from the intentionally Git-metadata-free
  vendored snapshot.
- Kept the optional ID-normalization property checks active while avoiding the
  unavailable Hypothesis optimiser module on the bundled Python runtime.
- Marked the moved-corpus zero-read cache expectation as non-Windows because
  UEEF deliberately re-hashes content there to avoid NTFS same-size/timestamp
  stale-cache false hits.
- Applied the same Windows condition to legacy and out-of-root stat-index
  warm-hit assertions, which intentionally exercise that disabled fast path.
- Corrected Gemini global-uninstall fixtures to use its Windows `.agents` path
  while retaining the `.gemini` project-scope assertions.
- Marked deleted-current-working-directory watch fixtures as non-Windows:
  Windows holds the process CWD open and cannot represent the POSIX scenario.
- Normalized persisted watch pending-change paths to POSIX separators, so the
  queue is portable across runtime processes and operating systems.

No upstream copyright, license, or notice file was removed or rewritten.
