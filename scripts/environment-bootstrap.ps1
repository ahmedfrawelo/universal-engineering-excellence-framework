param(
  [string[]]$Profile = @('Core','AI'),
  [switch]$Install
)
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$CodexHome=if($env:CODEX_HOME){$env:CODEX_HOME}elseif($env:UEEF_GLOBAL_PATH){Split-Path -Parent $env:UEEF_GLOBAL_PATH}else{''}
$Profile=@($Profile | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$allowed=@('Core','Frontend','Backend','Database','UIUX','DevOps','AI','Optional')
foreach($name in $Profile){if($allowed -notcontains $name){throw "Unknown environment profile: $name"}}
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
foreach($p in $Profile){
  switch($p){
    'Core' {
      Add-Check Core Git Mandatory (Ensure-Command git 'Git.Git') 'git command' 'winget install --id Git.Git -e'
      Add-Check Core 'GitHub CLI' Mandatory (Ensure-Command gh 'GitHub.cli') 'gh command; authentication is checked separately' 'winget install --id GitHub.cli -e'
      Add-Check Core 'Skill Installer' Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\.system\skill-installer\SKILL.md'))) 'Codex skill installer' 'Install from the Codex skill marketplace'
      Add-Check Core 'OpenAI Docs' Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\.system\openai-docs\SKILL.md'))) 'OpenAI docs skill' 'Install the openai-docs skill'
      Add-Check Core 'Skill Creator' Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\.system\skill-creator\SKILL.md'))) 'Skill creator skill' 'Install the skill-creator skill'
      Add-Check Core 'Validation Scripts' Mandatory (Has-Path (Join-Path $Root 'scripts\validate-framework.ps1')) 'repository validator'
      Add-Check Core 'UEEF Runtime' Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'ueef\codex\UEEF-LOADER.md'))) 'active runtime loader'
    }
    'AI' {
      Add-Check AI UEEF Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'ueef\codex\UEEF-LOADER.md'))) 'runtime loader'
      Add-Check AI 'Runtime Loader' Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'AGENTS.md'))) 'global agent rules'
    }
    'Frontend' {
      Add-Check Frontend Node Mandatory (Ensure-Command node 'OpenJS.NodeJS.LTS') 'node command' 'winget install OpenJS.NodeJS.LTS'
      Add-Check Frontend npm Mandatory (Ensure-Command npm 'OpenJS.NodeJS.LTS') 'npm command'
      Add-Check Frontend Playwright Recommended (Has-Command npx) 'npx can invoke Playwright'
      Add-Check Frontend 'UI UX Pro Max' Recommended ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\ui-ux-pro-max\SKILL.md'))) 'skill path' 'npx skills add github:https://github.com/nextlevelbuilder/ui-ux-pro-max-skill --skill ui-ux-pro-max'
      Add-Check Frontend Impeccable Recommended ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\impeccable\SKILL.md'))) 'skill path'
    }
    'Backend' { Add-Check Backend '.NET or Node or Python' Recommended ((Has-Command dotnet) -or (Has-Command node) -or (Has-Command python)) 'at least one detected backend runtime' }
    'Database' { Add-Check Database 'Database CLI' Recommended ((Has-Command sqlcmd) -or (Has-Command psql) -or (Has-Command mysql)) 'provider CLI detected' }
    'UIUX' { Add-Check UIUX 'UI UX Pro Max' Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\ui-ux-pro-max\SKILL.md'))) 'skill path'; Add-Check UIUX Impeccable Mandatory ([bool]$CodexHome -and (Has-Path (Join-Path $CodexHome 'skills\impeccable\SKILL.md'))) 'skill path'; Add-Check UIUX Playwright Recommended (Has-Command npx) 'npx available' }
    'DevOps' { Add-Check DevOps Docker Recommended (Has-Command docker) 'docker command'; Add-Check DevOps 'GitHub CLI' Mandatory (Has-Command gh) 'gh command' }
    'Optional' { Add-Check Optional 'Optional tools' Optional $true 'not blocking' }
  }
}
$results | Format-Table Profile,Name,Level,Status,Detail -AutoSize
$missingMandatory=@($results|Where-Object {$_.Level -eq 'Mandatory' -and $_.Status -eq 'MISSING'})
$missingRecommended=@($results|Where-Object {$_.Level -eq 'Recommended' -and $_.Status -eq 'MISSING'})
Write-Output "Environment Profile"
foreach($p in $Profile){$state=if(@($results|Where-Object {$_.Profile -eq $p -and $_.Status -eq 'MISSING' -and $_.Level -eq 'Mandatory'}).Count){'BLOCKED'}elseif(@($results|Where-Object {$_.Profile -eq $p -and $_.Status -eq 'MISSING'}).Count){'WARN'}else{'PASS'};Write-Output "$p $state"}
Write-Output "Mandatory Dependencies: $(@($results|Where-Object Level -eq Mandatory).Count) checked; Missing: $($missingMandatory.Count)"
Write-Output "Recommended Dependencies: $(@($results|Where-Object Level -eq Recommended).Count) checked; Missing: $($missingRecommended.Count)"
Write-Output "Optional Dependencies: $(@($results|Where-Object Level -eq Optional).Count) checked"
if($missingMandatory.Count){Write-Output 'Overall BLOCKED';$missingMandatory|ForEach-Object {Write-Output "Required action: $($_.Name) -> $($_.Install)"};exit 2}
if($missingRecommended.Count){Write-Output 'Overall READY_WITH_WARNINGS'}else{Write-Output 'Overall READY'}
