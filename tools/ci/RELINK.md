# Relinking the Unix builds

These CI builds statically link LGPL FFmpeg, with GPL and nonfree components
disabled. Keep this artifact available alongside the matching add-on distribution.
It contains the FFmpeg source archive, static libraries, extension object files,
Godot binding archive, generated Ninja link rules, and FFmpeg configuration.

Use the same platform SDK/compiler as the workflow. Extract and modify the FFmpeg
source, rebuild it using the configure options in source/ci/build_unix.sh and the
recorded ffmpeg/config.mak, then replace the FFmpeg archives in the recorded Ninja
link command. Adjust absolute paths to your extracted objects, libraries and SDK.
The native/build.ninja file records the original link flags and system libraries.
For iOS, recreate/sign the framework using your own Apple signing identity.

You may also rebuild from the complete CodisVP source with the pinned godot-cpp
revision in BUILD.txt and your modified FFmpeg SDK. Set CODISVP_STATIC_FFMPEG=ON
and FFMPEG_ROOT to the replacement SDK prefix when configuring CMake.
