#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_PATH="${THEOS}/sdks/iPhoneOS16.5.sdk"

if [ ! -d "$SDK_PATH" ]; then
    SDK_PATH="/Users/minhocean/theos/sdks/iPhoneOS16.5.sdk"
fi

if [ ! -d "$SDK_PATH" ]; then
    echo "Error: iPhoneOS SDK not found at $SDK_PATH"
    exit 1
fi

echo "==> Compiling RedditProxy.dylib for arm64 iOS 15.0+..."
clang -target arm64-apple-ios15.0 \
      -isysroot "$SDK_PATH" \
      -shared -fobjc-arc -O2 \
      -install_name @rpath/RedditProxy.dylib \
      -framework Foundation -framework UIKit -framework CFNetwork -framework CoreFoundation -framework CoreGraphics \
      -I "$DIR/src" \
      -o "$DIR/RedditProxy.dylib" \
      "$DIR/src/main.m" \
      "$DIR/src/RedditProxyManager.m" \
      "$DIR/src/RedditProxyHooks.m" \
      "$DIR/src/RedditProxyUI.m" \
      "$DIR/src/fishhook.c"

echo "==> Successfully built RedditProxy.dylib"
file "$DIR/RedditProxy.dylib"
