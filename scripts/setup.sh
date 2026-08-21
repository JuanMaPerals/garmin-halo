#!/bin/bash
# First-time setup script for Garmin Halo Bridge
# Run inside Docker container: docker-compose run --rm connectiq bash scripts/setup.sh
#
# Requires GARMIN_USERNAME and GARMIN_PASSWORD environment variables.
# Usage: docker-compose run --rm -e GARMIN_USERNAME=... -e GARMIN_PASSWORD=... connectiq bash scripts/setup.sh

set -e

AGREEMENT_HASH="CC737BBBA104D7740D5BBCF27D0F6382"

echo "=== Garmin Halo Bridge Setup ==="
echo ""

# 1. Generate developer key if not present
if [ ! -f developer.der ]; then
    echo "=== Generating developer key ==="
    openssl genrsa -out /tmp/key.pem 4096 2>&1
    openssl pkcs8 -topk8 -nocrypt -in /tmp/key.pem -outform DER -out developer.der 2>&1
    rm /tmp/key.pem
    echo "Developer key created: developer.der"
else
    echo "Developer key already exists: developer.der"
fi
echo ""

# 2. Generate launcher icon if not present
if [ ! -f resources/drawables/launcher_icon.png ]; then
    echo "=== Generating launcher icon ==="
    python3 create_icon.py
fi
echo ""

# 3. Accept license agreement
echo "=== Accepting license agreement ==="
connect-iq-sdk-manager agreement accept -H "$AGREEMENT_HASH" 2>&1 || true
echo ""

# 4. Login to Garmin
echo "=== Logging in to Garmin ==="
if [ -z "$GARMIN_USERNAME" ] || [ -z "$GARMIN_PASSWORD" ]; then
    echo "ERROR: GARMIN_USERNAME and GARMIN_PASSWORD environment variables required"
    exit 1
fi
connect-iq-sdk-manager login --username "$GARMIN_USERNAME" --password "$GARMIN_PASSWORD" 2>&1
echo ""

# 5. Download device profiles
echo "=== Downloading device profiles ==="
connect-iq-sdk-manager device download -m manifest.xml 2>&1
echo ""

# 6. Build
echo "=== Building project ==="
make build
echo ""

echo "=== Setup complete! ==="
echo "You can now run: make build    (compile)"
echo "                make run       (simulator)"
echo "                make test-lua  (Lua tests)"
