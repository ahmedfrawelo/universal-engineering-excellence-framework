param(
  [string[]]$Profile = @(),
  [switch]$Install
)
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$RuntimePath=''
if($env:UEEF_GLOBAL_PATH){
  if(Test-Path -LiteralPath (Join-Path $env:UEEF_GLOBAL_PATH 'UEEF-LOADER.md')){$RuntimePath=$env:UEEF_GLOBAL_PATH}
  elseif(Test-Path -LiteralPath (Join-Path $env:UEEF_GLOBAL_PATH 'codex\UEEF-LOADER.md')){$RuntimePath=Join-Path $env:UEEF_GLOBAL_PATH 'codex'}
}elseif($env:CODEX_HOME){$RuntimePath=Join-Path $env:CODEX_HOME 'ueef\codex'}
$CodexHome=if($env:CODEX_HOME){$env:CODEX_HOME}elseif($RuntimePath){Split-Path -Parent (Split-Path -Parent $RuntimePath)}else{''}
$selectedProfiles=@($Profile | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
if(!$selectedProfiles.Count){
  $signals=@(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue | Where-Object {$_.FullName -notmatch '\\.git\\'})
  $names=@($signals|Select-Object -ExpandProperty Name)
  $selectedProfiles=[System.Collections.Generic.List[string]]::new();$selectedProfiles.Add('Core');$selectedProfiles.Add('AI')
  if(($names|Where-Object {$_ -match '^(package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|angular\.json|vite\.config\.|next\.config\.)$'}).Count -or ($signals|Where-Object {$_.Extension -in @('.tsx','.jsx','.vue','.svelte')}).Count){$selectedProfiles.Add('Frontend')}
  if(($names|Where-Object {$_ -match '(\.sln|\.csproj|pyproject\.toml|requirements\.txt|pom\.xml|build\.gradle)$'}).Count -or ($names -contains 'Dockerfile')){$selectedProfiles.Add('Backend')}
  if(($names|Where-Object {$_ -match '(schema\.sql|migration|prisma|flyway|liquibase)' -or $_ -match '\.(sql|dbml)$'}).Count){$selectedProfiles.Add('Database')}
  if(($signals|Where-Object {$_.Extension -in @('.tsx','.jsx','.vue','.svelte','.html','.css','.scss')}).Count){$selectedProfiles.Add('UIUX')}
  if(($names|Where-Object {$_ -match '^Dockerfile$|docker-compose|^\.gitlab-ci|^Jenkinsfile$'}).Count -or (Test-Path (Join-Path $Root '.github\workflows'))){$selectedProfiles.Add('DevOps')}
}
$allowed=@('Core','Frontend','Backend','Database','UIUX','DevOps','AI','Optional')
foreach($name in $selectedProfiles){if($allowed -notcontains $name){throw "Unknown environment profile: $name"}}
$results=[System.Collections.Generic.List[object]]::new()
function Add-Check($profile,$name,$level,$ok,$detail,$install=''){ $results.Add([pscustomobject]@{Profile=$profile;Name=$name;Level=$level;Status=if($ok){'PASS'}else{'MISSING'};Detail=$detail;Install=$install}) }
function Has-Command($name){[bool](Get-Command $name -ErrorAction SilentlyContinue)}
function Has-Path($path){Test-Path -LiteralPath $path}
function Ensure-Command($name,$packageId){
  if(Has-Command $name){return $true}
  if($Install -and (Has-Command winget)){
    Write-Output "Installation Performed: winget install --id $packageId -e --silent"
    winget install --id $packageId -e --silent --accept-package-agreements --accept-source-agreements | Out-Host
  }
  return (Has-Command $name)
}
foreach($p in $selectedProfiles){
  switch($p){
    'Core' {
      Add-Check Core Git Mandatory (Ensure-Command git 'Git.Git') 'git command' 'winget install --id Git.Git -e'
      Add-Check Core 'GitHub CLI' Mandatory (Ensure-Command gh 'GitHub.cli') 'gh command; authentication is checked separately' 'winget install --id GitHub.cli -e'
      Add-Check Core 'Skill Installer' Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\.system\skill-installer\SKILL.md'))) 'Codex skill installer' 'Install from the Codex skill marketplace'
      Add-Check Core 'OpenAI Docs' Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\.system\openai-docs\SKILL.md'))) 'OpenAI docs skill' 'Install the openai-docs skill'
      Add-Check Core 'Skill Creator' Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\.system\skill-creator\SKILL.md'))) 'Skill creator skill' 'Install the skill-creator skill'
      Add-Check Core 'Validation Scripts' Mandatory (Has-Path (Join-Path $Root 'scripts\validate-framework.ps1')) 'repository validator'
      Add-Check Core 'UEEF Runtime' Mandatory ([bool]$RuntimePath -and (Has-Path (Join-Path $RuntimePath 'UEEF-LOADER.md'))) 'active runtime loader'
    }
    'AI' {
      Add-Check AI UEEF Mandatory ([bool]$RuntimePath -and (Has-Path (Join-Path $RuntimePath 'UEEF-LOADER.md'))) 'runtime loader'
      Add-Check AI 'Runtime Loader' Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'AGENTS.md'))) 'global agent rules'
    }
    'Frontend' {
      Add-Check Frontend Node Mandatory (Ensure-Command node 'OpenJS.NodeJS.LTS') 'node command' 'winget install OpenJS.NodeJS.LTS'
      Add-Check Frontend npm Mandatory (Ensure-Command npm 'OpenJS.NodeJS.LTS') 'npm command'
      Add-Check Frontend Playwright Recommended (Has-Command npx) 'npx can invoke Playwright'
      Add-Check Frontend 'UI UX Pro Max' Recommended ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\ui-ux-pro-max\SKILL.md'))) 'skill path' 'npx skills add github:https://github.com/nextlevelbuilder/ui-ux-pro-max-skill --skill ui-ux-pro-max'
      Add-Check Frontend Impeccable Recommended ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\impeccable\SKILL.md'))) 'skill path'
      Add-Check Frontend 'Frontend Design' Optional ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\frontend-design\SKILL.md'))) 'Open Design specialist skill path' 'Install from nexu-io/open-design'
    }
    'Backend' { Add-Check Backend '.NET or Node or Python' Recommended ((Has-Command dotnet) -or (Has-Command node) -or (Has-Command python)) 'at least one detected backend runtime' }
    'Database' { Add-Check Database 'Database CLI' Recommended ((Has-Command sqlcmd) -or (Has-Command psql) -or (Has-Command mysql)) 'provider CLI detected' }
    'UIUX' {
      Add-Check UIUX 'UI UX Pro Max' Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\ui-ux-pro-max\SKILL.md'))) 'skill path'
      Add-Check UIUX Impeccable Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\impeccable\SKILL.md'))) 'skill path'
      Add-Check UIUX 'Emil Design Engineering' Recommended ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\emil-design-eng\SKILL.md'))) 'specialist skill path' 'scripts/install-design-engineering-skills.ps1'
      foreach($skill in @('frontend-design','design-brief')) {
        Add-Check UIUX $skill Optional ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome "skills\$skill\SKILL.md"))) 'Open Design specialist skill path' 'Install from nexu-io/open-design'
      }
      foreach($skill in @('review-animations','improve-animations','animation-vocabulary','apple-design')) {
        Add-Check UIUX $skill Optional ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome "skills\$skill\SKILL.md"))) 'specialist skill path' 'scripts/install-design-engineering-skills.ps1'
      }
      Add-Check UIUX Playwright Recommended (Has-Command npx) 'npx available'
    }
    'DevOps' { Add-Check DevOps Docker Recommended (Has-Command docker) 'docker command'; Add-Check DevOps 'GitHub CLI' Mandatory (Has-Command gh) 'gh command' }
    'Optional' { Add-Check Optional 'Optional tools' Optional $true 'not blocking' }
  }
}
$results | Format-Table Profile,Name,Level,Status,Detail -AutoSize
$missingMandatory=@($results|Where-Object {$_.Level -eq 'Mandatory' -and $_.Status -eq 'MISSING'})
$missingRecommended=@($results|Where-Object {$_.Level -eq 'Recommended' -and $_.Status -eq 'MISSING'})
Write-Output "Environment Profile"
foreach($p in $selectedProfiles){$state=if(@($results|Where-Object {$_.Profile -eq $p -and $_.Status -eq 'MISSING' -and $_.Level -eq 'Mandatory'}).Count){'BLOCKED'}elseif(@($results|Where-Object {$_.Profile -eq $p -and $_.Status -eq 'MISSING'}).Count){'WARN'}else{'PASS'};Write-Output "$p $state"}
Write-Output "Mandatory Dependencies: $(@($results|Where-Object Level -eq Mandatory).Count) checked; Missing: $($missingMandatory.Count)"
Write-Output "Recommended Dependencies: $(@($results|Where-Object Level -eq Recommended).Count) checked; Missing: $($missingRecommended.Count)"
Write-Output "Optional Dependencies: $(@($results|Where-Object Level -eq Optional).Count) checked"
if($missingMandatory.Count){Write-Output 'Overall BLOCKED';$missingMandatory|ForEach-Object {Write-Output "Required action: $($_.Name) -> $($_.Install)"};exit 2}
if($missingRecommended.Count){Write-Output 'Overall READY_WITH_WARNINGS'}else{Write-Output 'Overall READY'}
