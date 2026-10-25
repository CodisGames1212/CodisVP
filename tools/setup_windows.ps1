param([string]$GodotCppRevision = '507ed9d840c01a3c5b2a39af8bb4000bfac30bf5')
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force third_party | Out-Null
Set-Content third_party/.gdignore ''
if (-not (Test-Path third_party/godot-cpp/CMakeLists.txt)) {
    git clone https://github.com/godotengine/godot-cpp.git third_party/godot-cpp
    if ($LASTEXITCODE -ne 0) { throw 'godot-cpp download failed' }
    git -C third_party/godot-cpp checkout $GodotCppRevision
    if ($LASTEXITCODE -ne 0) { throw 'godot-cpp checkout failed' }
}
$release = Invoke-RestMethod https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest
$asset = $release.assets | Where-Object name -eq 'ffmpeg-n8.1-latest-win64-lgpl-shared-8.1.zip'
if (-not $asset) { throw 'FFmpeg 8.1 LGPL shared SDK unavailable; set FFMPEG_ROOT manually.' }
Invoke-WebRequest $asset.browser_download_url -OutFile third_party/ffmpeg.zip
if ($asset.digest -like 'sha256:*') {
    $actual = (Get-FileHash third_party/ffmpeg.zip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $asset.digest.Substring(7)) { throw 'FFmpeg checksum mismatch' }
}
Expand-Archive third_party/ffmpeg.zip third_party/ffmpeg -Force
$release | ConvertTo-Json -Depth 10 | Set-Content third_party/ffmpeg-release.json
New-Item -ItemType Directory -Force addons/codisvp/licenses | Out-Null
Copy-Item third_party/ffmpeg/ffmpeg-n8.1-latest-win64-lgpl-shared-8.1/LICENSE.txt addons/codisvp/licenses/FFmpeg-LGPL-3.0.txt
Copy-Item third_party/godot-cpp/LICENSE.md addons/codisvp/licenses/godot-cpp-MIT.txt
Write-Output 'Dependencies ready. Run .\tools\build_windows.cmd.'
