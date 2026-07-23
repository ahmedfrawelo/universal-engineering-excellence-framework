[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('solo','startup','enterprise','regulated')][string]$Profile,[string]$ConfigPath=(Join-Path (Split-Path -Parent $PSScriptRoot) 'config\team-policy-profiles.json'),[switch]$Json)
$ErrorActionPreference='Stop';$doc=Get-Content $ConfigPath -Raw|ConvertFrom-Json;if($doc.schemaVersion -ne 1){throw 'Unsupported team-policy schema.'};$chain=[Collections.Generic.List[string]]::new();$values=@{};$current=$Profile
while($current){if($chain.Contains($current)){throw 'Cyclic team-policy inheritance.'};$chain.Add($current);$item=$doc.profiles.$current;if(!$item){throw "Unknown profile: $current"};$item.psobject.Properties|Where-Object Name -ne 'extends'|ForEach-Object{if(!$values.ContainsKey($_.Name)){$values[$_.Name]=$_.Value}};$current=$item.extends}
$result=[ordered]@{schemaVersion=1;profile=$Profile;precedence=@($chain);policy=$values;automaticMutation=$false};if($Json){$result|ConvertTo-Json -Depth 4}else{$result|Format-List}
