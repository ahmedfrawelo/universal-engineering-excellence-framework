[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('Enable','Disable')][string]$State,
  [string]$CodexHome = '',
  [int]$TimeoutMilliseconds = 750
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'resolve-codex-home.ps1')
$CodexHome = Resolve-CodexHome -Override $CodexHome
$configPath = Join-Path $CodexHome 'config.toml'
if (!(Test-Path -LiteralPath $configPath -PathType Leaf)) { throw "Codex config not found: $configPath" }

$text = [IO.File]::ReadAllText($configPath)
$sectionPattern = '(?ms)^\[mcp_servers\.penpot\]\s*\r?\n(?<body>.*?)(?=^\[|\z)'
$match = [regex]::Match($text, $sectionPattern)
if (!$match.Success) { throw 'Penpot MCP is not configured under [mcp_servers.penpot].' }
$body = $match.Groups['body'].Value
$urlMatch = [regex]::Match($body, '(?m)^\s*url\s*=\s*["''](?<url>[^"'']+)["'']\s*$')
if (!$urlMatch.Success) { throw 'Penpot MCP section has no URL.' }
$endpoint = [uri]$urlMatch.Groups['url'].Value
if (!$endpoint.IsLoopback) { throw "Refusing a non-loopback Penpot endpoint: $endpoint" }

if ($State -eq 'Enable') {
  $client = [Net.Sockets.TcpClient]::new()
  try {
    $connect = $client.ConnectAsync($endpoint.Host, $endpoint.Port)
    if (!$connect.Wait($TimeoutMilliseconds) -or !$client.Connected) { throw "Penpot endpoint is not reachable at $($endpoint.Host):$($endpoint.Port). Start the local bridge and connect the Penpot plugin first." }
  } finally { $client.Dispose() }
}

$enabledValue = if ($State -eq 'Enable') { 'true' } else { 'false' }
if ($body -match '(?m)^\s*enabled\s*=') { $body = [regex]::Replace($body, '(?m)^\s*enabled\s*=\s*(true|false)\s*$', "enabled = $enabledValue") } else { $body += "enabled = $enabledValue`r`n" }
if ($body -match '(?m)^\s*required\s*=') { $body = [regex]::Replace($body, '(?m)^\s*required\s*=\s*(true|false)\s*$', 'required = false') } else { $body += "required = false`r`n" }
$body = $body.TrimEnd("`r","`n") + "`r`n`r`n"
$replacement = "[mcp_servers.penpot]`r`n$body"
$updated = $text.Substring(0, $match.Index) + $replacement + $text.Substring($match.Index + $match.Length)
$temporary = "$configPath.$([guid]::NewGuid().ToString('N')).tmp"
[IO.File]::WriteAllText($temporary, $updated, [Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $temporary -Destination $configPath -Force
Write-Output "Penpot MCP: $($State.ToUpperInvariant())"
Write-Output "Endpoint: $endpoint"
Write-Output 'Required: false'
