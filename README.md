# CodisVP

CodisVP adds FFmpeg video playback to Godot through a native GDExtension. Use the existing `VideoStreamPlayer` node to play MP4, WebM, MKV, AVI, MOV, and other video formats supported by your FFmpeg build.

Version 0.1.0 is an initial implementation. A Windows x86_64 build is present in this workspace and tested with Godot 4.7. Other platforms have source build targets but are not yet validated releases.

## Features

- Background video and audio decoding with bounded queues.
- Forward and backward seeking through `VideoStreamPlayer.stream_position`.
- Pause, stop, replay, and the player's normal looping controls.
- Timestamped audio resampled to stereo at 48 kHz, routed through `VideoStreamPlayer.bus` with normal volume controls.
- Hardware decoding with software fallback: NVDEC/CUDA and D3D11VA on Windows, VAAPI/CUDA on Linux, VideoToolbox on Apple platforms, and NDK MediaCodec on Android when those backends are compiled into FFmpeg.
- Godot `FileAccess` integration for external files, `res://`, `user://`, and media packed in exported PCK files.
- A demo with file selection, seeking, pause/resume, hardware decoding selection, audio bus selection, and decoder diagnostics.

Codec availability depends on the FFmpeg build. Hardware availability also depends on the GPU, drivers, codec, and video profile. Decoded hardware surfaces are copied to CPU memory for RGBA conversion and texture upload; this implementation does not provide zero-copy GPU rendering. Smooth playback at a particular resolution is not guaranteed.

## Platform status

| Platform | Status |
| --- | --- |
| Windows x86_64 | Built and tested: software decoding, NVIDIA NVDEC, D3D11VA, seeking, rendered frames, audio bus output, and PCK media access. |
| Linux x86_64 / arm64 | Source target; needs a matching FFmpeg SDK, dependency packaging, and runtime testing. |
| macOS x86_64 / arm64 / universal | Source target; needs a matching FFmpeg SDK, Frameworks packaging/signing, and runtime testing. |
| Android arm64 / x86_64 | Source target; needs an NDK FFmpeg build, native dependency packaging, and device testing. MediaCodec uses NDK byte buffers. |
| iOS arm64 | Source target; needs an Apple toolchain, FFmpeg build, framework/export integration, signing, and device testing. |

Bindings target the Godot 4.3 API. Runtime compatibility has been tested on Godot 4.7 with standard single-precision engine builds. Web exports and double-precision Godot builds are not supported by the supplied binaries.

## GitHub Actions builds

