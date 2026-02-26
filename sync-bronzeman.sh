#!/bin/bash
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${PLUGIN_DIR:-$SCRIPT_DIR/../bronzeman-unleashed}"
RUNELITE_DIR="${RUNELITE_DIR:-$SCRIPT_DIR}"
RELEASE_REPO="${RELEASE_REPO:-elertan/runelite-with-bronzeman-unleashed}"
DIST_DIR="${DIST_DIR:-$RUNELITE_DIR/sync-bronzeman}"
TEMPLATE_DIR="${TEMPLATE_DIR:-$SCRIPT_DIR/sync-templates}"

# Source paths
SRC_JAVA="$PLUGIN_DIR/src/main/java/com.elertan"
SRC_RESOURCES="$PLUGIN_DIR/src/main/resources"

# Target paths
TARGET_JAVA="$RUNELITE_DIR/runelite-client/src/main/java/net/runelite/client/plugins/bronzemanunleashed"
TARGET_RESOURCES="$RUNELITE_DIR/runelite-client/src/main/resources/net/runelite/client/plugins/bronzemanunleashed"

# Package transformation
OLD_PACKAGE="com.elertan"
NEW_PACKAGE="net.runelite.client.plugins.bronzemanunleashed"

START_SH_TEMPLATE="$TEMPLATE_DIR/start.sh.template"
START_BAT_TEMPLATE="$TEMPLATE_DIR/start.bat.template"
JVMARGS_TEMPLATE="$TEMPLATE_DIR/jvmargs.example.txt"

render_template() {
    local input="$1"
    local output="$2"

    sed -e "s|__PLUGINHUB_VERSION__|$PLUGINHUB_VERSION|g" \
        -e "s|__RELEASE_REPO__|$RELEASE_REPO|g" \
        -e "s|__LOCAL_VERSION__|$RELEASE_VERSION|g" \
        "$input" > "$output"
}

echo "=== Bronzeman Unleashed → RuneLite Sync ==="
echo "Source: $PLUGIN_DIR"
echo "Target: $RUNELITE_DIR"
echo "Release Repo: $RELEASE_REPO"
echo ""

# Verify source exists
if [[ ! -d "$SRC_JAVA" ]]; then
    echo "ERROR: Source directory not found: $SRC_JAVA"
    exit 1
fi

if [[ ! -f "$START_SH_TEMPLATE" || ! -f "$START_BAT_TEMPLATE" || ! -f "$JVMARGS_TEMPLATE" ]]; then
    echo "ERROR: Launcher templates missing in $TEMPLATE_DIR"
    exit 1
fi

# Clean target directories
echo "Cleaning target directories..."
rm -rf "$TARGET_JAVA"
rm -rf "$TARGET_RESOURCES"

# Create target directories
mkdir -p "$TARGET_JAVA"
mkdir -p "$TARGET_RESOURCES"

# Copy and transform Java files
echo "Copying and transforming Java files..."
find "$SRC_JAVA" -name "*.java" | while read -r src_file; do
    # Get relative path from source root
    rel_path="${src_file#$SRC_JAVA/}"
    target_file="$TARGET_JAVA/$rel_path"

    # Create target directory structure
    mkdir -p "$(dirname "$target_file")"

    # Copy with package/import transformation (including static imports)
    # Also transform absolute resource paths to relative (remove leading /)
    sed -e "s|package $OLD_PACKAGE|package $NEW_PACKAGE|g" \
        -e "s|import $OLD_PACKAGE|import $NEW_PACKAGE|g" \
        -e "s|import static $OLD_PACKAGE|import static $NEW_PACKAGE|g" \
        -e 's|"/icons/|"icons/|g' \
        "$src_file" > "$target_file"
done

# Count Java files
java_count=$(find "$TARGET_JAVA" -name "*.java" | wc -l | tr -d ' ')
echo "  Copied $java_count Java files"

# Copy resources (preserve directory structure)
echo "Copying resources..."
if [[ -d "$SRC_RESOURCES" ]]; then
    cp -R "$SRC_RESOURCES"/. "$TARGET_RESOURCES"/
fi

