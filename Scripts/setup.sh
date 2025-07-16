#!/bin/bash

# NoBuddy iOS Project Setup Script
# This script automates the initial setup for the NoBuddy iOS project

set -e  # Exit on any error

echo "🚀 Setting up NoBuddy iOS Project..."

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed. Please install Xcode 15.0 or later."
    exit 1
fi

# Check Xcode version
XCODE_VERSION=$(xcodebuild -version | head -n 1 | awk '{print $2}')
echo "✅ Found Xcode version: $XCODE_VERSION"

# Create Xcode project structure
echo "📁 Creating Xcode project structure..."

# Main project creation (this would typically be done in Xcode)
echo "⚠️  Note: You'll need to create the Xcode project manually in Xcode with the following configuration:"
echo "   - Product Name: NoBuddy"
echo "   - Interface: SwiftUI"
echo "   - Language: Swift"
echo "   - Bundle Identifier: com.nobuddy.app"
echo "   - Deployment Target: iOS 16.0"

# Create additional directories that aren't created by default
echo "📂 Creating project directories..."
mkdir -p Documentation/API
mkdir -p Documentation/Architecture
mkdir -p Documentation/UserGuides
mkdir -p Scripts/Build
mkdir -p Scripts/Deploy
mkdir -p Assets/Icons
mkdir -p Assets/Screenshots

# Create placeholder files for development
echo "📄 Creating placeholder files..."

# Create a simple project configuration file
cat > project_config.json << EOF
{
  "project_name": "NoBuddy",
  "bundle_id": "com.nobuddy.app",
  "deployment_target": "16.0",
  "swift_version": "5.9",
  "xcode_version": "15.0",
  "targets": [
    {
      "name": "NoBuddy",
      "type": "app",
      "bundle_id": "com.nobuddy.app"
    },
    {
      "name": "NoBuddyWidget",
      "type": "widget-extension",
      "bundle_id": "com.nobuddy.app.widget"
    },
    {
      "name": "NoBuddyIntents",
      "type": "app-intents-extension",
      "bundle_id": "com.nobuddy.app.intents"
    }
  ],
  "dependencies": [
    {
      "name": "KeychainAccess",
      "url": "https://github.com/kishikawakatsumi/KeychainAccess.git",
      "version": "4.2.2"
    },
    {
      "name": "SwiftUI-Introspect",
      "url": "https://github.com/siteline/SwiftUI-Introspect.git",
      "version": "1.1.3"
    }
  ]
}
EOF

# Create development guidelines
cat > Documentation/DEVELOPMENT_GUIDELINES.md << EOF
# NoBuddy Development Guidelines

## Code Style
- Follow Swift naming conventions
- Use SwiftLint for consistency
- Maximum line length: 120 characters
- Use meaningful variable and function names

## Architecture Patterns
- MVVM with Combine
- Single responsibility principle
- Dependency injection for services
- Protocol-oriented programming

## Git Workflow
- Feature branches: \`feature/description\`
- Bug fixes: \`fix/description\`
- Releases: \`release/version\`
- Commit messages: Follow conventional commits

## Testing Requirements
- Unit test coverage: 80%+
- UI tests for critical user flows
- Integration tests for API interactions
- Performance tests for widgets

## Security Guidelines
- Never commit API keys or tokens
- Use Keychain for sensitive data
- Validate all user inputs
- Implement certificate pinning

## Performance Standards
- App launch time: < 2 seconds
- Network requests: < 5 seconds timeout
- Widget updates: < 3 seconds
- Memory usage: < 50MB baseline
EOF

# Create API documentation template
cat > Documentation/API/NOTION_API_REFERENCE.md << EOF
# Notion API Reference for NoBuddy

## Authentication
- Bearer token authentication
- Token stored securely in Keychain
- Rate limiting: 3 requests per second

## Endpoints Used

### Databases
- GET /v1/databases/{database_id}
- POST /v1/databases/{database_id}/query
- PATCH /v1/databases/{database_id}

### Pages
- GET /v1/pages/{page_id}
- POST /v1/pages
- PATCH /v1/pages/{page_id}

### Blocks
- GET /v1/blocks/{block_id}/children
- PATCH /v1/blocks/{block_id}
- DELETE /v1/blocks/{block_id}

### Search
- POST /v1/search

### Users
- GET /v1/users/me
- GET /v1/users
EOF

# Create build script
cat > Scripts/Build/build.sh << EOF
#!/bin/bash

# Build script for NoBuddy
echo "🔨 Building NoBuddy..."

# Clean build directory
xcodebuild clean -project NoBuddy.xcodeproj -scheme NoBuddy

# Build for simulator
xcodebuild build -project NoBuddy.xcodeproj -scheme NoBuddy -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

echo "✅ Build completed successfully"
EOF

chmod +x Scripts/Build/build.sh

# Create test script
cat > Scripts/test.sh << EOF
#!/bin/bash

# Test script for NoBuddy
echo "🧪 Running NoBuddy tests..."

# Run unit tests
xcodebuild test -project NoBuddy.xcodeproj -scheme NoBuddy -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

echo "✅ Tests completed"
EOF

chmod +x Scripts/test.sh

echo "✅ Project setup completed!"
echo ""
echo "📋 Next Steps:"
echo "1. Open Xcode and create a new iOS project with the settings shown above"
echo "2. Replace the default project structure with the one outlined in Documentation/PROJECT_SETUP.md"
echo "3. Add the Swift Package dependencies listed in project_config.json"
echo "4. Implement the core features as outlined in the project documentation"
echo ""
echo "📚 Important Files Created:"
echo "   - Documentation/PROJECT_SETUP.md (Comprehensive setup guide)"
echo "   - Documentation/DEVELOPMENT_GUIDELINES.md (Development standards)"
echo "   - project_config.json (Project configuration)"
echo "   - Scripts/setup.sh (This setup script)"
echo "   - Scripts/build.sh (Build automation)"
echo ""
echo "🎉 Ready to start development!" 