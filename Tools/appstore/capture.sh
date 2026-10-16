#!/bin/bash
#
#  capture.sh
#  Tools
#
#  Created by Hongjeongmin on 10/16/26.
#
#  App Store 스크린샷 원본 촬영. 데모 모드 UI 테스트(AppStoreScreenshotUITests)를 돌리고,
#  테스트가 출력하는 "SHOT:<이름>" 표시마다 simctl로 시뮬레이터 화면을 찍는다.
#
#  사용법: Tools/appstore/capture.sh <시뮬레이터 UDID> <저장 폴더> [접두어]
#  환경 변수: SHOT_LANG(ko|en), SHOT_SCENES(쉼표 목록), SHOT_ORIENTATION(portrait|landscape),
#            SHOT_DISPLAY(simctl --display 값, Duo 바깥 화면 등)
#

set -u
cd "$(dirname "$0")/../.." || exit 1
udid="$1"; out="$2"; prefix="${3:-}"
mkdir -p "$out"
log="$out/.capture-${prefix:-run}.log"

xcrun simctl boot "$udid" 2>/dev/null
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 2>/dev/null

TEST_RUNNER_SHOT_LANG="${SHOT_LANG:-ko}" \
TEST_RUNNER_SHOT_SCENES="${SHOT_SCENES:-}" \
TEST_RUNNER_SHOT_ORIENTATION="${SHOT_ORIENTATION:-portrait}" \
perl -e 'alarm 1500; exec @ARGV' xcodebuild -project SymCatch.xcodeproj -scheme SymCatch \
    -destination "platform=iOS Simulator,id=$udid" -parallel-testing-enabled NO \
    -only-testing:SymCatchUITests/AppStoreScreenshotUITests test > "$log" 2>&1 &
pid=$!

taken=""
while kill -0 "$pid" 2>/dev/null; do
    for name in $(grep -o 'SHOT:[a-z0-9]*' "$log" 2>/dev/null | cut -d: -f2); do
        case " $taken " in *" $name "*) continue ;; esac
        sleep 1
        if [ -n "${SHOT_DISPLAY:-}" ]; then
            xcrun simctl io "$udid" screenshot --display="$SHOT_DISPLAY" "$out/${prefix}${name}.png" >/dev/null 2>&1
        else
            xcrun simctl io "$udid" screenshot "$out/${prefix}${name}.png" >/dev/null 2>&1
        fi
        echo "찍음: ${prefix}${name}.png"
        taken="$taken $name"
    done
    sleep 1
done
wait "$pid"; status=$?
grep -E "\*\* TEST (SUCCEEDED|FAILED)|error:" "$log" | tail -5
exit $status
