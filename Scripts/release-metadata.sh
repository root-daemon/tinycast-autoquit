#!/bin/bash
set -euo pipefail

if [ "$CHANNEL" = beta ]; then
    VERSION="${BASE_VERSION}-beta.${GITHUB_RUN_NUMBER}"
    DISPLAY_NAME="Tinycast Beta"
    BUNDLE_ID="com.tinycast.app.beta"
else
    VERSION="$BASE_VERSION"
    DISPLAY_NAME="Tinycast"
    BUNDLE_ID="com.tinycast.app"
fi
{
    echo "VERSION=$VERSION"
    echo "TAG=v$VERSION"
    echo "DISPLAY_NAME=$DISPLAY_NAME"
    echo "BUNDLE_ID=$BUNDLE_ID"
} >> "$GITHUB_ENV"