Download installable binaries from [GitHub Releases](https://github.com/CodisGames1212/CodisVP/releases).
Extract `CodisVP.zip` into your project. Each release also provides matching source,
FFmpeg relinking materials, build provenance, and SHA-256 checksums.

Maintainers can publish a successful build under **Actions → Release CodisVP**
by supplying its run ID and a version tag such as `v0.1.0`. The release workflow
verifies binary architectures and publishes the complete set of assets together.

`.github/workflows/build-plugin.yml` adapts the parallel-build and merged-add-on
pattern from [godot-plus-plus](https://github.com/nikoladevelops/godot-plus-plus)
to this project's CMake build and FFmpeg dependencies. It runs on pushes, pull
requests, and manual runs under **Actions → Build CodisVP**.

Targets: Windows x86_64, Linux x86_64/arm64, macOS x86_64/arm64, Android
arm64/x86_64 (API 24+), and an unsigned iOS arm64 framework (iOS 13+).
macOS uses separate architecture libraries. Web and 32-bit builds are excluded;
Web needs a separate FFmpeg/Emscripten and threading port.

Download **CodisVP-all-platforms** after a successful run, then extract its
`CodisVP.zip` into your project. The package job requires every expected binary
and Windows FFmpeg DLL before creating the ZIP. Platform artifacts are also
available separately. Compilation does not validate playback on devices; Apple
distribution still needs your signing identity and export testing.

Windows uses the existing FFmpeg 8.1 shared SDK helper and records upstream release
metadata. Other targets compile FFmpeg 8.0.1 as static PIC libraries, without
external codec dependencies, GPL/nonfree options, or network support. Apple builds
enable VideoToolbox; Android enables MediaCodec; Linux CI uses software decoding.
Codec availability differs from the Windows SDK. Keep matching `relink-*`
artifacts alongside distributions: they contain FFmpeg source, static archives,
extension objects and relinking instructions.

Commit the project source, including `native/`, `tools/`, `addons/codisvp/`, and
`CMakeLists.txt`, to the repository. CI downloads pinned godot-cpp itself;
the ignored `third_party/` and local build directories should stay untracked.

## Build on Windows

Install Git, CMake 3.22+, Python 3, and Visual Studio 2022 with the Desktop development with C++ workload and a Windows SDK. The build helper uses the Visual Studio developer environment and Ninja.

From the project directory:

```powershell
.\tools\setup_windows.ps1
.\tools\build_windows.cmd
```

Setup downloads a pinned godot-cpp revision and the current FFmpeg 8.1 LGPL shared SDK from BtbN, checking its SHA-256 digest when supplied by GitHub. The exact SDK and digest used for this workspace are recorded in `native/dependencies.lock.json`; the upstream `latest` FFmpeg asset can change. Build outputs and downloaded dependencies are excluded from version control.

To use your own FFmpeg development SDK:

```powershell
$env:FFMPEG_ROOT = 'C:\SDKs\ffmpeg'
.\tools\build_windows.cmd
```

The SDK must contain `include`, `lib`, and `bin` directories with matching shared-library headers, import libraries, and DLLs. The supplied extension manifest expects FFmpeg 8.x DLL names (`avcodec-62`, `avformat-62`, `avutil-60`, `swscale-9`, and `swresample-6`). Update its dependency entries if using a different ABI.

Close Godot before rebuilding a DLL it has loaded. Reopen the project after building, then press F6 on the demo scene or F5 to run the project.

## Install and use

Copy `addons/codisvp` into your project, including the built extension, FFmpeg runtime libraries, and third-party notices. Enable CodisVP under Project Settings → Plugins for its editor integration. The native extension and resource loader are registered when Godot loads the `.gdextension` file.

Assign a video to an existing player:

```gdscript
extends Control

@onready var player: VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
    player.stream = load("res://videos/intro.mp4")
    player.bus = &"Master" # Or an existing bus in your project.
    player.play()

func jump_to(seconds: float) -> void:
    player.stream_position = seconds
```

For an external file, an extension the resource loader does not recognize, or explicit software decoding:

```gdscript
var stream := VideoStreamCodisVP.new()
stream.file = "user://recordings/clip.mkv"
stream.hardware_decoding = false
$VideoStreamPlayer.stream = stream
$VideoStreamPlayer.play()
```

The resource loader recognizes `mp4`, `m4v`, `webm`, `mkv`, `avi`, `mov`, `mpeg`, `mpg`, `ts`, `m2ts`, `flv`, and `wmv`. Other containers can be opened by setting `VideoStreamCodisVP.file`. Existing Ogg Theora loading remains provided by Godot.

`hardware_decoding` applies when a new playback instance is created. Assign the stream again to change the decoding mode for an active player.

Diagnostics are available from the stream's most recently created playback instance:

```gdscript
var playback = player.stream.get_last_playback()
if playback:
    print(playback.get_decoder_backend()) # software, cuda, d3d11va, etc.
    playback.playback_error.connect(func(message): push_error(message))
    print(playback.get_last_error())
```

A shared stream can have multiple players; `get_last_playback()` reports only its most recent instance. Opening failures also appear in Godot's Output panel and return no playback instance.

## Export

The included Windows export preset packages video files and the native dependencies. Export from Godot's Export dialog, or:

```powershell
New-Item -ItemType Directory -Force build-export
godot --headless --path . --export-debug 'Windows Desktop' build-export/CodisVP.exe
```

For other projects, add video patterns to the export preset's non-resource inclusion filter, particularly for media loaded through a manually configured `file` property. Include the third-party notices as well. FFmpeg DLLs are listed in the extension's `[dependencies]` section so Godot copies them next to the Windows executable. Distribute the executable, PCK, extension DLL, and FFmpeg DLLs together.

Custom shared FFmpeg SDKs on other platforms need platform-specific runtime dependencies added to the manifest. The GitHub Actions builds instead link FFmpeg statically on non-Windows platforms.

## Other native builds

Use a matching godot-cpp checkout and FFmpeg development SDK:

```sh
cmake -S . -B build-native \
  -DGODOT_CPP_DIR=/path/to/godot-cpp \
  -DFFMPEG_ROOT=/path/to/ffmpeg-prefix \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build-native --parallel
```

For Android, supply the NDK's CMake toolchain, `ANDROID_ABI`, and `ANDROID_PLATFORM`, plus FFmpeg libraries built for that same ABI/API. For Apple platforms, supply the appropriate SDK, architecture, and deployment target. CMake names the extension for the detected platform and architecture and builds a framework for iOS. Shared FFmpeg dependencies must be packaged separately for custom SDK builds; the CI scripts automate static FFmpeg builds on non-Windows platforms.

## Verification

Generate local fixtures and run the integration tests with a Godot console executable:

```powershell
.\tools\generate_test_media.ps1
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/playback_test.gd
godot --path . --script tests/playback_test.gd --rendering-method gl_compatibility --audio-driver Dummy
```

The rendered run verifies red frames before seeking and blue frames after seeking. Both runs verify five containers, duration, clock advancement, pause, forward/backward seeking, stop/reset, replay, natural completion, audio reaching a configured bus, silent playback, and hardware-enabled H.264 playback. Hardware tests report the actual backend; fallback is valid on machines without an available decoder. Audio bus output is measured, but long-duration A/V drift and mobile performance have not been benchmarked.

To check media access in the exported PCK with the editor/console executable:

```powershell
godot --headless --main-pack build-export/CodisVP.pck --script res://tests/playback_test.gd
```

## Current limits

Local and packed files are supported; URLs, network streaming, subtitles, HDR tone mapping, and video rotation metadata are not implemented. Frames are displayed as SDR RGBA. Audio is downmixed to stereo. Seeks reset decoder queues, but the stock player's already-buffered audio can remain audible briefly after a seek. The current clock follows player updates and schedules audio with a short lead; this is not an audio-device-master clock. Audio track changes are implemented after stream assignment; initial non-default track selection through the stock player's preconfigured `audio_track` is not guaranteed across Godot versions.

Opening/probing and seek setup happen on the main thread; large files or long GOPs can add startup/seek latency. Decoding and conversion run on a worker, and rendering/mixing run on the main thread.

## Dependencies

See `addons/codisvp/licenses/THIRD_PARTY_NOTICES.md` and the included FFmpeg and godot-cpp license texts. The Windows helper uses LGPL shared FFmpeg libraries. Alternate FFmpeg builds can carry different licenses depending on their enabled components.
