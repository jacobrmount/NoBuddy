#!/bin/bash

# Test script for NoBuddy
echo "🧪 Running NoBuddy tests..."

# Run unit tests
xcodebuild test -project NoBuddy.xcodeproj -scheme NoBuddy -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

echo "✅ Tests completed"
