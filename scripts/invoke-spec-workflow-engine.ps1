[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments)][string[]]$EngineArguments
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$packageRoot = Join-Path $root 'engines\spec-workflow\ueef'
$python = Get-Command python -ErrorAction Stop
$previousPythonPath = $env:PYTHONPATH
$previousBytecode = $env:PYTHONDONTWRITEBYTECODE
try {
  if ($previousPythonPath) {
    $env:PYTHONPATH = $packageRoot + [IO.Path]::PathSeparator + $previousPythonPath
  } else {
    $env:PYTHONPATH = $packageRoot
  }
  $env:PYTHONDONTWRITEBYTECODE = '1'
  & $python.Source -m ueef_spec_workflow @EngineArguments
  exit $LASTEXITCODE
} finally {
  $env:PYTHONPATH = $previousPythonPath
  $env:PYTHONDONTWRITEBYTECODE = $previousBytecode
}
