param([string]$GamePath = $PSScriptRoot, [string]$PackagePath, [string]$ExpectedSha256)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$taskRepo = 'ToyWitH/FreeKill_DIY_Extensions'
$taskPatchPaths = @('LunarLtk/Components/Photo/EquipItem.qml', 'LunarLtk/Models/RoomModel.qml', 'LunarLtk/LtkLuaUtil.qml', 'ltk/core/request_type/play_card.lua', 'ltk/server/room.lua')
$taskGameRoot = (Resolve-Path -LiteralPath $GamePath).Path.TrimEnd('\')
function Get-TaskPath([string]$Base, [string]$Relative) {
  $taskResult = [IO.Path]::GetFullPath((Join-Path $Base $Relative))
  if (-not $taskResult.StartsWith($Base.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw '路径超出更新目录。' }
  return $taskResult
}
function Get-TaskHash([string]$Path, [switch]$Normalize) {
  if ($Normalize) {
    $taskBytes = [Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($Path).Replace("`r`n", "`n"))
    $taskSha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($taskSha.ComputeHash($taskBytes))).Replace('-', '').ToLowerInvariant() }
    finally { $taskSha.Dispose() }
  }
  $taskStream = [IO.File]::OpenRead($Path)
  $taskSha = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($taskSha.ComputeHash($taskStream))).Replace('-', '').ToLowerInvariant() }
  finally { $taskStream.Dispose(); $taskSha.Dispose() }
}
function Invoke-TaskDownload([string]$Uri, [string]$OutFile, [switch]$Binary) {
  $taskHeaders = @{'User-Agent'='FreeKill-DIY-Updater'; Accept='application/vnd.github+json'; 'X-GitHub-Api-Version'='2022-11-28'}
  if ($Binary) { $taskHeaders.Accept = 'application/octet-stream' }
  for ($taskAttempt = 1; $taskAttempt -le 3; $taskAttempt++) {
    try {
      if ($OutFile) { Invoke-WebRequest -Uri $Uri -Headers $taskHeaders -UseBasicParsing -TimeoutSec 30 -OutFile $OutFile; return }
      return Invoke-RestMethod -Uri $Uri -Headers $taskHeaders -TimeoutSec 30
    } catch {
      if ($taskAttempt -eq 3) { throw '连接GitHub失败，请检查网络后再次双击更新。游戏文件未因下载失败而修改。' }
      Start-Sleep -Seconds 2
    }
  }
}

