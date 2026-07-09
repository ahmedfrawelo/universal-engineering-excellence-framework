# Install UEEF

Clone the repository, open a terminal at the repository root, and run the installer for your assistant.

## Codex

```powershell
.\scripts\install-codex.ps1
```

```sh
./scripts/install-codex.sh
```

## Cursor

```powershell
.\scripts\install-cursor.ps1
```

```sh
./scripts/install-cursor.sh
```

## Generic Agents

```powershell
.\scripts\install-generic.ps1
```

```sh
./scripts/install-generic.sh
```

## What Installers Do

1. Confirm the source repository path.
2. Create a global UEEF directory.
3. Ask before overwriting an existing loader.
4. Back up existing global rules.
5. Copy `framework/` into the global location.
6. Write a loader that tells the AI assistant how to load UEEF.
7. Print the final installation path.

## Verify Installation

Run the installer again and confirm it detects the existing loader. You can also open the printed global path and verify that `framework/MASTER_INDEX.md` and the assistant loader file exist.
