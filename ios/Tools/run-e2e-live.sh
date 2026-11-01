#!/bin/zsh
# Live operating-flow run of the iOS apps against a real local backend (dev-guide, "Live end-to-end run").
# Usage: E2E_DIR=<folder> SIMULATOR=<udid> DEVELOPER_DIR=<full Xcode> ios/Tools/run-e2e-live.sh
# Needs: a backend on E2E_API_BASE_URL (default http://127.0.0.1:8080) whose console output goes to
# $E2E_DIR/backend-ios.log (or E2E_BACKEND_LOG), console mail provider, and the owner and a free phone.
set -eu
IOS=${0:A:h:h}
: ${E2E_DIR:?folder for logs, state and screenshots}
: ${SIMULATOR:?simulator id}
VIDEO=${E2E_VIDEO:-$HOME/Movies/banh-ui-tests/e2e-ios-operating-flow.mp4}
DD=${E2E_DERIVED:-$E2E_DIR/derived}
mkdir -p $E2E_DIR/ios $(dirname $VIDEO)
setopt nullglob
# E2E_REUSE_ORDERS=1 keeps the state file, so step 1 is skipped (the phone allows 5 orders a day).
if [[ ${E2E_REUSE_ORDERS:-0} != 1 ]]; then rm -f $E2E_DIR/ios-state.json; fi
rm -f $E2E_DIR/ios/*.png
cd $IOS
# The customer app is a separate app: build it and install it, the admin UI tests start it by bundle id.
xcodebuild -project BanhApp.xcodeproj -scheme BanhApp -destination "id=$SIMULATOR" -derivedDataPath $DD/customer \
  CODE_SIGNING_ALLOWED=NO build > $E2E_DIR/build-customer.log 2>&1
xcrun simctl install $SIMULATOR $DD/customer/Build/Products/Debug-iphonesimulator/BanhApp.app
# A background job of a script ignores SIGINT; simctl needs it to finish the file, so reset it first.
perl -e '$SIG{INT}="DEFAULT"; exec @ARGV' xcrun simctl io $SIMULATOR recordVideo --codec h264 --force $VIDEO &
REC=$!
sleep 3
kill -0 $REC 2>/dev/null || echo "WARNING: the recorder did not start (another recording of this simulator may be running: Host recording is already in progress)"
# E2E_TESTS="test02b_PhoneLimitStillCountsTheSpamOrder test05_..." runs only those methods (default: all).
ONLY=()
for t in ${=E2E_TESTS:-}; do ONLY+=(-only-testing:BanhAdminUITests/OperatingFlowLiveTests/$t); done
(( $#ONLY )) || ONLY=(-only-testing:BanhAdminUITests/OperatingFlowLiveTests)
set +e
TEST_RUNNER_E2E_LIVE=1 TEST_RUNNER_E2E_REUSE_ORDERS=${E2E_REUSE_ORDERS:-0} TEST_RUNNER_E2E_DIR=$E2E_DIR TEST_RUNNER_E2E_SHOTS_DIR=$E2E_DIR/ios \
TEST_RUNNER_E2E_BACKEND_LOG=${E2E_BACKEND_LOG:-$E2E_DIR/backend-ios.log} \
xcodebuild -project BanhAdmin.xcodeproj -scheme BanhAdmin -destination "id=$SIMULATOR" -derivedDataPath $DD/admin \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO ${(@)ONLY} test \
  > $E2E_DIR/test-admin.log 2>&1
STATUS=$?
kill -INT $REC
for i in {1..30}; do kill -0 $REC 2>/dev/null || break; sleep 1; done
tail -40 $E2E_DIR/test-admin.log
exit $STATUS
