#!/bin/bash

# Build a dynamic rust library for a chosen platform and automatically place it in the output bin
# directory so it can be used in Godot.
# Example usage: ./build_platform.sh windows debug
# Example output: addons/dijkstra-map/dijkstra_map_library/bin/dijkstra_map_gd.windows.debug.dll

# For experimental web support, see:
# https://godot-rust.github.io/book/toolchain/export-web.html?highlight=web#export-to-web
# It is necessary to install emscripten and enable the emsdk env for web builds to work.
# Tested with emscripten 3.1.74.
# You likely will need to pass in the third 'host' param for web builds to work, especially on
# Windows; this allows us to specify a more reliable host platform-specific nightly toolchain.
# Example web build usage: ./build_platform.sh web_threads debug windows
# If this fails initially, try directly installing the specific component for your host platform,
# e.g. `rustup component add rust-src --toolchain nightly-2026-05-15-x86_64-pc-windows-msvc` for
# the nightly toolchain that is best compatible for Windows systems for web builds (following the
# same platform structure seen down below). Then re-run the build command and see if it works.

# This build script is intended for local testing builds only. For releases, use the make_release
# GitHub Action.

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <platform> <profile>"
    echo "  platform:        windows | linux | mac | mac_arm | web_threads | web_nothreads"
    echo "  profile:         debug | release"
    echo "  host(optional):  windows | linux | mac"
    exit 1
fi

CHOSEN_PLATFORM=$1
CHOSEN_PROFILE=$2
CHOSEN_HOST=${3:-}

# Pinned version of the Rust nightly toolchain that is known to support features that the WASM
# builds rely on. In a future gdext release we may be able to unset this.
# See: https://github.com/godot-rust/gdext/issues/438#issuecomment-4654794355
WEB_COMPATIBLE_NIGHTLY_TOOLCHAIN="+nightly-2026-05-15"

# Verify host platform if provided + set host-specific params.
case $CHOSEN_HOST in
    windows)
        HOST_CUSTOM_TOOLCHAIN_SUFFIX="-x86_64-pc-windows-msvc"
        ;;
    linux)
        HOST_CUSTOM_TOOLCHAIN_SUFFIX="-x86_64-unknown-linux-gnu"
        ;;
    max)
        HOST_CUSTOM_TOOLCHAIN_SUFFIX="-x86_64-apple-darwin"
        ;;
    "")
        HOST_CUSTOM_TOOLCHAIN_SUFFIX=""
        ;;
     *)
        echo "Invalid host: $CHOSEN_HOST"
        echo "Supported hosts: windows, linux, mac, or none (empty string)"
        exit 1
        ;;
esac

