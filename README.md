# AI Tools Hub

A macOS menu bar application that integrates multiple web-based AI tools into a single, convenient interface.

## Overview

AI Tools Hub is a native macOS application that lives in your menu bar, providing quick access to popular AI services:

- ChatGPT
- Claude
- Copilot
- Perplexity
- DeepSeek

Each service maintains its own separate session, allowing you to switch between them seamlessly while preserving your conversation history.

## Features

- **Menu Bar Integration**: Access all AI tools from a convenient menu bar icon
- **Single Window Interface**: All AI services in one window with a simple dropdown to switch between them
- **Keyboard Shortcuts**: Quickly access specific AI services with keyboard shortcuts (⌘⌥1 through ⌘⌥5)
- **Session Management**: Each AI service maintains its own separate session
- **Native macOS Experience**: Built with SwiftUI for a seamless macOS experience

## Getting Started

The easiest way to get started is to run the master script:

```
./get_started.sh
```

This interactive script will guide you through the entire process of preparing, building, running, and installing the app.

### Option 1: Quick Setup (Recommended)

1. Run the preparation script to ensure all necessary files are available:
   ```
   ./prepare_project.sh
   ```

2. Build the application using the build script:
   ```
   ./build_app.sh
   ```

3. Run the app:
   ```
   ./run_app.sh
   ```

4. Optionally, install the app to your Applications folder:
   ```
   ./install_app.sh
   ```

### Option 2: Manual Setup with Xcode

1. Open the project in Xcode:
   - If you have an existing project: Open `AIToolsHub.xcodeproj` or `AIToolsHubApp/AIToolsHubApp.xcodeproj`
   - If not, create a new macOS app project in Xcode

2. Ensure the project has the following settings:
   - Minimum deployment target: macOS 11.0 or later
   - In Info.plist, set `LSUIElement` to `YES` (makes it a menu bar app)
   - App Sandbox: Disabled (to allow web access)

3. Build and run the app in Xcode (⌘R)

## Usage

1. After launching the app, you'll see a brain icon in your menu bar
2. Click the icon to open the AI Tools Hub window
3. Use the dropdown menu at the top to switch between different AI services
4. Each service maintains its own session, so you can switch between them without losing your place
5. Use keyboard shortcuts for quick access:
   - ⌘⌥1: ChatGPT
   - ⌘⌥2: Claude
   - ⌘⌥3: Copilot
   - ⌘⌥4: Perplexity
   - ⌘⌥5: DeepSeek

## Project Structure

- `AIToolsApp.swift`: Main app entry point
- `Models/AIService.swift`: Defines the AI service model and available services
- `Views/AIWebView.swift`: WebView implementation for displaying AI services
- `Views/MainChatView.swift`: Main UI for the app
- `Managers/MenuBarManager.swift`: Handles menu bar integration and window management
- `Managers/KeyboardShortcutManager.swift`: Manages global keyboard shortcuts

## Helper Scripts

- `get_started.sh`: Master script that guides you through the entire process
- `prepare_project.sh`: Creates all necessary files and directories
- `explore_project.sh`: Interactive script to explore the project structure
- `build_app.sh`: Builds the app using xcodebuild
- `run_app.sh`: Launches the built app
- `install_app.sh`: Installs the app to your Applications folder
- `check_scripts.sh`: Verifies that all scripts are available and executable

## Requirements

- macOS 11.0 or later
- Xcode 12.0 or later (for building from source)

## Privacy

This app does not collect any data. It simply embeds the web interfaces of the AI services. You will need to log in to each service with your own credentials, and the app will maintain those sessions.

## License

This project is available under the MIT License. See the LICENSE file for more information. 