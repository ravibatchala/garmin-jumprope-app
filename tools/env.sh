#!/bin/zsh
# Shared build environment. Adjust SDK if you install a newer Connect IQ SDK.
export SDK="${SDK:-$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.3.0-2026-10-20-95888f262}"
export DEVICE="${DEVICE:-instincte40mm}"
export PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