# Verify target platform choice + set platform-specific params.
case $CHOSEN_PLATFORM in
    windows)
        PLATFORM="x86_64-pc-windows-msvc"
        PLATFORM_EXTENSION="dll"
        PLATFORM_TARGET_PREFIX=""
        PLATFORM_CUSTOM_TOOLCHAIN=""
        PLATFORM_CARGO_FLAGS=""
        PLATFORM_RUSTFLAGS=""
        ;;
    linux)
        PLATFORM="x86_64-unknown-linux-gnu"
        PLATFORM_EXTENSION="so"
        PLATFORM_TARGET_PREFIX="lib"
        PLATFORM_CUSTOM_TOOLCHAIN=""
        PLATFORM_CARGO_FLAGS=""
        PLATFORM_RUSTFLAGS=""
        ;;
    mac)
        PLATFORM="x86_64-apple-darwin"
        PLATFORM_EXTENSION="dylib"
        PLATFORM_TARGET_PREFIX="lib"
        PLATFORM_CUSTOM_TOOLCHAIN=""
        PLATFORM_CARGO_FLAGS=""
        PLATFORM_RUSTFLAGS=""
        ;;
    mac_arm)
        PLATFORM="aarch64-apple-darwin"
        PLATFORM_EXTENSION="dylib"
        PLATFORM_TARGET_PREFIX="lib"
        PLATFORM_CUSTOM_TOOLCHAIN=""
        PLATFORM_CARGO_FLAGS=""
        PLATFORM_RUSTFLAGS=""
        ;;
    web_threads)
        if ! command -v emcc &> /dev/null
        then
            echo "Error: emcc is not detected. Make sure to source the emsdk env before building."
            exit 1
        fi
        if [ -z $CHOSEN_HOST ]; then
            echo "Warning: host platform arg may need to be specified; otherwise the build may fail."
        fi
        PLATFORM="wasm32-unknown-emscripten"
        PLATFORM_EXTENSION="wasm"
        PLATFORM_TARGET_PREFIX=""
        PLATFORM_CUSTOM_TOOLCHAIN=${WEB_COMPATIBLE_NIGHTLY_TOOLCHAIN}${HOST_CUSTOM_TOOLCHAIN_SUFFIX}
        PLATFORM_CARGO_FLAGS="-Zbuild-std"
        PLATFORM_RUSTFLAGS="-C link-args=-pthread \
            -C target-feature=+atomics \
            -C link-args=-sSIDE_MODULE=2 \
            -C llvm-args=-enable-emscripten-cxx-exceptions=0 \
            -Z default-visibility=hidden \
            -Z link-native-libraries=no \
            -Z emscripten-wasm-eh=false"
        ;;
    web_nothreads)
        if ! command -v emcc &> /dev/null
        then
            echo "Error: emcc is not detected. Make sure to source the emsdk env before building."
            exit 1
        fi
        if [ -z $CHOSEN_HOST ]; then
            echo "Warning: host platform arg may need to be specified; otherwise the build may fail."
        fi
        PLATFORM="wasm32-unknown-emscripten"
        PLATFORM_EXTENSION="wasm"
        PLATFORM_TARGET_PREFIX=""
        PLATFORM_CUSTOM_TOOLCHAIN=${WEB_COMPATIBLE_NIGHTLY_TOOLCHAIN}${HOST_CUSTOM_TOOLCHAIN_SUFFIX}
        PLATFORM_CARGO_FLAGS="--features nothreads -Zbuild-std"
        PLATFORM_RUSTFLAGS="-C link-args=-sSIDE_MODULE=2 \
            -C llvm-args=-enable-emscripten-cxx-exceptions=0 \
            -Z default-visibility=hidden \
            -Z link-native-libraries=no \
            -Z emscripten-wasm-eh=false"
        ;;
    *)
        echo "Invalid platform: $CHOSEN_PLATFORM"
        echo "Supported platforms: windows, linux, mac, mac_arm, web_threads, web_nothreads"
        exit 1
        ;;
esac

# Verify profile choice
case $CHOSEN_PROFILE in
  release)
    PROFILE_CARGO_FLAGS="--release"
    ;;
  debug)
    PROFILE_CARGO_FLAGS=""
    ;;
  *)
    echo "Invalid profile: $CHOSEN_PROFILE"
    echo "Supported profiles: debug, release"
    exit 1
    ;;
esac

# Build for the specified platform & profile
CRATE_NAME="dijkstra_map_gd"
BIN_DIR="addons/dijkstra-map/dijkstra_map_library/bin"
TARGET_DIR="target/$PLATFORM/$CHOSEN_PROFILE"
OUTPUT_FILE="${CRATE_NAME}.${CHOSEN_PLATFORM}.${CHOSEN_PROFILE}.${PLATFORM_EXTENSION}"
DEST_PATH="${BIN_DIR}/${OUTPUT_FILE}"

# Ensure target platform is available
rustup target add $PLATFORM

# Start build
echo "Building $CRATE_NAME for $PLATFORM ($CHOSEN_PLATFORM) [$CHOSEN_PROFILE]..."
export RUSTFLAGS=$PLATFORM_RUSTFLAGS
cargo $PLATFORM_CUSTOM_TOOLCHAIN build $PLATFORM_CARGO_FLAGS $PROFILE_CARGO_FLAGS --target $PLATFORM

# Copy built artifact over to the destination path
mkdir -p "$BIN_DIR"
cp "$TARGET_DIR/${PLATFORM_TARGET_PREFIX}${CRATE_NAME}.${PLATFORM_EXTENSION}" "$DEST_PATH"

echo "Build complete!"
