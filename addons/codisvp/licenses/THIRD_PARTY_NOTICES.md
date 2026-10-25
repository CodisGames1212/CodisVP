# Third-party dependencies

CodisVP uses the official godot-cpp bindings, licensed under MIT. Its notice is included in `godot-cpp-MIT.txt`. Source: https://github.com/godotengine/godot-cpp, revision `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5` for the validated build.

The validated Windows build links dynamically to FFmpeg 8.1 LGPL shared libraries supplied by BtbN. FFmpeg is copyright its developers and licensed under LGPL version 3 or later for this distribution. The supplied license is included in `FFmpeg-LGPL-3.0.txt`. Source and build configuration: https://github.com/BtbN/FFmpeg-Builds and https://ffmpeg.org/. The release asset, digest, and godot-cpp revision are recorded in `native/dependencies.lock.json` in the source project. The validated FFmpeg version is `n8.1.3-14-g330caae0c1-20261005`.

FFmpeg packages may include additional libraries with their own notices and source obligations. Preserve the notices and corresponding-source information from the SDK when distributing its binaries. The minimal five DLLs needed here are avcodec, avformat, avutil, swresample, and swscale. A different FFmpeg build can have different dependencies and licensing.

Non-Windows GitHub Actions builds use FFmpeg 8.0.1, compiled from
https://ffmpeg.org/releases/ffmpeg-8.0.1.tar.xz under LGPL 2.1 or later, with
GPL/nonfree components and external codec dependencies disabled. Its license is
included as FFmpeg-LGPL-2.1.txt. Matching relink artifacts contain the corresponding
source, static archives, extension objects and instructions; preserve these with
binary distributions. Build configuration is in tools/ci/build_unix.sh.

No FFmpeg example source was copied into this extension. The decoder uses FFmpeg's public API.
