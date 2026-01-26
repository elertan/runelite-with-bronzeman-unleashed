#!/bin/bash
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/../bronzeman-unleashed"
RUNELITE_DIR="$SCRIPT_DIR"

# Source paths
SRC_JAVA="$PLUGIN_DIR/src/main/java/com.elertan"
SRC_RESOURCES="$PLUGIN_DIR/src/main/resources"

# Target paths
TARGET_JAVA="$RUNELITE_DIR/runelite-client/src/main/java/net/runelite/client/plugins/bronzemanunleashed"
TARGET_RESOURCES="$RUNELITE_DIR/runelite-client/src/main/resources/net/runelite/client/plugins/bronzemanunleashed"

# Package transformation
OLD_PACKAGE="com.elertan"
NEW_PACKAGE="net.runelite.client.plugins.bronzemanunleashed"

echo "=== Bronzeman Unleashed → RuneLite Sync ==="
echo "Source: $PLUGIN_DIR"
echo "Target: $RUNELITE_DIR"
echo ""

# Verify source exists
if [[ ! -d "$SRC_JAVA" ]]; then
    echo "ERROR: Source directory not found: $SRC_JAVA"
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
    sed -e "s|package $OLD_PACKAGE|package $NEW_PACKAGE|g" \
        -e "s|import $OLD_PACKAGE|import $NEW_PACKAGE|g" \
        -e "s|import static $OLD_PACKAGE|import static $NEW_PACKAGE|g" \
        "$src_file" > "$target_file"
done

# Count Java files
java_count=$(find "$TARGET_JAVA" -name "*.java" | wc -l | tr -d ' ')
echo "  Copied $java_count Java files"

# Copy resources (preserve directory structure)
echo "Copying resources..."
if [[ -d "$SRC_RESOURCES/icons" ]]; then
    mkdir -p "$TARGET_RESOURCES/icons"
    cp "$SRC_RESOURCES/icons"/* "$TARGET_RESOURCES/icons/" 2>/dev/null || true
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
JAR_PATH=$(find "$RUNELITE_DIR/runelite-client/build/libs" -name "client-*-shaded.jar" | head -1)
if [[ -z "$JAR_PATH" ]]; then
    echo "ERROR: Could not find shaded JAR"
    exit 1
fi

# Extract version from filename (e.g., client-1.12.13-SNAPSHOT-shaded.jar -> 1.12.13)
JAR_FILENAME=$(basename "$JAR_PATH")
VERSION=$(echo "$JAR_FILENAME" | sed -E 's/client-([0-9]+\.[0-9]+\.[0-9]+).*/\1/')

# Calculate plugin hub version (minor - 1, but not below 0)
MAJOR=$(echo "$VERSION" | cut -d. -f1)
MINOR=$(echo "$VERSION" | cut -d. -f2)
PATCH=$(echo "$VERSION" | cut -d. -f3)
if [[ "$PATCH" -gt 0 ]]; then
    PLUGINHUB_PATCH=$((PATCH - 1))
else
    PLUGINHUB_PATCH=0
fi
PLUGINHUB_VERSION="$MAJOR.$MINOR.$PLUGINHUB_PATCH"

echo ""
echo "=== Creating distribution ==="
echo "Version: $VERSION"
echo "Plugin Hub Version: $PLUGINHUB_VERSION"

# Create distribution folder
DIST_DIR="$RUNELITE_DIR/sync-bronzeman"
VERSION_DIR="$DIST_DIR/$VERSION"
mkdir -p "$VERSION_DIR"

# Copy JAR
cp "$JAR_PATH" "$VERSION_DIR/runelite.jar"
echo "  Copied runelite.jar"

# Create start.sh
cat > "$VERSION_DIR/start.sh" << EOF
#!/bin/bash
java "-Drunelite.pluginhub.version=$PLUGINHUB_VERSION" "-Dsun.java2d.uiScale=1.35" -jar runelite.jar
EOF
chmod +x "$VERSION_DIR/start.sh"
echo "  Created start.sh"

# Create start.bat
cat > "$VERSION_DIR/start.bat" << EOF
java "-Drunelite.pluginhub.version=$PLUGINHUB_VERSION" "-Dsun.java2d.uiScale=1.35" -jar .\runelite.jar
EOF
echo "  Created start.bat"

# Create zip
cd "$DIST_DIR"
zip -r "$VERSION.zip" "$VERSION"
echo "  Created $VERSION.zip"

echo ""
echo "=== Build complete ==="
echo "Distribution: $VERSION_DIR"
echo "Zip: $DIST_DIR/$VERSION.zip"
echo ""

read -p "Open distribution folder? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$VERSION_DIR"
fi
