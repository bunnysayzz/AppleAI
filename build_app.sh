#!/bin/bash

# Exit on any error
set -e

echo "AppleAI - Build Script"
echo "===================="
echo "This script will build the AppleAI app from the command line."
echo ""

# Check if xcodebuild is available
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild is not available. Please make sure Xcode is installed."
    exit 1
fi

# Clean previous builds
rm -rf build/
mkdir -p build/

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
    echo "Error: Could not find Xcode project"
    exit 1
fi

echo ""
echo "Building the app..."
echo ""

# Build the app
xcodebuild -project "$PROJECT_PATH" \
           -scheme "$SCHEME" \
           -configuration Release \
           -destination 'platform=macOS' \
           -derivedDataPath build \
           build

# Check if the build was successful
if [ $? -eq 0 ]; then
    # Find the app in the build directory
    APP_PATH=$(find build -name "*.app" -type d | head -n 1)
    
    if [ -n "$APP_PATH" ]; then
        echo ""
        echo "Build successful! App is located at: $APP_PATH"
        echo ""
        echo "You can run the app by double-clicking it in Finder or by running:"
        echo "open \"$APP_PATH\""
        echo ""
        
        # Copy the app to the current directory for easy access
        APP_NAME="Apple AI.app"
        cp -R "$APP_PATH" "./$APP_NAME"
        echo "A copy of the app has been placed in the current directory: ./$APP_NAME"
        
        # Ask if the user wants to run the app
        read -p "Do you want to run the app now? (y/n): " RUN_APP
        if [[ "$RUN_APP" =~ ^[Yy]$ ]]; then
            open "$APP_PATH"
            echo "App launched!"
        fi
    else
        echo ""
        echo "Build seems successful, but couldn't find the app in the build directory."
        echo "Check the build directory manually: build"
    fi
else
    echo ""
    echo "Build failed. Please check the error messages above."
fi 