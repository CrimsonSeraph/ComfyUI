param(
  [int]$Port = 8188,
  [int]$TimeoutSec = 600,
  [switch]$NoWait
)

# ComfyUI launcher helper.
# Waits until the ComfyUI server listens on 127.0.0.1:$Port, then opens the UI in a
# dedicated browser *application* window (Edge --app, falling back to Chrome --app,
# then to the system default browser).
#
# Kept ASCII-only on purpose: Windows PowerShell 5.1 reads .ps1 as ANSI unless the
# file has a BOM, so non-ASCII text here would be at the mercy of the code page.

$ErrorActionPreference = 'Stop'

function Test-LocalPort {
  param([int]$P)
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $iar = $client.BeginConnect('127.0.0.1', $P, $null, $null)
    if (-not $iar.AsyncWaitHandle.WaitOne(500)) { return $false }
    $client.EndConnect($iar)
    return $true
  } catch {
    return $false
  } finally {
    $client.Close()
  }
}

function Get-AppBrowser {
  $candidates = New-Object System.Collections.Generic.List[string]
  $pf86  = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)', 'Process')
  $pf    = [Environment]::GetEnvironmentVariable('ProgramFiles', 'Process')
  $local = [Environment]::GetEnvironmentVariable('LocalAppData', 'Process')

  if ($pf86)  { $candidates.Add((Join-Path $pf86  'Microsoft\Edge\Application\msedge.exe')) }
  if ($pf)    { $candidates.Add((Join-Path $pf    'Microsoft\Edge\Application\msedge.exe')) }
  if ($local) { $candidates.Add((Join-Path $local 'Microsoft\Edge\Application\msedge.exe')) }
  if ($pf)    { $candidates.Add((Join-Path $pf    'Google\Chrome\Application\chrome.exe')) }
  if ($pf86)  { $candidates.Add((Join-Path $pf86  'Google\Chrome\Application\chrome.exe')) }
  if ($local) { $candidates.Add((Join-Path $local 'Google\Chrome\Application\chrome.exe')) }

  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  return $null
}

$url = "http://127.0.0.1:$Port"

# Wait for the server to accept connections (it may still be loading models after that).
if (-not $NoWait) {
  if (-not (Test-LocalPort -P $Port)) {
    Write-Host "[launcher] Waiting for ComfyUI on $url ..."
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
      if (Test-LocalPort -P $Port) { break }
      Start-Sleep -Milliseconds 500
    }
  }
}

if (Test-LocalPort -P $Port) {
  Write-Host "[launcher] ComfyUI is listening on $url"
} else {
  Write-Host "[launcher] WARNING: nothing is listening on $url yet; opening the window anyway."
}

$browser = Get-AppBrowser
if ($browser) {
  $browserArgs = @("--app=$url")
  if ($env:COMFY_WINDOW_SIZE)        { $browserArgs += "--window-size=$($env:COMFY_WINDOW_SIZE)" }
  if ($env:COMFY_EDGE_PROFILE_DIR)   { $browserArgs += "--user-data-dir=$($env:COMFY_EDGE_PROFILE_DIR)" }
  Write-Host "[launcher] Opening app window: $browser"
  Start-Process -FilePath $browser -ArgumentList $browserArgs
} else {
  Write-Host "[launcher] No Edge/Chrome found; falling back to the default browser."
  Start-Process $url
}
