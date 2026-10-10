param([Parameter(Mandatory = $true)][string]$GamePath)
$ErrorActionPreference = 'Stop'
$taskGameRoot = (Resolve-Path -LiteralPath $GamePath).Path
if (-not (Test-Path -LiteralPath (Join-Path $taskGameRoot 'FreeKill.exe'))) {
  throw 'GamePath必须指向含FreeKill.exe的目录。'
}
$taskSource = Join-Path $PSScriptRoot 'diy_sunjiale'
$taskDestination = Join-Path $taskGameRoot 'packages/diy_sunjiale'
if (Test-Path -LiteralPath $taskDestination) { throw '同名扩展已存在；请备份后再安装。' }
$taskManifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'client-patches/manifest.json') -Raw | ConvertFrom-Json
foreach ($taskEntry in $taskManifest) {
  $taskTarget = Join-Path $taskGameRoot $taskEntry.path
  if (-not (Test-Path -LiteralPath $taskTarget)) { throw "找不到游戏文件：$taskTarget" }
  $taskText = [System.IO.File]::ReadAllText($taskTarget).Replace("`r`n", "`n")
  $taskSha = [System.Security.Cryptography.SHA256]::Create()
  try { $taskHashBytes = $taskSha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($taskText)) }
  finally { $taskSha.Dispose() }
  $taskHash = [System.BitConverter]::ToString($taskHashBytes).Replace('-', '').ToLowerInvariant()
  if ($taskHash -ne $taskEntry.original -and $taskHash -ne $taskEntry.patched) {
    throw "游戏文件与目标版本不符，未修改：$taskTarget"
  }
}
foreach ($taskEntry in $taskManifest) {
  $taskTarget = Join-Path $taskGameRoot $taskEntry.path
  $taskBackup = "$taskTarget.before-sunjiale"
  if (-not (Test-Path -LiteralPath $taskBackup)) { Copy-Item -LiteralPath $taskTarget -Destination $taskBackup }
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('client-patches/' + $taskEntry.path)) -Destination $taskTarget -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $taskGameRoot 'packages') | Out-Null
Copy-Item -LiteralPath $taskSource -Destination $taskDestination -Recurse
foreach ($taskName in @('update-sunjiale.ps1', '双击更新.cmd')) {
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot $taskName) -Destination (Join-Path $taskGameRoot $taskName) -Force
}
Write-Output 'DIY武将扩展与兼容补丁已安装。请重启新月杀。'
