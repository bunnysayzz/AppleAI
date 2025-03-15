#!/bin/bash

echo "AI Tools Hub - Run App Script"
echo "============================"
echo ""

# Find the app
if [ -d "build/Build/Products/Release/AppleAI.app" ]; then
    APP_PATH="build/Build/Products/Release/AppleAI.app"
elif [ -d "build/Build/Products/Release/AppleAI.app" ]; then
    APP_PATH="build/Build/Products/Release/AppleAI.app"
elif [ -d "AppleAI.app" ]; then
    APP_PATH="AppleAI.app"
else
    echo "Error: Could not find AppleAI.app"
    exit 1
fi

# Run the app
echo "Running $APP_PATH..."
open "$APP_PATH"

# Print keyboard shortcuts
echo "
AppleAI is now running! Look for the icon in your menu bar.
Use these keyboard shortcuts to:

⌘⌥O - Toggle main window
⌘⌥1 - Open ChatGPT
⌘⌥2 - Open Claude
⌘⌥3 - Open Copilot
⌘⌥4 - Open Perplexity
⌘⌥5 - Open DeepSeek
⌘⌥6 - Open Grok
"

echo ""
echo "App launched successfully!"
echo "Look for the brain icon in your menu bar."
echo ""
echo "Keyboard shortcuts:"
echo "- ⌘⌥O: Toggle the main window"
echo "- ⌘⌥1: Open ChatGPT"
echo "- ⌘⌥2: Open Claude"
echo "- ⌘⌥3: Open Copilot"
echo "- ⌘⌥4: Open Perplexity"
echo "- ⌘⌥5: Open DeepSeek"
echo "- ⌘⌥6: Open Grok" 