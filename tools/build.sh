#!/bin/zsh
set -e
source "$(dirname "$0")/env.sh"
cd "$PROJECT_DIR"

if [ ! -f developer_key.der ]; then
    echo "Missing developer_key.der. Generate one with:"
    echo "  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out developer_key.pem"
    echo "  openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt"
    exit 1
fi

mkdir -p build
"$SDK/bin/monkeyc" \
    -f monkey.jungle \
    -o build/JumpRope.prg \
    -y developer_key.der \
    -d "$DEVICE" \
    -w \
    --typecheck 2 \
    -r

echo "Built: $PROJECT_DIR/build/JumpRope.prg"
