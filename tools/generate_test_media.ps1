param([string]$FFmpeg = "$PSScriptRoot/../third_party/ffmpeg/ffmpeg-n8.1-latest-win64-lgpl-shared-8.1/bin/ffmpeg.exe")
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force tests/media | Out-Null
foreach ($format in @('mp4','mkv','avi','mov','webm')) {
    $codec = if ($format -eq 'webm') { 'libvpx-vp9' } else { 'mpeg4' }
    $audio = if ($format -eq 'webm') { 'libopus' } elseif ($format -eq 'avi') { 'pcm_s16le' } else { 'aac' }
    & $FFmpeg -hide_banner -loglevel error -y -f lavfi -i 'color=c=red:s=160x90:r=30:d=1' -f lavfi -i 'color=c=blue:s=160x90:r=30:d=1' -f lavfi -i 'sine=frequency=440:sample_rate=48000:duration=2' -filter_complex '[0:v][1:v]concat=n=2:v=1:a=0[v]' -map '[v]' -map '2:a' -c:v $codec -c:a $audio -shortest "tests/media/sample.$format"
    if ($LASTEXITCODE -ne 0) { throw "Cannot generate $format fixture" }
}
& $FFmpeg -hide_banner -loglevel error -y -i tests/media/sample.mp4 -an -c:v copy tests/media/silent.mp4
if ($LASTEXITCODE -ne 0) { throw 'Cannot generate silent fixture' }
& $FFmpeg -hide_banner -loglevel error -y -i tests/media/sample.mp4 -c:v libopenh264 -c:a copy tests/media/hardware.mp4
if ($LASTEXITCODE -ne 0) { throw 'Cannot generate H.264 fixture' }
