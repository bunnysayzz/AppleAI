#!/bin/bash

# Create the AILogos directory in the asset catalog if it doesn't exist
mkdir -p "AppleAI/Assets.xcassets/AILogos"

# Create Contents.json for the AILogos directory
echo '{"info":{"author":"xcode","version":1},"properties":{"provides-namespace":true}}' > "AppleAI/Assets.xcassets/AILogos/Contents.json"

# Array of logo names
logos=("chatgpt" "claude" "copilot" "perplexity" "deekseek" "grok")

# For each logo
for logo in "${logos[@]}"; do
  # Create directory for the logo
  mkdir -p "AppleAI/Assets.xcassets/AILogos/${logo}.imageset"
  
  # Create Contents.json
  cat > "AppleAI/Assets.xcassets/AILogos/${logo}.imageset/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "${logo}.png",
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "original"
  }
}
EOF
  
  # Copy the logo file
  cp "ailogos/${logo}.png" "AppleAI/Assets.xcassets/AILogos/${logo}.imageset/"
done

echo "AI logos successfully set up in asset catalog" 