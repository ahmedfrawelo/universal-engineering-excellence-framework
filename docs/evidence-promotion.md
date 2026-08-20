# Durable UEEF evidence promotion

`.ueef/` is task-local cache and execution state and remains ignored by Git. Evidence needed to support a durable completion or release claim must be explicitly promoted into `docs/evidence/<task-id>/`:

```powershell
.\scripts\promote-ueef-evidence.ps1 -TaskId '<task-id>' -SourcePath '.ueef\evidence\<artifact>.json'
```

Promotion copies only explicitly named files and writes `manifest.json` with SHA-256 hashes and source/destination classifications. Review and commit the promoted directory like any other release evidence. Do not promote credentials, transcripts, private session state, or unredacted logs.
