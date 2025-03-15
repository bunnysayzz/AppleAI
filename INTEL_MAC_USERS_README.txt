# Apple AI - Intel Mac Compatibility Guide

## Issue
Some Intel Mac users may experience issues running Apple AI directly from the .dmg file.
This is because the app may have been built primarily for Apple Silicon (arm64) architecture.

## Solutions

### Solution 1: Install Rosetta 2
The easiest solution is to install Rosetta 2, which allows Apple Silicon apps to run on Intel Macs:

1. Open Terminal
2. Run the command: softwareupdate --install-rosetta

This only needs to be done once, and then Apple AI should run correctly.

### Solution 2: Use the Universal DMG
If available, download and use the "Apple_AI_Universal.dmg" instead of the regular DMG.
This version contains a universal binary that works on both Intel and Apple Silicon Macs.

### Solution 3: Build from Source
If you're comfortable with development tools:

1. Clone the repository
2. Run the 'build_universal_direct.sh' script
3. This will create a universal binary app that works on both architectures

## Technical Details
Modern Mac apps can be built for different CPU architectures:
- arm64: For Apple Silicon (M1, M2, etc.) Macs
- x86_64: For Intel Macs
- Universal: Contains code for both architectures

If you want to check the architecture of an app:
1. Open Terminal
2. Run: lipo -archs "/Applications/Apple AI.app/Contents/MacOS/AIToolsHub"

For additional help, please visit our support forum or GitHub repository.
