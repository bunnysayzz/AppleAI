#!/bin/bash

# Exit on any error
set -e

echo "Apple AI - Create Universal DMG Installer"
echo "======================================"
echo "This script creates a universal DMG that works on both Intel and Apple Silicon Macs"
echo ""

# Configuration
APP_NAME="Apple AI"
DMG_NAME="Apple_AI_Universal"
DMG_FINAL="${DMG_NAME}.dmg"
VOLUME_NAME="Apple AI"

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo -e "${YELLOW}Error: create-dmg tool is not installed.${NC}"
    echo "Please install it using: brew install create-dmg"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${YELLOW}Error: xcodebuild is not available. Please make sure Xcode is installed.${NC}"
    exit 1
fi

echo -e "${BLUE}Step 1: Building universal binary app for both Intel and Apple Silicon${NC}"
echo ""

# Determine the project path and scheme
if [ -d "AppleAI/AppleAI.xcodeproj" ]; then
    PROJECT_PATH="AppleAI/AppleAI.xcodeproj"
    SCHEME="AIToolsHub"
    echo "Found AppleAI.xcodeproj, using it for the build."
elif [ -d "AppleAI.xcodeproj" ]; then
    PROJECT_PATH="AppleAI.xcodeproj"
    SCHEME="AIToolsHub"
    echo "Found AppleAI.xcodeproj, using it for the build."
else
    echo -e "${YELLOW}Error: Could not find Xcode project${NC}"
    exit 1
fi

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf build_universal/
mkdir -p build_universal/

# Build for Apple Silicon
echo "Building for Apple Silicon (arm64)..."
xcodebuild -project "$PROJECT_PATH" \
           -scheme "$SCHEME" \
           -configuration Release \
           -destination 'platform=macOS,arch=arm64' \
           -derivedDataPath build_universal/arm64 \
           build

# Build for Intel
echo "Building for Intel (x86_64)..."
xcodebuild -project "$PROJECT_PATH" \
           -scheme "$SCHEME" \
           -configuration Release \
           -destination 'platform=macOS,arch=x86_64' \
           -derivedDataPath build_universal/x86_64 \
           build

# Find the app paths
ARM64_APP_PATH=$(find build_universal/arm64 -name "*.app" -type d | head -n 1)
X86_64_APP_PATH=$(find build_universal/x86_64 -name "*.app" -type d | head -n 1)

if [ -z "$ARM64_APP_PATH" ] || [ -z "$X86_64_APP_PATH" ]; then
    echo -e "${YELLOW}Error: Could not find built apps${NC}"
    exit 1
fi

# Create a universal app by combining both architectures
echo -e "${BLUE}Step 2: Creating universal binary by combining both architectures${NC}"
UNIVERSAL_APP_PATH="build_universal/${APP_NAME}.app"
mkdir -p "$(dirname "$UNIVERSAL_APP_PATH")"

# Copy the Apple Silicon app as the base
cp -R "$ARM64_APP_PATH" "$UNIVERSAL_APP_PATH"

# Get the executable name
echo "Determining executable name..."
APP_EXECUTABLE_NAME=$(defaults read "$UNIVERSAL_APP_PATH/Contents/Info" CFBundleExecutable 2>/dev/null || echo "AIToolsHub")

# If executable name couldn't be determined, try to find it manually
if [ -z "$APP_EXECUTABLE_NAME" ]; then
    echo "Could not get executable name from Info.plist, searching manually..."
    # Look in the MacOS directory for the executable
    APP_EXECUTABLE_NAME=$(ls "$UNIVERSAL_APP_PATH/Contents/MacOS/" | head -n 1)
    
    if [ -z "$APP_EXECUTABLE_NAME" ]; then
        # If still not found, use the app name without spaces
        APP_EXECUTABLE_NAME="AIToolsHub"
        echo "Using default executable name: $APP_EXECUTABLE_NAME"
    else
        echo "Found executable name: $APP_EXECUTABLE_NAME"
    fi
else
    echo "Found executable name from Info.plist: $APP_EXECUTABLE_NAME"
fi

ARM64_EXECUTABLE="$ARM64_APP_PATH/Contents/MacOS/$APP_EXECUTABLE_NAME"
X86_64_EXECUTABLE="$X86_64_APP_PATH/Contents/MacOS/$APP_EXECUTABLE_NAME"
UNIVERSAL_EXECUTABLE="$UNIVERSAL_APP_PATH/Contents/MacOS/$APP_EXECUTABLE_NAME"

