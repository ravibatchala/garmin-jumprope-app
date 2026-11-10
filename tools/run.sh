#!/bin/zsh
set -e
source "$(dirname "$0")/env.sh"
cd "$PROJECT_DIR"

if [ ! -f build/JumpRope.prg ]; then
    echo "Build first: ./tools/build.sh"
    exit 1
fi

if ! pgrep -f "ConnectIQ.app/Contents/MacOS/simulator" >/dev/null 2>&1; then
    echo "Starting the Connect IQ simulator..."
    open "$SDK/bin/ConnectIQ.app"
    sleep 6
fi

"$SDK/bin/monkeydo" build/JumpRope.prg "$DEVICE"
