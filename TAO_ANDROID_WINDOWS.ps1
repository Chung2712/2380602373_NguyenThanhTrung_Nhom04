# Run AFTER: python rename_project.py NguyenThanhTrungThat
# Requires Flutter SDK on PATH and Flutter >= 3.41 / Dart >= 3.11.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Khong tim thay lenh flutter. Cai Flutter SDK va them vao PATH.'
}
$yaml = Get-Content (Join-Path $PSScriptRoot 'pubspec.yaml') -Raw
if ($yaml -notmatch '(?m)^name:\s*([a-z][a-z0-9_]*)') { throw 'Khong doc duoc pubspec name.' }
$projectName = $Matches[1]
$owner = $projectName.Split('_')[0]
if ($owner -eq ('ten' + 'canhan')) { throw 'Phai doi ten ca nhan that TRUOC khi tao project.' }
$backup = Join-Path ([IO.Path]::GetTempPath()) ('smartguard_backup_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'lib') (Join-Path $backup 'lib') -Recurse
Copy-Item (Join-Path $PSScriptRoot 'pubspec.yaml') (Join-Path $backup 'pubspec.yaml')
Copy-Item (Join-Path $PSScriptRoot 'analysis_options.yaml') (Join-Path $backup 'analysis_options.yaml')
try {
  flutter create --platforms=android --org "com.$owner" --project-name "$projectName" .
  if ($LASTEXITCODE -ne 0) { throw 'flutter create that bai' }
  Remove-Item (Join-Path $PSScriptRoot 'lib') -Recurse -Force
  Copy-Item (Join-Path $backup 'lib') (Join-Path $PSScriptRoot 'lib') -Recurse
  Copy-Item (Join-Path $backup 'pubspec.yaml') (Join-Path $PSScriptRoot 'pubspec.yaml') -Force
  Copy-Item (Join-Path $backup 'analysis_options.yaml') (Join-Path $PSScriptRoot 'analysis_options.yaml') -Force
  $manifest = Join-Path $PSScriptRoot 'android/app/src/main/AndroidManifest.xml'
  $raw = Get-Content $manifest -Raw
  if (-not $raw.Contains('android.permission.CAMERA')) {
    $perms = @'
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
'@
    $raw = $raw.Replace('<application', $perms + "`n    <application")
    Set-Content -Path $manifest -Value $raw -Encoding utf8
  }
  $debugDir = Join-Path $PSScriptRoot 'android/app/src/debug'
  New-Item -ItemType Directory -Path $debugDir -Force | Out-Null
  $debugManifest = @'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:usesCleartextTraffic="true" />
</manifest>
'@
  Set-Content -Path (Join-Path $debugDir 'AndroidManifest.xml') -Value $debugManifest -Encoding utf8
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get that bai' }
  Write-Host 'DA TAO ANDROID FLUTTER. Run: flutter run'
 } finally {
  # Always restore project-specific source after flutter create, including failed runs.
  if (Test-Path (Join-Path $PSScriptRoot 'lib')) {
    Remove-Item (Join-Path $PSScriptRoot 'lib') -Recurse -Force
  }
  Copy-Item (Join-Path $backup 'lib') (Join-Path $PSScriptRoot 'lib') -Recurse
  Copy-Item (Join-Path $backup 'pubspec.yaml') (Join-Path $PSScriptRoot 'pubspec.yaml') -Force
  Copy-Item (Join-Path $backup 'analysis_options.yaml') (Join-Path $PSScriptRoot 'analysis_options.yaml') -Force
  Remove-Item $backup -Recurse -Force -ErrorAction SilentlyContinue
}
