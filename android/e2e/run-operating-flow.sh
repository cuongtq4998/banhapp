#!/bin/zsh
# Runs the shop's operating flow on the emulator with both real apps (customer :app, admin :admin) against a real local backend.
# See docs/engineering/dev-guide.md, "Live operating flow". No secrets here: the backend address is the emulator alias of the host.
#
# Environment (all optional):
#   BACKEND_PORT  port of the local backend on the host (default 8081); the emulator reaches it at 10.0.2.2:$BACKEND_PORT
#   OUT           folder for screenshots and notes (default ./e2e-out)
#   MOVIES        folder for the screen recording (default ~/Movies/banh-ui-tests); recording runs when RECORD=1
#   PHONE         customer phone of this run (default: random 0900xxxxxx); the shop allows 5 orders per phone in 24 hours
#   REC_START     number of the first recording part (a resumed run continues the numbering)
#   START         method name to continue from (a failed run keeps its state on the device)
#   NO_BUILD=1    skip the Gradle build and the install (also skips clearing app data, so START can resume)
set -u
cd "$(dirname $0)/.."
ADB=${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}
PORT=${BACKEND_PORT:-8081}
OUT=${OUT:-$PWD/e2e-out}
MOVIES=${MOVIES:-$HOME/Movies/banh-ui-tests}
PHONE=${PHONE:-$(printf '0900%06d' $(( (RANDOM * 32768 + RANDOM) % 1000000 )))}
export JAVA_HOME=${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home} ANDROID_HOME=${ANDROID_HOME:-$HOME/Library/Android/sdk}
RUNNER=androidx.test.runner.AndroidJUnitRunner
CUSTOMER=app.banh.customer; ADMIN=app.banh.admin
mkdir -p $OUT

# ---- phases in order: package:method ----
PHASES=(
  ${CUSTOMER}:step1_customerPlacesTwoOrders
  ${ADMIN}:step2a_ownerSignsInByMailCodeAndSeesBothNewOrdersFirst
  ${ADMIN}:step2b_ownerChecksOrder1AgainstWhatTheCustomerTypedAndConfirmsIt
  ${ADMIN}:step3_ownerCancelsOrder2AsSpamAndThePerPhoneCountStillIncludesIt
  ${ADMIN}:step4_ownerCompletesOrder1
  ${ADMIN}:step5a_ownerLowersTheDailyLimitAndTheImpactPreviewListsTheDate
  ${CUSTOMER}:step5a_dateStepShowsTheDateFull
  ${ADMIN}:step5b_ownerRestoresTheLimit
  ${CUSTOMER}:step5b_dateIsAvailableAgainAfterTheLimitIsRestored
  ${ADMIN}:step6a_ownerFillsTheCakeFormAndTheCakeIsAddedByHelperUpload
  ${CUSTOMER}:step6a_newCakeIsInTheCustomerCatalog
  ${ADMIN}:step6b_ownerHidesTheCake
  ${CUSTOMER}:step6b_hiddenCakeIsGoneFromTheCustomerCatalog
  ${ADMIN}:step7_ownerAddsStaffSignsOutStaffWorksThenIsDeactivated
  ${ADMIN}:step8_logAudit
)

if [[ -z ${NO_BUILD:-} ]]; then
  ./gradlew :app:assembleDebug :app:assembleDebugAndroidTest :admin:assembleDebug :admin:assembleDebugAndroidTest \
    -PapiBaseUrl=http://10.0.2.2:$PORT/ -PadminApiBaseUrl=http://10.0.2.2:$PORT/ -q || exit 1
  for apk in app/build/outputs/apk/debug/app-debug.apk app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
             admin/build/outputs/apk/debug/admin-debug.apk admin/build/outputs/apk/androidTest/debug/admin-debug-androidTest.apk; do
    $ADB install -r $apk > /dev/null || exit 1
  done
  $ADB shell pm clear $CUSTOMER > /dev/null; $ADB shell pm clear $ADMIN > /dev/null
fi

# ---- screen recording in parts of 175 s (screenrecord stops at 180 s) ----
if [[ ${RECORD:-0} == 1 ]]; then
  mkdir -p $MOVIES
  ( n=${REC_START:-1}; while [[ ! -f $OUT/.stop ]]; do
      $ADB shell screenrecord --time-limit 175 /sdcard/e2e-p$n.mp4
      sleep 2; $ADB pull /sdcard/e2e-p$n.mp4 $MOVIES/e2e-android-operating-flow-p$n.mp4 > /dev/null; n=$((n+1))
    done ) &
  RECORDER=$!
fi
rm -f $OUT/.stop

pull_shots() { for pkg in $CUSTOMER $ADMIN; do $ADB pull /sdcard/Android/data/$pkg/files/e2e/shots/. $OUT/ > /dev/null 2>&1; done; }

# State the customer run recorded, passed on as instrumentation arguments to the admin run.
admin_args() {
  local state; state=$($ADB shell cat /sdcard/Android/data/$CUSTOMER/files/e2e/state.properties 2>/dev/null | tr -d '\r')
  for key in date code1 code2 phone; do
    print -- "-e $key $(printf "%s\n" "$state" | sed -n "s/^$key=//p")"
  done
  print -- "-e total1 $(printf '%s\n' "$state" | sed -n 's/^total1=//p' | sed 's/\\u20AB//' | tr -cd '0-9')"
}

started=${START:+0}; failed=0
for phase in $PHASES; do
  pkg=${phase%%:*}; method=${phase#*:}
  if [[ -n ${START:-} && $started == 0 ]]; then [[ $method == $START ]] || continue; started=1; fi
  extra=""; [[ $pkg == $ADMIN ]] && extra=$(admin_args | tr '\n' ' ')
  echo "== $pkg $method"
  result=$($ADB shell am instrument -w -e e2eLive true -e e2ePhone $PHONE -e e2eCake Banh_E2E_${PHONE: -4} ${=extra} -e class $pkg.live.OperatingFlowLiveTest#$method $pkg.test/$RUNNER 2>&1)
  print -- "$result" > $OUT/result-$method.txt
  pull_shots
  if ! print -- "$result" | grep -q '^OK (1 test)'; then print -- "$result" | head -30; failed=1; break; fi
  echo "   passed"
done

touch $OUT/.stop
if [[ -n ${RECORDER:-} ]]; then $ADB shell pkill -2 screenrecord; wait $RECORDER; fi
pull_shots
echo "phone $PHONE; pictures and notes in $OUT"
exit $failed
