#!/bin/bash

echo "AI Tools Hub - Install App"
echo "========================="
echo "This script will install the AI Tools Hub app to your Applications folder."
echo ""

# Check if the app exists in the build directory
if [ -d "build/Release/AIToolsHub.app" ]; then
    APP_PATH="build/Release/AIToolsHub.app"
elif [ -d "build/Release/AIToolsHubApp.app" ]; then
    APP_PATH="build/Release/AIToolsHubApp.app"
else
    echo "Error: Could not find the built app in the build/Release directory."
    echo "Please run ./build_app.sh first to build the app."
    exit 1
fi

echo "Found app at: $APP_PATH"
echo ""

# Ask for confirmation
echo "This will copy the app to your Applications folder."
read -p "Do you want to continue? (y/n): " answer

if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    echo "Installation cancelled."
    exit 0
fi

# Copy the app to Applications
echo ""
echo "Copying app to Applications folder..."
cp -R "$APP_PATH" "/Applications/"

if [ $? -eq 0 ]; then
    echo ""
    echo "Installation successful!"
    echo "You can now launch AI Tools Hub from your Applications folder or Spotlight."
    echo ""
    echo "Would you like to launch the app now?"
    read -p "(y/n): " launch_answer
    
    if [ "$launch_answer" = "y" ] || [ "$launch_answer" = "Y" ]; then
        echo "Launching AI Tools Hub..."
        open "/Applications/$(basename "$APP_PATH")"
    fi
else
    echo ""
    echo "Error: Failed to copy the app to Applications folder."
    echo "You might need to run this script with sudo:"
    echo "sudo ./install_app.sh"
fi 