[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Task,
  [ValidateSet('low','medium','high','critical')][string]$Risk = 'low',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$text = $Task.ToLowerInvariant()
$skills = [Collections.Generic.List[string]]::new()
$mcps = [Collections.Generic.List[string]]::new()
$reasons = [Collections.Generic.List[string]]::new()
function Add-Unique([Collections.Generic.List[string]]$List, [string]$Value) { if (!$List.Contains($Value)) { $List.Add($Value) } }

$isReadOnly = $text -match '\b(explain|answer|summari[sz]e|translate|define|what is|review status)\b' -and $text -notmatch '\b(current|latest|online|browser|file|repository|code)\b'
$needsBrowser = $text -match '\b(browser|chrome|tab|website|visual check|screenshot|figma)\b'
$needsCurrentDocs = $text -match '\b(latest|current|up.to.date|documentation|api docs|library version)\b'
$isUi = $text -match '\b(ui|ux|frontend|react|angular|css|layout|accessibility|design)\b'
$isSecurity = $Risk -in @('high','critical') -or $text -match '\b(security|auth|payment|privacy|production|migration|destructive)\b'

if ($isReadOnly) {
  $profile = 'CORE_ONLY'
  Add-Unique $reasons 'The request is self-contained and read-only.'
} elseif ($isSecurity) {
  $profile = 'ASSURED'
  Add-Unique $reasons 'High-impact or regulated work needs verified capabilities and independent evidence.'
} else {
  $profile = 'SELECTIVE'
  Add-Unique $reasons 'Use only capabilities directly justified by the task.'
}

if ($isUi) {
  Add-Unique $skills 'ui-ux-pro-max'; Add-Unique $skills 'impeccable'
  Add-Unique $reasons 'UI work requires the installed UI/UX baseline skills.'
}
if ($needsCurrentDocs) { Add-Unique $skills '.system/openai-docs'; Add-Unique $reasons 'The task requests current documentation.' }
if ($needsBrowser) { Add-Unique $mcps 'node_repl'; Add-Unique $reasons 'Existing browser/session work requires the Node REPL browser control channel.' }
if ($isSecurity) { Add-Unique $reasons 'Run the relevant security and rollback gates; do not assume optional MCP availability.' }

$result = [ordered]@{
  schemaVersion = 1
  profile = $profile
  task = $Task
  skills = @($skills)
  mcps = @($mcps)
  capabilityHealthRequired = ($profile -eq 'ASSURED' -or $mcps.Count -gt 0)
  reasons = @($reasons)
}
if ($Json) { $result | ConvertTo-Json -Depth 3 } else {
  Write-Output "Capability profile: $($result.profile)"
  Write-Output "Skills: $(if($skills.Count){$skills -join ', '}else{'none'})"
  Write-Output "MCPs: $(if($mcps.Count){$mcps -join ', '}else{'none'})"
  Write-Output "Capability health required: $($result.capabilityHealthRequired)"
  $reasons | ForEach-Object { Write-Output "Reason: $_" }
}
