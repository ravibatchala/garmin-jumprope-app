#!/bin/zsh
set -e
source "$(dirname "$0")/env.sh"
cd "$PROJECT_DIR"

if [ ! -f developer_key.der ]; then
    echo "Missing developer_key.der. Run ./tools/build.sh for instructions."
    exit 1
fi

mkdir -p build
"$SDK/bin/monkeyc" \
    -f test.jungle \
    -o build/JumpRopeTest.prg \
    -y developer_key.der \
    -d "$DEVICE" \
    -w \
    --typecheck 2 \
    -t

if ! pgrep -f "ConnectIQ.app/Contents/MacOS/simulator" >/dev/null 2>&1; then
    echo "Starting the Connect IQ simulator..."
    open "$SDK/bin/ConnectIQ.app"
    sleep 6
fi

set +e
output=$("$SDK/bin/monkeydo" build/JumpRopeTest.prg "$DEVICE" -t 2>&1)
exit_code=$?
printf '%s\n' "$output"

# monkeydo in this SDK returns 1 even when every test passes. Treat the
# explicit PASSED summary as success, but keep a real failure nonzero.
if printf '%s\n' "$output" | grep -q "PASSED (passed="; then
    exit 0
fi
exit $exit_code
