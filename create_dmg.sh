#!/bin/bash

# Exit on any error
set -e

echo "Apple AI - Create DMG Installer"
echo "=============================="
echo ""

# Configuration
APP_NAME="Apple AI"
DMG_NAME="Apple_AI"
DMG_FINAL="${DMG_NAME}.dmg"
VOLUME_NAME="Apple AI"

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg tool is not installed."
    echo "Please install it using: brew install create-dmg"
    exit 1
fi

# Make sure we have the app
if [ ! -d "${APP_NAME}.app" ]; then
    echo "App not found. Building it first..."
    ./build_app.sh
    
    if [ ! -d "${APP_NAME}.app" ]; then
        echo "Error: Failed to build the app. DMG creation aborted."
        exit 1
    fi
fi

# Remove any existing DMG file
if [ -f "${DMG_FINAL}" ]; then
    echo "Removing existing DMG file..."
    rm -f "${DMG_FINAL}"
fi

# Create a temporary directory for DMG contents and background
echo "Setting up DMG contents..."
TMP_DIR="tmp_dmg"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"
mkdir -p "${TMP_DIR}/.background"

# Prepare background image - creating a standard Mac installer look
BACKGROUND_IMG="${TMP_DIR}/.background/background.png"

echo "Creating professional DMG background..."
if command -v convert &> /dev/null; then
    # Create a clean, simple, standard-looking background with gradient
    convert -size 540x380 \
        gradient:white-aliceblue \
        -bordercolor white -border 30 \
        "${BACKGROUND_IMG}"
    
    # Add a nice arrow pointing from left to right
    convert "${BACKGROUND_IMG}" \
        -fill "#0068da" -stroke "#0068da" -strokewidth 3 \
        -draw "path 'M 245,190 L 345,190 L 345,175 L 380,205 L 345,235 L 345,220 L 245,220 Z'" \
        "${BACKGROUND_IMG}"
else
    echo "Warning: ImageMagick not installed. Using simple background."
    # Create a simple white background as fallback
    cat > "${TMP_DIR}/.background/background.svg" << EOF
<svg width="600" height="400" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#f7f7f7;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#f0f8ff;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="600" height="400" fill="url(#grad)"/>
  <path d="M 245,190 L 345,190 L 345,175 L 380,205 L 345,235 L 345,220 L 245,220 Z" fill="#0068da" stroke="#0068da" stroke-width="3"/>
</svg>
EOF
    if command -v rsvg-convert &> /dev/null; then
        rsvg-convert "${TMP_DIR}/.background/background.svg" -o "${BACKGROUND_IMG}"
    else
        # If no conversion tools available, create a simple white background
        cat > "${BACKGROUND_IMG}" << EOF
<html>
<body style="background-color: white;">
</body>
</html>
EOF
    fi
fi

# Copy the app to the temporary directory
echo "Copying app to the staging area..."
cp -R "${APP_NAME}.app" "${TMP_DIR}/"

# Use create-dmg to create a professional DMG with standard Mac layout
echo "Creating DMG with create-dmg..."
create-dmg \
    --volname "${VOLUME_NAME}" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --background "${BACKGROUND_IMG}" \
    --icon-size 128 \
    --icon "${APP_NAME}.app" 150 205 \
    --app-drop-link 450 205 \
    --no-internet-enable \
    "${DMG_FINAL}" \
    "${TMP_DIR}"

# Check if DMG creation was successful
if [ -f "${DMG_FINAL}" ]; then
    echo ""
    echo "DMG creation complete!"
    echo "Final DMG file: ${DMG_FINAL}"
    echo ""
    echo "Instructions for users:"
    echo "1. Double-click the DMG file to open it"
    echo "2. Drag the Apple AI app to the Applications folder"
    echo "3. Eject the disk image"
    echo "4. Launch Apple AI from the Applications folder or Launchpad"
    echo ""
    echo "To test the DMG, double-click ${DMG_FINAL} in Finder."
else
    echo "Error: DMG creation failed."
    exit 1
fi

# Clean up the temporary directory
echo "Cleaning up..."
rm -rf "${TMP_DIR}"

exit 0 