# Count resource files
resource_count=$(find "$TARGET_RESOURCES" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "  Copied $resource_count resource files"

echo ""
echo "=== Sync complete ==="
echo "Java files: $TARGET_JAVA"
echo "Resources:  $TARGET_RESOURCES"
echo ""

# Build shaded JAR
echo "=== Building shadowJar ==="
cd "$RUNELITE_DIR"
./gradlew :client:shadowJar

# Find the built JAR and extract version
JAR_PATH=$(find "$RUNELITE_DIR/runelite-client/build/libs" -name "client-*-shaded.jar" -print0 | xargs -0 ls -t | head -1)
if [[ -z "$JAR_PATH" ]]; then
    echo "ERROR: Could not find shaded JAR"
    exit 1
fi

# Extract version from filename (e.g., client-1.12.13-SNAPSHOT-shaded.jar -> 1.12.13)
# Also supports 4th segment versions like 1.12.12.1.
JAR_FILENAME=$(basename "$JAR_PATH")
RUNELITE_VERSION=$(echo "$JAR_FILENAME" | sed -E 's/client-([0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/')
if [[ ! "$RUNELITE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "ERROR: Unable to parse RuneLite version from JAR filename: $JAR_FILENAME"
    exit 1
fi

# Keep plugin hub version aligned with the RuneLite build version.
PLUGINHUB_VERSION="$RUNELITE_VERSION"

PLUGIN_SHA="$(git -C "$PLUGIN_DIR" rev-parse --short=7 HEAD 2>/dev/null || true)"
if [[ -z "$PLUGIN_SHA" ]]; then
    PLUGIN_SHA="unknown"
fi
RELEASE_VERSION="$RUNELITE_VERSION-$PLUGIN_SHA"

echo ""
echo "=== Creating distribution ==="
echo "RuneLite Version: $RUNELITE_VERSION"
echo "Plugin Commit: $PLUGIN_SHA"
echo "Release Version: $RELEASE_VERSION"
echo "Plugin Hub Version: $PLUGINHUB_VERSION"

# Create distribution folder
VERSION_DIR="$DIST_DIR/$RELEASE_VERSION"
mkdir -p "$VERSION_DIR"

# Copy JAR
cp "$JAR_PATH" "$VERSION_DIR/runelite.jar"
echo "  Copied runelite.jar"

# Create launcher files
render_template "$START_SH_TEMPLATE" "$VERSION_DIR/start.sh"
chmod +x "$VERSION_DIR/start.sh"
echo "  Created start.sh"

render_template "$START_BAT_TEMPLATE" "$VERSION_DIR/start.bat"
echo "  Created start.bat"

cp "$JVMARGS_TEMPLATE" "$VERSION_DIR/jvmargs.example.txt"
echo "  Copied jvmargs.example.txt"

printf '%s\n' "$RELEASE_VERSION" > "$VERSION_DIR/VERSION"
echo "  Created VERSION"

# Create full zip (versioned directory) and update zip (flat files)
cd "$DIST_DIR"
VERSION_ZIP="$DIST_DIR/$RELEASE_VERSION.zip"
UPDATE_ZIP="$DIST_DIR/runelite-update.zip"
VERSION_TXT="$DIST_DIR/version.txt"
rm -f "$VERSION_ZIP" "$UPDATE_ZIP"
zip -r "$VERSION_ZIP" "$RELEASE_VERSION" >/dev/null
zip -j "$UPDATE_ZIP" \
    "$VERSION_DIR/runelite.jar" \
    "$VERSION_DIR/start.sh" \
    "$VERSION_DIR/start.bat" \
    "$VERSION_DIR/VERSION" \
    "$VERSION_DIR/jvmargs.example.txt" >/dev/null
printf '%s\n' "$RELEASE_VERSION" > "$VERSION_TXT"
echo "  Created $(basename "$VERSION_ZIP")"
echo "  Created $(basename "$UPDATE_ZIP")"
echo "  Created $(basename "$VERSION_TXT")"

cat > "$DIST_DIR/release-info.env" << EOF
RELEASE_VERSION="$RELEASE_VERSION"
RUNELITE_VERSION="$RUNELITE_VERSION"
PLUGIN_SHA="$PLUGIN_SHA"
RELEASE_DIR="$VERSION_DIR"
ZIP_PATH="$VERSION_ZIP"
UPDATE_ZIP="$UPDATE_ZIP"
VERSION_TXT="$VERSION_TXT"
EOF
echo "  Created release-info.env"

echo ""
echo "=== Build complete ==="
echo "Distribution: $VERSION_DIR"
echo "Zip: $VERSION_ZIP"
echo "Update Zip: $UPDATE_ZIP"
echo "Version File: $VERSION_TXT"
echo ""
