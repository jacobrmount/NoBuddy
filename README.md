# NoBuddy

A powerful iOS companion app for Notion that brings your workspace to your iPhone with seamless integration through widgets, shortcuts, and secure token management.

## 🎯 Overview

NoBuddy transforms how you interact with Notion on iOS by providing:
- **Native iOS integration** through widgets and shortcuts
- **Secure token management** for multiple Notion workspaces
- **Powerful automation** via iOS Shortcuts and App Intents
- **Real-time data display** through customizable widgets

## ✨ Features

### 🔐 Token Management
- **Secure Storage**: Keychain-based storage for Notion integration tokens
- **Multi-Workspace Support**: Manage tokens for multiple Notion workspaces
- **Token Validation**: Real-time verification of token validity
- **CRUD Operations**: Complete token lifecycle management

### 🔗 iOS Shortcuts Integration
- **App Intents**: Native iOS shortcuts for all Notion API operations
- **Siri Integration**: Voice commands for hands-free Notion interaction
- **Custom Workflows**: Build complex automation sequences
- **Parameter Validation**: Smart input validation and suggestions

### 📱 iOS Widgets
- **Multiple Sizes**: Small (1x1), Medium (2x1), and Large (2x2) widgets
- **Real-time Updates**: Live data from your Notion databases
- **Deep Linking**: Tap widgets to open specific content
- **Customizable**: Configure data sources and display options

### 🛠 Core Capabilities
- **Complete Notion API Coverage**: Support for databases, pages, blocks, and more
- **Offline Support**: Cached data for offline viewing
- **Rate Limit Handling**: Intelligent API request management
- **Error Recovery**: Robust error handling and user feedback

## 🏗 Technical Architecture

### Project Structure
```
NoBuddy/
├── NoBuddy/                    # Main app target
│   ├── Models/                 # Data models and entities
│   ├── Views/                  # SwiftUI views and screens
│   ├── ViewModels/             # MVVM view models
│   ├── Services/               # API and business logic services
│   ├── Extensions/             # Swift extensions and utilities
│   └── Resources/              # Assets, localizations, config
├── NoBuddyWidget/              # Widget extension
├── NoBuddyIntents/             # App Intents extension
├── NoBuddyTests/               # Unit and integration tests
└── NoBuddyUITests/             # UI automation tests
```

### Technology Stack
- **Framework**: SwiftUI + UIKit (iOS 16.0+)
- **Architecture**: MVVM with Combine
- **Networking**: URLSession with custom Notion API client
- **Storage**: Core Data + Keychain Services
- **Dependencies**: Swift Package Manager

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 16.0+ deployment target
- Apple Developer account (for device testing)
- Notion integration token(s)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd NoBuddy
   ```

2. **Open in Xcode**
   ```bash
   open NoBuddy.xcodeproj
   ```

3. **Configure your team and bundle identifier**
   - Select the NoBuddy project in Xcode
   - Update the Team and Bundle Identifier in Signing & Capabilities
   - Ensure all targets have proper signing

4. **Build and run**
   - Select your target device or simulator
   - Press Cmd+R to build and run

### First Launch Setup

1. **Create a Notion Integration**
   - Visit [Notion Developers](https://www.notion.so/my-integrations)
   - Create a new integration and copy the token
   - Grant necessary permissions to your pages/databases

2. **Add Token in NoBuddy**
   - Launch the app
   - Navigate to Token Management
   - Add your Notion integration token
   - Verify connection to your workspace

## 📝 Development Roadmap

### Phase 1: Foundation ✅
- [x] Project setup and architecture
- [x] Basic token management
- [x] Notion API client foundation
- [x] Core SwiftUI views

### Phase 2: Core Features 🚧
- [ ] Complete token CRUD operations
- [ ] Database and page operations
- [ ] Basic widget implementation
- [ ] Simple App Intents

### Phase 3: Advanced Features 📋
- [ ] Advanced widget configurations
- [ ] Complex App Intents workflows
- [ ] Offline data synchronization
- [ ] Share extension integration

### Phase 4: Polish & Optimization 📋
- [ ] Performance optimization
- [ ] Advanced error handling
- [ ] Accessibility improvements
- [ ] Comprehensive testing

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Notion API](https://developers.notion.com/) for the powerful integration capabilities
- Apple's [WidgetKit](https://developer.apple.com/documentation/widgetkit) and [App Intents](https://developer.apple.com/documentation/appintents) frameworks
- The iOS development community for best practices and inspiration

## 📞 Support

- **Issues**: Report bugs via [GitHub Issues](../../issues)
- **Discussions**: Join the conversation in [GitHub Discussions](../../discussions)
- **Documentation**: Check out the [Wiki](../../wiki) for detailed guides

---

**Built with ❤️ for the Notion and iOS communities** 