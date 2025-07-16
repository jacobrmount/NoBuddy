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
- Feature branches: `feature/description`
- Bug fixes: `fix/description`
- Releases: `release/version`
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
