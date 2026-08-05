# Performance And Reliability

Keep audit scans bounded by ignoring dependency stores, build output, reports, and VCS metadata. Prefer streaming or targeted scans for large repositories. Record command duration and avoid changing project files during an audit.

On Unix, `ueef-audit.sh --quick` keeps structural validation but skips nested behavior tests. Use it only when the same workflow already ran the full validator, or for fast local feedback; release boundaries still use the default full audit.
