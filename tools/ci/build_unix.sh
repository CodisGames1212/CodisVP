#!/usr/bin/env bash
set -euo pipefail
platform=${1:?platform required}
arch=${2:?architecture required}
root=$(pwd)
prefix="$root/build-ci/ffmpeg-sdk"
mkdir -p build-ci
curl --fail --location --retry 3 "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" -o build-ci/ffmpeg.tar.xz
tar -xf build-ci/ffmpeg.tar.xz -C build-ci
source_dir="$root/build-ci/ffmpeg-${FFMPEG_VERSION}"
ffargs=(--prefix="$prefix" --enable-static --disable-shared --enable-pic
  --disable-autodetect --disable-programs --disable-doc --disable-network
  --disable-avdevice --disable-avfilter --disable-encoders --disable-muxers)
cmargs=(-DCMAKE_BUILD_TYPE=Release -DGODOTCPP_TARGET=template_release
  -DCODISVP_STATIC_FFMPEG=ON "-DFFMPEG_ROOT=$prefix")
case "$platform" in
  linux) ;;
  macos)
    apple_arch=$arch
    [[ $arch != arm64 ]] || apple_arch=aarch64
    ffargs+=(--enable-cross-compile --target-os=darwin --arch="$apple_arch"
      --cc=clang --cxx=clang++ --enable-videotoolbox
      --extra-cflags="-arch $arch -mmacosx-version-min=11.0"
      --extra-ldflags="-arch $arch -mmacosx-version-min=11.0")
    cmargs+=("-DCMAKE_OSX_ARCHITECTURES=$arch" -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0)
    ;;
  ios)
    sdk=$(xcrun --sdk iphoneos --show-sdk-path)
    ffargs+=(--enable-cross-compile --target-os=darwin --arch=aarch64
      --cc="$(xcrun --sdk iphoneos -f clang)" --enable-videotoolbox
      --sysroot="$sdk" --extra-cflags="-arch arm64 -miphoneos-version-min=13.0"
      --extra-ldflags="-arch arm64 -miphoneos-version-min=13.0")
    cmargs+=(-DCMAKE_SYSTEM_NAME=iOS "-DCMAKE_OSX_SYSROOT=$sdk"
      -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0)
    ;;
  android)
    ndk="${ANDROID_HOME:?}/ndk/27.2.12479018"
    toolchain="$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin"
    if [[ $arch == arm64 ]]; then
      triple=aarch64-linux-android
      abi=arm64-v8a
      ffarch=aarch64
    else
      triple=x86_64-linux-android
      abi=x86_64
      ffarch=x86_64
    fi
    ffargs+=(--enable-cross-compile --target-os=android --arch="$ffarch"
      --cc="$toolchain/${triple}24-clang" --cxx="$toolchain/${triple}24-clang++"
      --ar="$toolchain/llvm-ar" --ranlib="$toolchain/llvm-ranlib"
      --strip="$toolchain/llvm-strip" --enable-mediacodec)
    cmargs+=("-DCMAKE_TOOLCHAIN_FILE=$ndk/build/cmake/android.toolchain.cmake"
      "-DANDROID_ABI=$abi" -DANDROID_PLATFORM=24 -DANDROID_STL=c++_static)
    ;;
  *) echo "Unsupported platform: $platform" >&2; exit 1 ;;
esac
cd "$source_dir"
./configure "${ffargs[@]}"
make -j3
make install
cd "$root"
cmake -S . -B build-ci/native -G Ninja "${cmargs[@]}"
cmake --build build-ci/native --parallel 3

# Static LGPL libraries need matching objects and build instructions for relinking.
kit="$root/build-ci/relink"
mkdir -p "$kit/ffmpeg" "$kit/native" "$kit/source" addons/codisvp/licenses
cp "$prefix"/lib/*.a "$kit/ffmpeg/"
cp -R build-ci/native/CMakeFiles/codisvp.dir "$kit/native/"
find build-ci/native/godot-cpp -name '*.a' -exec cp {} "$kit/native/" \;
cp build-ci/native/build.ninja build-ci/native/CMakeCache.txt "$kit/native/"
cp build-ci/native/CMakeFiles/rules.ninja "$kit/native/"
cp build-ci/ffmpeg.tar.xz "$kit/source/"
cp -R native CMakeLists.txt tools/ci "$kit/source/"
cp "$source_dir/config.h" "$source_dir/ffbuild/config.mak" "$kit/ffmpeg/"
cp "$source_dir/COPYING.LGPLv2.1" addons/codisvp/licenses/FFmpeg-LGPL-2.1.txt
cp third_party/godot-cpp/LICENSE.md addons/codisvp/licenses/godot-cpp-MIT.txt
printf 'FFmpeg %s; godot-cpp %s; platform %s; architecture %s\n' \
  "$FFMPEG_VERSION" "$GODOT_CPP_REVISION" "$platform" "$arch" > "$kit/BUILD.txt"
cp tools/ci/RELINK.md "$kit/README.md"
