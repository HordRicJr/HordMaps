# Contributing to HordMaps 🗺️

Thank you for your interest in contributing to HordMaps! We welcome contributions from developers of all skill levels and backgrounds.

## 🎃 Hacktoberfest 2025

We're excited to participate in Hacktoberfest 2025! Here's how you can get involved:

### Hacktoberfest Quick Start
1. **Register** at [hacktoberfest.com](https://hacktoberfest.com)
2. **Find issues** labeled `hacktoberfest` in our [issue tracker](https://github.com/yourusername/hordmaps/issues?q=is%3Aissue+is%3Aopen+label%3Ahacktoberfest)
3. **Start with** `good first issue` if you're new to the project
4. **Submit quality PRs** - we value quality over quantity!

### Hacktoberfest Labels
- 🎃 `hacktoberfest` - Issues specifically for Hacktoberfest
- 🌱 `good first issue` - Perfect for newcomers
- 🆘 `help wanted` - We need community help with these
- 📚 `documentation` - Help improve our docs
- 🐛 `bug` - Bug fixes welcome
- ✨ `enhancement` - New features and improvements

## 🚀 Quick Start for Contributors

### Prerequisites
- Flutter SDK 3.19.0+
- Dart SDK 3.3.0+
- Git
- Android Studio or VS Code with Flutter extension

### Development Setup
1. **Fork and clone**
   ```bash
   git clone https://github.com/yourusername/hordmaps.git
   cd hordmaps
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Create Azure Maps config**
   ```bash
   # Create lib/core/config/azure_maps_config.dart
   # Add your Azure Maps subscription key
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## 📝 How to Contribute

### 1. Choose Your Contribution Type

#### 🐛 Bug Fixes
- Check existing issues for bug reports
- Reproduce the bug locally
- Create a minimal test case
- Fix the bug and add tests

#### ✨ New Features
- Discuss the feature in an issue first
- Follow the existing architecture patterns
- Include comprehensive tests
- Update documentation

#### 📚 Documentation
- Improve README sections
- Add code comments
- Create tutorials or guides
- Fix typos and grammar

#### 🌍 Translations
- Add new language support
- Improve existing translations
- Follow i18n best practices

#### 🎨 UI/UX Improvements
- Follow Material Design 3 guidelines
- Ensure accessibility compliance
- Test on different screen sizes
- Maintain design consistency

### 2. Development Workflow

1. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-number
   ```

2. **Make your changes**
   - Follow the coding standards (see below)
   - Write tests for new functionality
   - Update documentation as needed

3. **Test your changes**
   ```bash
   flutter test
   flutter analyze
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add amazing new feature"
   ```

5. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```

## 🏗️ Architecture Guidelines

### Project Structure
Follow the existing project structure:
```
lib/
├── core/           # Configuration and core utilities
├── features/       # Feature-specific code
├── models/         # Data models
├── services/       # Business logic services
└── shared/         # Shared widgets and utilities
```

### Coding Standards

#### Dart/Flutter Standards
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use meaningful variable and function names
- Keep functions small and focused
- Add documentation comments for public APIs

#### Code Style
```dart
// ✅ Good
class NavigationService {
  /// Calculates the optimal route between two points
  Future<Route> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    TransportMode mode = TransportMode.car,
  }) async {
    // Implementation
  }
}

// ❌ Bad
class NavSvc {
  Future<Route> calc(LatLng o, LatLng d, [TransportMode? m]) async {
    // Implementation
  }
}
```

#### State Management
- Use Provider pattern for state management
- Keep providers focused on single responsibilities
- Use `ChangeNotifier` for reactive updates

#### Service Layer
- Create services for external API interactions
- Implement proper error handling
- Use dependency injection where appropriate

### Testing Guidelines

#### Unit Tests
```dart
// Test file: test/services/navigation_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hordmaps/services/navigation_service.dart';

void main() {
  group('NavigationService', () {
    late NavigationService navigationService;

    setUp(() {
      navigationService = NavigationService();
    });

    test('should calculate route between two points', () async {
      // Given
      final origin = LatLng(40.7128, -74.0060);
      final destination = LatLng(34.0522, -118.2437);

      // When
      final route = await navigationService.calculateRoute(
        origin: origin,
        destination: destination,
      );

      // Then
      expect(route, isNotNull);
      expect(route.distance, greaterThan(0));
    });
  });
}
```

#### Widget Tests
```dart
// Test UI components
testWidgets('MapScreen displays correctly', (WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(home: MapScreen()));
  
  expect(find.byType(FlutterMap), findsOneWidget);
  expect(find.byIcon(Icons.my_location), findsOneWidget);
});
```

## 📋 PR Guidelines

### Before Submitting
- [ ] Code passes `flutter analyze`
- [ ] All tests pass (`flutter test`)
- [ ] New features have tests
- [ ] Documentation is updated
- [ ] Code follows project conventions

### PR Template
When creating a PR, include:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature  
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Refactoring

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing completed
- [ ] Tested on Android
- [ ] Tested on iOS (if applicable)

## Screenshots (if applicable)
Add screenshots of UI changes

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests pass
```

### Review Process
1. **Automated checks** must pass (CI/CD)
2. **Code review** by maintainers
3. **Testing** on different devices
4. **Approval** and merge

## 🏷️ Issue Guidelines

### Reporting Bugs
Use the bug report template:
```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
What you expected to happen.

**Screenshots**
If applicable, add screenshots.

**Device Info:**
 - Device: [e.g. Pixel 7]
 - OS: [e.g. Android 13]
 - App Version: [e.g. 1.0.0]
```

### Feature Requests
Use the feature request template:
```markdown
**Is your feature request related to a problem?**
A clear description of what the problem is.

**Describe the solution you'd like**
A clear description of what you want to happen.

**Describe alternatives you've considered**
Other solutions you've thought about.

**Additional context**
Any other context or screenshots.
```

## 🎯 Focus Areas for Contributors

### High Priority
- 🐛 **Critical bug fixes**
- 🚀 **Performance optimizations**
- ♿ **Accessibility improvements**
- 🔒 **Security enhancements**

### Medium Priority
- ✨ **New navigation features**
- 🎨 **UI/UX improvements**
- 📱 **Platform compatibility**
- 🌍 **Internationalization**

### Low Priority (Good for beginners)
- 📚 **Documentation improvements**
- 🧹 **Code cleanup and refactoring**
- 🎯 **Test coverage improvements**
- 💅 **Minor UI polish**

## 💬 Communication

### Where to Ask Questions
- 💬 [GitHub Discussions](https://github.com/yourusername/hordmaps/discussions) - General questions and ideas
- 🐛 [GitHub Issues](https://github.com/yourusername/hordmaps/issues) - Bug reports and feature requests
- 📧 [Email](mailto:dev@hordmaps.com) - Private/sensitive matters

### Communication Guidelines
- Be respectful and inclusive
- Search existing issues before creating new ones
- Provide clear, detailed descriptions
- Use appropriate labels and templates

## 🏆 Recognition

Contributors will be recognized through:
- 📜 **All Contributors** section in README
- 🎉 **Special mentions** in release notes
- 🏆 **Contributor badges** (coming soon)
- 💝 **Swag** for significant contributions (when available)

## 📊 Stats & Metrics

Track your contributions:
- **GitHub Insights** - See your contribution graph
- **PR Activity** - Monitor your PR status and reviews
- **Issue Activity** - Track issues you've helped resolve

## 🔄 Release Process

### Versioning
We follow [Semantic Versioning](https://semver.org/):
- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality
- **PATCH** version for backwards-compatible bug fixes

### Release Schedule
- 🔄 **Minor releases**: Monthly
- 🐛 **Patch releases**: As needed
- 🚀 **Major releases**: Quarterly

## 📜 Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it to understand the standards we expect from our community.

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Azure Maps Documentation](https://docs.microsoft.com/en-us/azure/azure-maps/)
- [Material Design 3](https://m3.material.io/)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)

---

## 🎉 Thank You!

Thank you for contributing to HordMaps! Every contribution, no matter how small, helps make this project better for everyone. 

Happy coding! 🚀

---

*For questions about contributing, feel free to reach out via [GitHub Discussions](https://github.com/yourusername/hordmaps/discussions) or email us at dev@hordmaps.com.*