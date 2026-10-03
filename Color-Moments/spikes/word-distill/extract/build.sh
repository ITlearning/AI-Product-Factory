#!/bin/sh
# 앱의 단어 코드를 고치지 않고 그대로 컴파일한다. PhotoEnrichment 만 SwiftUI 파일에서 잘라 온다.
set -e
here=$(cd "$(dirname "$0")" && pwd)
shared="$here/../../../Shared"
mkdir -p "$here/.build"
awk '/^public enum PhotoEnrichment/{on=1} on{print} on&&/^}$/{exit}' "$shared/Day/DayPhotoView.swift" \
  | sed '1i\
import Foundation
' > "$here/.build/PhotoEnrichment.swift"
xcrun swiftc -O -swift-version 5 -o "$here/.build/extract" \
  "$here/main.swift" "$here/stubs.swift" "$here/.build/PhotoEnrichment.swift" \
  "$shared/Day/Moment.swift" "$shared/Word/WordList.swift" "$shared/Word/WordPicker.swift" \
  "$shared/Word/PhotoContext.swift" "$shared/Word/Celestial.swift" "$shared/Word/PhotoLabeler.swift" \
  "$shared/Word/WordChoice.swift"
