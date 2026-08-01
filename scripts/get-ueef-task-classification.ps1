[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Task,
  [ValidateRange(0,3)][int]$Scope = 0,
  [ValidateRange(0,3)][int]$Ambiguity = 0,
  [ValidateRange(0,3)][int]$Coupling = 0,
  [ValidateRange(0,3)][int]$Risk = 0,
  [ValidateRange(0,3)][int]$Verification = 0,
  [ValidateSet('None','Architecture','Authentication','Authorization','Security','Production','Migration','Destructive','Privacy','Payment','Incident','Release')][string]$RiskFloor = 'None',
  [ValidateSet('ui','browser','current-docs','ambiguous','debugging')][string[]]$TaskTag = @(),
  [switch]$CodeChange,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$inputParameters = @{} + $PSBoundParameters
. (Join-Path $PSScriptRoot 'task-language-signals.ps1')
$text = ConvertTo-UeefTaskSignalText $Task

function Test-TaskText([string]$Pattern) {
  return $text -match $Pattern
}

function Get-InputSource([string]$Name) {
  if ($inputParameters.ContainsKey($Name)) { return 'explicit' }
  return 'inferred'
}

$explanatoryOnly = Test-TaskText '\b(explain|answer|summari[sz]e|translate|define|what is|how does|compare concepts?)\b'
$changeLanguage = Test-TaskText '\b(build|implement|install|add|change|refactor|fix|repair|migrat\w*|create|update|remove|delete|harden|polish|upgrade|replace|write|edit|integrate|deploy|release|redesign|optimi[sz]e|improve|develop|scaffold|tune)\b'
$reviewLanguage = Test-TaskText '\b(audit|review|inspect|diagnos\w*|investigate|verify|validate|assess|test)\b'
$wideScopeLanguage = Test-TaskText '\b(project[- ]wide|repository[- ]wide|system[- ]wide|end[- ]to[- ]end|all (?:problems|issues|modules|files)|entire (?:project|repository|system)|complete migration|full migration)\b'
$architectureLanguage = Test-TaskText '\b(architecture|architectural|cross[- ]cutting|platform|framework core|runtime contract)\b'
$dataLanguage = Test-TaskText '\b(database|schema|sql|query|storage|persistence|data model)\b'
$apiLanguage = Test-TaskText '\b(api|endpoint|backend|server|controller|service|integration)\b'
$dependencyLanguage = Test-TaskText '\b(dependency|package|runtime upgrade|framework upgrade)\b'
$unclearLanguage = Test-TaskText '\b(ambiguous|unclear|unknown requirements?|brainstorm|explore|idea|acceptance criteria|contradictory|not sure)\b'
$debugLanguage = Test-TaskText '\b(bug|debug|regression|failure|failing|broken|error|crash|fix|repair)\b'
$inferredCodeChange = $changeLanguage -and !$explanatoryOnly
if (!$inputParameters.ContainsKey('CodeChange')) {
  $CodeChange = $inferredCodeChange
}
$frontendRouteArgs = @((Join-Path $PSScriptRoot 'select-frontend-route.mjs'), '--task', $Task, '--mode', 'Auto')
if ($TaskTag -contains 'ui') { $frontendRouteArgs += '--force-frontend' }
if ($inputParameters.ContainsKey('CodeChange')) { $frontendRouteArgs += @('--mutation', $(if ($CodeChange) { 'Implement' } else { 'ReadOnly' })) }
$frontendRoute = (& node @frontendRouteArgs | Out-String) | ConvertFrom-Json
$uiNounLanguage = [bool]$frontendRoute.applies
$uiActionLanguage = Test-TaskText '\b(build|implement|create|change|update|fix|polish|design|style|render|audit|review|inspect|verify|redesign|optimi[sz]e|improve|recommend|choose|suggest|compare)\b'
$browserActionLanguage = Test-TaskText '\b(open|navigate|inspect|click|type|upload|download|authenticate|log.?in|browse|capture|screenshot|visually verify|visual check)\b'
$browserSurfaceLanguage = Test-TaskText '\b(browser|chrome|tab|website|web page|site|localhost|figma)\b'
$currentDocsLanguage = (Test-TaskText '\b(latest|current|up[- ]to[- ]date|newest|recent)\b') -and (Test-TaskText '\b(documentation|docs|api|sdk|library|package|model|specification|standard|version)\b')

$inferredTags = [Collections.Generic.List[string]]::new()
if ($uiNounLanguage -and $uiActionLanguage) { $inferredTags.Add('ui') }
if ($browserActionLanguage -and $browserSurfaceLanguage) { $inferredTags.Add('browser') }
if ($currentDocsLanguage) { $inferredTags.Add('current-docs') }
if ($unclearLanguage) { $inferredTags.Add('ambiguous') }
if ($debugLanguage) { $inferredTags.Add('debugging') }

$effectiveTags = [Collections.Generic.List[string]]::new()
foreach ($tag in @($TaskTag) + @($inferredTags)) {
  if (!$effectiveTags.Contains($tag)) { $effectiveTags.Add($tag) }
}

if (!$inputParameters.ContainsKey('RiskFloor')) {
  if (!$explanatoryOnly -and (Test-TaskText '\b(incident|outage|breach|compromise|emergency)\b')) {
    $RiskFloor = 'Incident'
  } elseif (!$explanatoryOnly -and (Test-TaskText '\b(destructive|irreversible|drop table|truncate|purge|delete permanently|data loss)\b')) {
    $RiskFloor = 'Destructive'
  } elseif (!$explanatoryOnly -and (Test-TaskText '\b(payment|billing|checkout|financial transaction)\b')) {
    $RiskFloor = 'Payment'
  } elseif (!$explanatoryOnly -and (Test-TaskText '\b(privacy|pii|personal data|sensitive data)\b')) {
    $RiskFloor = 'Privacy'
  } elseif (!$explanatoryOnly -and (Test-TaskText '\b(production|prod|live environment|live system)\b')) {
    $RiskFloor = 'Production'
  } elseif (!$explanatoryOnly -and (Test-TaskText '\b(migration|migrate|schema change)\b')) {
    $RiskFloor = 'Migration'
  } elseif (!$explanatoryOnly -and (Test-TaskText '\b(authentication|sign[- ]?in|login|identity)\b')) {
    $RiskFloor = 'Authentication'
  } elseif (!$explanatoryOnly -and (Test-TaskText '\b(authorization|permission|access control|rbac|policy enforcement)\b')) {
    $RiskFloor = 'Authorization'
  } elseif (!$explanatoryOnly -and (Test-TaskText '\b(security|vulnerability|secret|credential|owasp|threat)\b')) {
    $RiskFloor = 'Security'
  } elseif (!$explanatoryOnly -and $architectureLanguage) {
    $RiskFloor = 'Architecture'
  } elseif (!$explanatoryOnly -and (Test-TaskText '\b(release|deploy|rollout|publish)\b')) {
    $RiskFloor = 'Release'
  }
}

if (!$inputParameters.ContainsKey('Scope')) {
  $Scope = if ($wideScopeLanguage) {
    3
  } elseif ($CodeChange -and ($architectureLanguage -or $dataLanguage -or $apiLanguage -or $dependencyLanguage)) {
    2
  } elseif ($CodeChange -or $reviewLanguage) {
    1
  } else {
    0
  }
}

if (!$inputParameters.ContainsKey('Ambiguity')) {
  $Ambiguity = if ($unclearLanguage) { 1 } elseif ($CodeChange -and (Test-TaskText '\b(new feature|from scratch|redesign)\b')) { 1 } else { 0 }
}

if (!$inputParameters.ContainsKey('Coupling')) {
  $Coupling = if ($wideScopeLanguage -or ($CodeChange -and (Test-TaskText '\b(migration|production|platform|cross[- ]cutting)\b'))) {
    3
  } elseif ($CodeChange -and ($architectureLanguage -or $dataLanguage -or $apiLanguage -or $dependencyLanguage -or $RiskFloor -in @('Authentication','Authorization','Security'))) {
    2
  } elseif ($CodeChange) {
    1
  } else {
    0
  }
}

if (!$inputParameters.ContainsKey('Risk')) {
  $Risk = if ($RiskFloor -in @('Production','Migration','Destructive','Privacy','Payment','Incident')) {
    3
  } elseif ($RiskFloor -in @('Architecture','Authentication','Authorization','Security','Release')) {
    2
  } elseif ($CodeChange) {
    1
  } else {
    0
  }
}

if (!$inputParameters.ContainsKey('Verification')) {
  $Verification = if ($Risk -eq 3 -or $wideScopeLanguage) {
    3
  } elseif ($debugLanguage) {
    2
  } elseif ($CodeChange -or $reviewLanguage) {
    1
  } else {
    0
  }
}

$routeArgs = @{
  Scope = $Scope
  Ambiguity = $Ambiguity
  Coupling = $Coupling
  Risk = $Risk
  Verification = $Verification
  RiskFloor = $RiskFloor
  CodeChange = [bool]$CodeChange
  Json = $true
}
$route = (& (Join-Path $PSScriptRoot 'select-agent-route.ps1') @routeArgs | Out-String) | ConvertFrom-Json

$sources = [ordered]@{
  scope = Get-InputSource 'Scope'
  ambiguity = Get-InputSource 'Ambiguity'
  coupling = Get-InputSource 'Coupling'
  risk = Get-InputSource 'Risk'
  verification = Get-InputSource 'Verification'
  riskFloor = Get-InputSource 'RiskFloor'
  taskTags = if ($inputParameters.ContainsKey('TaskTag') -and $inferredTags.Count) { 'mixed' } elseif ($inputParameters.ContainsKey('TaskTag')) { 'explicit' } else { 'inferred' }
  codeChange = Get-InputSource 'CodeChange'
}
$sourceValues = @($sources.Values)
$classificationSource = if ($sourceValues -notcontains 'inferred' -and $sourceValues -notcontains 'mixed') {
  'explicit'
} elseif ($sourceValues -contains 'explicit' -or $sourceValues -contains 'mixed') {
  'mixed'
} else {
  'inferred'
}

$result = [ordered]@{
  schemaVersion = 1
  task = $Task
  source = $classificationSource
  frontendRoute = $frontendRoute
  values = [ordered]@{
    scope = $Scope
    ambiguity = $Ambiguity
    coupling = $Coupling
    risk = $Risk
    verification = $Verification
    riskFloor = $RiskFloor
    taskTags = @($effectiveTags)
    codeChange = [bool]$CodeChange
  }
  sources = $sources
  evidence = [ordered]@{
    inferredTags = @($inferredTags)
    explanatoryOnly = $explanatoryOnly
    changeLanguage = $changeLanguage
    reviewLanguage = $reviewLanguage
    wideScopeLanguage = $wideScopeLanguage
  }
  route = $route
}

if ($Json) {
  $result | ConvertTo-Json -Depth 6
} else {
  [pscustomobject]$result
}
