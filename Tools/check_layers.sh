#!/bin/bash
#
#  check_layers.sh
#  Tools
#
#  Created by Hongjeongmin on 10/11/26.
#
#  CLAUDE.md 2.2의 import 허용표를 검사한다.
#  Domain·Storage·Recognition은 패키지 타깃이라 컴파일러가 막아 주지만,
#  Presentation은 App과 같은 앱 타깃이라 이 스크립트로 확인한다.
#
#  사용법: Tools/check_layers.sh   (위반이 있으면 exit 1)
#

cd "$(dirname "$0")/.." || exit 1
status=0

check() {
    local dir="$1" pattern="$2" rule="$3"
    [ -d "$dir" ] || return 0
    local hits
    hits=$(grep -rnE "^[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+($pattern)\b" "$dir" --include='*.swift')
    if [ -n "$hits" ]; then
        echo "❌ $rule"
        echo "$hits"
        status=1
    fi
}

check "Symbol Sketch/Presentation" "Storage|Recognition|SwiftData|Vision|CoreML" \
    "Presentation은 Domain(UseCase 프로토콜)에만 의존해야 합니다"
check "Symbol Sketch/DesignSystem" "Storage|Recognition|SwiftData|Vision|CoreML" \
    "DesignSystem은 Storage·Recognition에 의존하면 안 됩니다"
check "Packages/SymbolSketchKit/Sources/Domain" "SwiftUI|UIKit|SwiftData|Vision|CoreML|Accelerate|CoreGraphics|PencilKit|Storage|Recognition" \
    "Domain은 Foundation만 import할 수 있습니다"

[ $status -eq 0 ] && echo "✅ 레이어 규칙 위반 없음"
exit $status