$taskWork = $null
$taskLock = $null
$taskBackup = $null
$taskFileChanges = @()
$taskOldMoved = $false
$taskNewMoved = $false
try {
  $taskExe = Join-Path $taskGameRoot 'FreeKill.exe'
  if (-not (Test-Path -LiteralPath $taskExe -PathType Leaf)) { throw '请将更新器放在FreeKill.exe所在目录。' }
  if (([IO.File]::ReadAllText((Join-Path $taskGameRoot 'fk_ver'))).Trim().TrimStart('v') -ne '0.5.25') { throw '本更新器适用于新月杀v0.5.25。请使用配套懒人包。' }
  foreach ($taskProcess in (Get-Process FreeKill -ErrorAction SilentlyContinue)) {
    if ($taskProcess.Path -eq $taskExe) { throw '请先完全关闭新月杀，再双击更新。' }
  }
  $taskLockPath = Get-TaskPath $taskGameRoot '.sunjiale-update.lock'
  $taskLock = [IO.File]::Open($taskLockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
  $taskWork = Get-TaskPath $taskGameRoot ('.sunjiale-update/' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $taskWork -Force | Out-Null
  $taskZip = Join-Path $taskWork 'update.zip'
  if ($PackagePath) {
    if ($ExpectedSha256 -notmatch '^[a-fA-F0-9]{64}$') { throw '离线更新需要提供安装包SHA256。' }
    Copy-Item -LiteralPath $PackagePath -Destination $taskZip
  } else {
    Write-Host '正在检查DIY武将扩展的最新版本……'
    $taskRelease = Invoke-TaskDownload ('https://api.github.com/repos/' + $taskRepo + '/releases/latest')
    $taskAssetName = 'FreeKill_diy_sunjiale-' + $taskRelease.tag_name + '.zip'
    $taskAssets = @($taskRelease.assets | Where-Object {$_.name -eq $taskAssetName -and $_.state -eq 'uploaded'})
    if ($taskAssets.Count -ne 1 -or $taskAssets[0].digest -notmatch '^sha256:([a-fA-F0-9]{64})$') { throw '最新发布未附完整更新包或校验值，请稍后重试。' }
    $ExpectedSha256 = $Matches[1]
    Write-Host "正在下载 $($taskRelease.tag_name)（仅更新扩展与补丁）……"
    Invoke-TaskDownload ('https://api.github.com/repos/' + $taskRepo + '/releases/assets/' + [long]$taskAssets[0].id) $taskZip -Binary
  }
  if ((Get-TaskHash $taskZip) -ne $ExpectedSha256.ToLowerInvariant()) { throw '安装包完整性校验失败，未修改游戏文件。' }
  $taskExtract = Join-Path $taskWork 'extracted'
  New-Item -ItemType Directory -Path $taskExtract | Out-Null
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $taskArchive = [IO.Compression.ZipFile]::OpenRead($taskZip)
  $taskZipNames = @{}
  try {
    foreach ($taskEntry in $taskArchive.Entries) {
      $taskName = $taskEntry.FullName.Replace('\', '/')
      if ($taskName -match '(^/|:|(^|/)\.\.(/|$))' -or (($taskEntry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw '安装包含不安全路径，未修改游戏文件。' }
      $null = Get-TaskPath $taskExtract $taskName
      if ($taskName.EndsWith('/')) { continue }
      if ($taskZipNames.ContainsKey($taskName)) { throw '安装包存在重复文件。' }
      $taskZipNames[$taskName] = $true
    }
  } finally { $taskArchive.Dispose() }
  [IO.Compression.ZipFile]::ExtractToDirectory($taskZip, $taskExtract)
  $taskManifest = Get-Content -LiteralPath (Join-Path $taskExtract 'update-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($taskManifest.format -ne 1 -or $taskManifest.game_version -ne '0.5.25' -or $taskManifest.version -notmatch '^\d+\.\d+\.\d+$') { throw '更新包格式或游戏版本不匹配。' }
  if ($taskRelease -and ('v' + $taskManifest.version) -ne $taskRelease.tag_name) { throw '更新包版本与发布版本不匹配。' }
  $taskSeen = @{}
  foreach ($taskEntry in $taskManifest.files) {
    if ($taskSeen.ContainsKey($taskEntry.path) -or -not $taskZipNames.ContainsKey($taskEntry.path)) { throw '更新包文件清单不一致。' }
    $taskSeen[$taskEntry.path] = $true
    if ((Get-TaskHash (Get-TaskPath $taskExtract $taskEntry.path)) -ne $taskEntry.sha256) { throw '更新包文件校验失败。' }
  }
  if ($taskSeen.Count -ne $taskZipNames.Count - 1 -or -not $taskZipNames.ContainsKey('update-manifest.json')) { throw '更新包存在未列入清单的文件。' }
  $taskStatePath = Get-TaskPath $taskGameRoot '.sunjiale-update-state.json'
  $taskOldState = $null
  if (Test-Path -LiteralPath $taskStatePath -PathType Leaf) { $taskOldState = Get-Content -LiteralPath $taskStatePath -Raw -Encoding UTF8 | ConvertFrom-Json }
  if ($taskOldState -and [version]$taskOldState.version -gt [version]$taskManifest.version) { throw '已安装版本更新，未自动降级。' }
  $taskPatches = @((Get-Content -LiteralPath (Join-Path $taskExtract 'client-patches/manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object {$_})
  if ($taskPatches.Count -ne $taskPatchPaths.Count -or @($taskPatches.path | Select-Object -Unique).Count -ne $taskPatchPaths.Count) { throw '补丁清单不匹配。' }
  foreach ($taskPatch in $taskPatches) {
    if ($taskPatch.path -notin $taskPatchPaths) { throw '更新包含不支持的游戏补丁。' }
    $taskTarget = Get-TaskPath $taskGameRoot $taskPatch.path
    $taskHash = Get-TaskHash $taskTarget -Normalize
    $taskPrevious = @($taskOldState.patches | Where-Object {$_.path -eq $taskPatch.path})
    $taskAllowed = @($taskPatch.original, $taskPatch.patched) + @($taskPrevious | ForEach-Object {$_.patched})
    if ($taskHash -notin $taskAllowed) { throw "游戏文件版本不符或被其他扩展修改，未覆盖：$($taskPatch.path)" }
    if ((Get-TaskHash (Get-TaskPath $taskExtract ('client-patches/' + $taskPatch.path)) -Normalize) -ne $taskPatch.patched) { throw '补丁文件与清单不一致。' }
  }
  $taskExtension = Get-TaskPath $taskGameRoot 'packages/diy_sunjiale'
  if (-not (Test-Path -LiteralPath (Join-Path $taskExtract 'diy_sunjiale/init.lua') -PathType Leaf)) { throw '更新包缺少武将入口。' }
  $taskSame = $taskOldState -and $taskOldState.archive_sha256 -eq $ExpectedSha256.ToLowerInvariant()
  foreach ($taskEntry in $taskManifest.files | Where-Object {$_.path.StartsWith('diy_sunjiale/')}) {
    $taskTarget = Get-TaskPath $taskGameRoot ('packages/' + $taskEntry.path)
    if (-not (Test-Path -LiteralPath $taskTarget -PathType Leaf) -or (Get-TaskHash $taskTarget) -ne $taskEntry.sha256) { $taskSame = $false }
  }
  foreach ($taskPatch in $taskPatches) { if ((Get-TaskHash (Get-TaskPath $taskGameRoot $taskPatch.path) -Normalize) -ne $taskPatch.patched) { $taskSame = $false } }
  foreach ($taskName in @('update-sunjiale.ps1', '双击更新.cmd')) {
    if (-not (Test-Path -LiteralPath (Join-Path $taskGameRoot $taskName) -PathType Leaf) -or (Get-TaskHash (Join-Path $taskGameRoot $taskName)) -ne (Get-TaskHash (Join-Path $taskExtract $taskName))) { $taskSame = $false }
  }
  if ($taskSame) { Write-Host "已经是最新版本 v$($taskManifest.version)。"; return }
  $taskBackup = Get-TaskPath $taskGameRoot ('update-backups/' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $taskBackup -Force | Out-Null
  $taskCopies = @($taskPatches | ForEach-Object {@{source=(Join-Path $taskExtract ('client-patches/' + $_.path)); target=$_.path}})
  $taskCopies += @(@{source=(Join-Path $taskExtract 'update-sunjiale.ps1'); target='update-sunjiale.ps1'}, @{source=(Join-Path $taskExtract '双击更新.cmd'); target='双击更新.cmd'})
  $taskNewStatePath = Join-Path $taskWork 'new-state.json'
  @{format=1; version=$taskManifest.version; archive_sha256=$ExpectedSha256.ToLowerInvariant(); patches=$taskPatches} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $taskNewStatePath -Encoding UTF8
  $taskCopies += @{source=$taskNewStatePath; target='.sunjiale-update-state.json'}
  foreach ($taskCopy in $taskCopies) {
    $taskTarget = Get-TaskPath $taskGameRoot $taskCopy.target
    $taskSaved = Get-TaskPath $taskBackup $taskCopy.target
    $taskExists = Test-Path -LiteralPath $taskTarget -PathType Leaf
    if ($taskExists) { New-Item -ItemType Directory -Path (Split-Path $taskSaved) -Force | Out-Null; Copy-Item -LiteralPath $taskTarget -Destination $taskSaved }
    $taskCopy.saved = $taskSaved
    $taskCopy.existed = $taskExists
  }
  New-Item -ItemType Directory -Path (Split-Path $taskExtension) -Force | Out-Null
  if (Test-Path -LiteralPath $taskExtension) {
    Move-Item -LiteralPath $taskExtension -Destination (Get-TaskPath $taskBackup 'extension')
    $taskOldMoved = $true
  }
  Move-Item -LiteralPath (Get-TaskPath $taskExtract 'diy_sunjiale') -Destination $taskExtension
  $taskNewMoved = $true
  foreach ($taskCopy in $taskCopies) {
    $taskTarget = Get-TaskPath $taskGameRoot $taskCopy.target
    if ($taskCopy.existed -and (Get-TaskHash $taskTarget) -eq (Get-TaskHash $taskCopy.source)) { continue }
    $taskFileChanges += $taskCopy
    Copy-Item -LiteralPath $taskCopy.source -Destination $taskTarget -Force
  }
  Write-Host "更新成功：v$($taskManifest.version)。账号、设置与录像已保留。"
  Write-Host "上一版备份：$taskBackup"
} catch {
  $taskFailure = $_.Exception.Message
  $taskRollbackErrors = @()
  foreach ($taskCopy in $taskFileChanges) {
    try {
      $taskTarget = Get-TaskPath $taskGameRoot $taskCopy.target
      if ($taskCopy.existed) {
        if ((Test-Path -LiteralPath $taskTarget -PathType Leaf) -and (Get-TaskHash $taskTarget) -eq (Get-TaskHash $taskCopy.saved)) { continue }
        Copy-Item -LiteralPath $taskCopy.saved -Destination $taskTarget -Force
      } elseif (Test-Path -LiteralPath $taskTarget -PathType Leaf) { Remove-Item -LiteralPath $taskTarget }
    } catch { $taskRollbackErrors += $_.Exception.Message }
  }
  try {
    if ($taskNewMoved) { Move-Item -LiteralPath $taskExtension -Destination (Get-TaskPath $taskWork 'failed-extension') }
    if ($taskOldMoved) { Move-Item -LiteralPath (Get-TaskPath $taskBackup 'extension') -Destination $taskExtension }
  } catch { $taskRollbackErrors += $_.Exception.Message }
  if ($taskRollbackErrors.Count) { Write-Host "更新未完成，部分文件需从备份恢复：$taskBackup"; throw ($taskFailure + '；' + ($taskRollbackErrors -join '；')) }
  if ($taskOldMoved -or $taskNewMoved -or $taskFileChanges.Count) { Write-Host '更新失败，已恢复更新前的扩展与补丁。' }
  throw $taskFailure
} finally {
  if ($taskLock) { $taskLock.Dispose() }
  if ($taskWork -and (Test-Path -LiteralPath $taskWork) -and -not $taskRollbackErrors.Count) {
    $null = Get-TaskPath $taskGameRoot $taskWork.Substring($taskGameRoot.Length + 1)
    Remove-Item -LiteralPath $taskWork -Recurse -Force
  }
}
