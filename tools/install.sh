#!/bin/zsh
set -e
source "$(dirname "$0")/env.sh"
cd "$PROJECT_DIR"

if [ ! -f build/JumpRope.prg ]; then
    echo "Build first: ./tools/build.sh"
    exit 1
fi

DEST=""
for candidate in /Volumes/*; do
    if [ -d "$candidate/GARMIN/APPS" ]; then
        DEST="$candidate/GARMIN/APPS"
        break
    fi
done

if [ -z "$DEST" ]; then
    echo "Watch not mounted in Finder."
    echo "Use OpenMTP (or Android File Transfer) and copy:"
    echo "  $PROJECT_DIR/build/JumpRope.prg"
    echo "to:"
    echo "  GARMIN/APPS/JUMPROPE.PRG"
    exit 1
fi

cp build/JumpRope.prg "$DEST/JUMPROPE.PRG"
echo "Copied to $DEST/JUMPROPE.PRG"
echo "Safely eject the watch, then start Jump Rope from the watch app list."
