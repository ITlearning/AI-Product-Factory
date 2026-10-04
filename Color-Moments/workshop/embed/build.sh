#!/bin/sh
set -e
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$here/.build"
xcrun swiftc -O -o "$here/.build/embed" "$here/main.swift" "$here/../../Shared/Word/WordImage.swift"