# Verify that executables exist
if [ ! -f "$ARM64_EXECUTABLE" ]; then
    echo -e "${YELLOW}Error: ARM64 executable not found at $ARM64_EXECUTABLE${NC}"
    echo "Contents of MacOS directory:"
    ls -la "$ARM64_APP_PATH/Contents/MacOS/"
    exit 1
fi

if [ ! -f "$X86_64_EXECUTABLE" ]; then
    echo -e "${YELLOW}Error: x86_64 executable not found at $X86_64_EXECUTABLE${NC}"
    echo "Contents of MacOS directory:"
    ls -la "$X86_64_APP_PATH/Contents/MacOS/"
    exit 1
fi

# Create universal binary using lipo
echo "Creating universal binary executable..."
lipo -create -output "$UNIVERSAL_EXECUTABLE" "$ARM64_EXECUTABLE" "$X86_64_EXECUTABLE"

# Verify the universal binary
echo "Verifying universal binary..."
lipo -info "$UNIVERSAL_EXECUTABLE"

# Remove any existing app in the current directory
if [ -d "./${APP_NAME}.app" ]; then
    echo "Removing existing app in current directory..."
    rm -rf "./${APP_NAME}.app"
fi

# Copy the universal app to the current directory using ditto to preserve all attributes
echo "Copying universal app to the current directory..."
ditto "$UNIVERSAL_APP_PATH" "./${APP_NAME}.app"

# Verify the copied app is universal
echo "Verifying the copied app is universal..."
lipo -info "./${APP_NAME}.app/Contents/MacOS/$APP_EXECUTABLE_NAME"

echo -e "${GREEN}Universal app created successfully!${NC}"
echo ""

# Remove any existing DMG file
if [ -f "${DMG_FINAL}" ]; then
    echo "Removing existing DMG file..."
    rm -f "${DMG_FINAL}"
fi

echo -e "${BLUE}Step 3: Creating DMG installer...${NC}"
echo ""

# Create a temporary directory for DMG contents and background
echo "Setting up DMG contents..."
TMP_DIR="tmp_dmg_universal"
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

# Copy the universal app to the temporary directory using ditto to preserve all attributes
echo "Copying universal app to the staging area..."
ditto "./${APP_NAME}.app" "${TMP_DIR}/${APP_NAME}.app"

# Add a README file with information about universal binary
cat > "${TMP_DIR}/README.txt" << EOF
Apple AI - Universal Binary

This application is a universal binary that works on both:
- Apple Silicon Macs (M1, M2, etc.)
- Intel-based Macs

Installation Instructions:
1. Drag the Apple AI icon to the Applications folder
2. Eject this disk image
3. Launch Apple AI from your Applications folder

For support, please visit: https://github.com/bunnysayzz/appleai
EOF

# Use create-dmg to create a professional DMG with standard Mac layout
echo "Creating universal DMG with create-dmg..."
create-dmg \
    --volname "${VOLUME_NAME}" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --background "${BACKGROUND_IMG}" \
    --icon-size 128 \
    --icon "${APP_NAME}.app" 150 205 \
    --app-drop-link 450 205 \
    --text-size 12 \
    --icon "README.txt" 350 350 \
    --no-internet-enable \
    "${DMG_FINAL}" \
    "${TMP_DIR}"

# Check if DMG creation was successful
if [ -f "${DMG_FINAL}" ]; then
    echo ""
    echo -e "${GREEN}Universal DMG creation complete!${NC}"
    echo "Final DMG file: ${DMG_FINAL}"
    echo ""
    echo "This DMG contains a universal binary app that works on both:"
    echo "- Apple Silicon Macs (M1, M2, etc.)" 
    echo "- Intel-based Macs"
    echo ""
    echo "Instructions for users:"
    echo "1. Double-click the DMG file to open it"
    echo "2. Drag the Apple AI app to the Applications folder"
    echo "3. Eject the disk image"
    echo "4. Launch Apple AI from the Applications folder or Launchpad"
    echo ""
    echo "To test the DMG, double-click ${DMG_FINAL} in Finder."
else
    echo -e "${YELLOW}Error: DMG creation failed.${NC}"
    exit 1
fi

# Clean up the temporary directory
echo "Cleaning up..."
rm -rf "${TMP_DIR}"

echo ""
echo -e "${GREEN}Universal DMG creation process completed successfully!${NC}"
exit 0 