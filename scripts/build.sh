#!/bin/bash
# Build script for Garmin Halo Bridge
# Runs inside the Docker container
# Usage: docker-compose run --rm connectiq bash scripts/build.sh
#
# If device profiles are missing, requires GARMIN_USERNAME and GARMIN_PASSWORD
# to download them first.

set -e

AGREEMENT_HASH="CC737BBBA104D7740D5BBCF27D0F6382"

# Check if device profiles are already available by attempting a dry build
if ! java -jar "$(cat ~/.Garmin/ConnectIQ/current-sdk.cfg)/bin/monkeybrains.jar" \
    -f monkey.jungle -d fr165 -o /dev/null -y developer.der -l 0 2>/dev/null; then

    echo "=== Device profiles not found, downloading... ==="

    if [ -z "$GARMIN_USERNAME" ] || [ -z "$GARMIN_PASSWORD" ]; then
        echo "ERROR: Device profiles missing. Set GARMIN_USERNAME and GARMIN_PASSWORD to download them."
        echo "  docker-compose run --rm -e GARMIN_USERNAME=... -e GARMIN_PASSWORD=... connectiq bash scripts/build.sh"
        exit 1
    fi

    connect-iq-sdk-manager agreement accept -H "$AGREEMENT_HASH" 2>&1 || true
    connect-iq-sdk-manager login --username "$GARMIN_USERNAME" --password "$GARMIN_PASSWORD" 2>&1
    connect-iq-sdk-manager device download -m manifest.xml 2>&1
    echo ""
fi

echo "=== Building ==="
make build

echo "=== Build complete ==="
ls -la bin/garmin-halo.prg 2>/dev/null
