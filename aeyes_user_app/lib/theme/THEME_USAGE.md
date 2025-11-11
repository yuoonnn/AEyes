# AppTheme Usage Guide

This guide shows you how to use the centralized theme system in your AEyes app.

## Quick Start

The theme is already integrated in `main.dart`. You can now use it throughout your app!

## Using Colors

### Instead of hardcoded colors:
```dart
// ❌ Old way
final green = const Color(0xFF388E3C);
final greenAccent = const Color(0xFF66BB6A);

// ✅ New way
import 'package:aeyes_user_app/theme/app_theme.dart';

final green = AppTheme.primaryGreen;
final greenAccent = AppTheme.accentGreen;
```

### Semantic Colors:
```dart
AppTheme.success    // For success states
AppTheme.warning    // For warnings
AppTheme.error      // For errors
AppTheme.info       // For informational messages
```

### Colors with Opacity:
```dart
// Primary color with 10% opacity
AppTheme.primaryWithOpacity(0.1)

// Accent color with 20% opacity
AppTheme.accentWithOpacity(0.2)
```

## Using Spacing

### Instead of magic numbers:
```dart
// ❌ Old way
const SizedBox(height: 16);
padding: const EdgeInsets.all(24.0);

// ✅ New way
const SizedBox(height: AppTheme.spacingMD);
padding: AppTheme.paddingLG;
```

### Common Spacing Values:
- `AppTheme.spacingXS` = 4px
- `AppTheme.spacingSM` = 8px
- `AppTheme.spacingMD` = 16px
- `AppTheme.spacingLG` = 24px
- `AppTheme.spacingXL` = 32px

### Pre-defined Padding:
```dart
padding: AppTheme.paddingMD;              // All sides: 16px
padding: AppTheme.paddingHorizontalLG;    // Left/Right: 24px
padding: AppTheme.paddingVerticalSM;      // Top/Bottom: 8px
```

## Using Border Radius

```dart
// ❌ Old way
borderRadius: BorderRadius.circular(16)

// ✅ New way
borderRadius: AppTheme.borderRadiusLG
```

### Available Radius:
- `AppTheme.borderRadiusXS` = 4px
- `AppTheme.borderRadiusSM` = 8px
- `AppTheme.borderRadiusMD` = 12px
- `AppTheme.borderRadiusLG` = 16px
- `AppTheme.borderRadiusXL` = 24px

## Using Text Styles

```dart
// ❌ Old way
Text(
  'Title',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
)

// ✅ New way
Text(
  'Title',
  style: AppTheme.textStyleTitle,
)
```

### Available Text Styles:
- `AppTheme.textStyleHeadline1` - 32px, bold
- `AppTheme.textStyleHeadline2` - 28px, bold
- `AppTheme.textStyleHeadline3` - 24px, semi-bold
- `AppTheme.textStyleTitle` - 18px, semi-bold
- `AppTheme.textStyleSubtitle` - 16px, medium
- `AppTheme.textStyleBody` - 14px, regular
- `AppTheme.textStyleBodyLarge` - 16px, regular
- `AppTheme.textStyleCaption` - 12px, regular
- `AppTheme.textStyleOverline` - 10px, medium

## Using Button Styles

```dart
// Primary button
ElevatedButton(
  onPressed: () {},
  style: AppTheme.primaryButtonStyle,
  child: Text('Submit'),
)

// Secondary button
ElevatedButton(
  onPressed: () {},
  style: AppTheme.secondaryButtonStyle,
  child: Text('Cancel'),
)

// Text button
TextButton(
  onPressed: () {},
  style: AppTheme.textButtonStyle,
  child: Text('Learn More'),
)
```

## Using Card Styles

```dart
// Using Card widget (automatically styled)
Card(
  child: YourContent(),
)

// Using BoxDecoration
Container(
  decoration: AppTheme.cardDecoration,
  child: YourContent(),
)
```

## Using Status Colors

```dart
// Get color based on status string
Color statusColor = AppTheme.getStatusColor('Connected');  // Returns success green
Color statusColor = AppTheme.getStatusColor('Failed');     // Returns error red
Color statusColor = AppTheme.getStatusColor('Scanning');   // Returns info blue
```

## Example: Refactoring a Screen

### Before:
```dart
Widget build(BuildContext context) {
  final green = const Color(0xFF388E3C);
  final greenAccent = const Color(0xFF66BB6A);
  
  return Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Hello',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: green,
            ),
          ),
        ),
      ),
    ),
  );
}
```

### After:
```dart
import 'package:aeyes_user_app/theme/app_theme.dart';

Widget build(BuildContext context) {
  return Scaffold(
    body: Padding(
      padding: AppTheme.paddingLG,
      child: Card(
        elevation: AppTheme.elevationHigh,
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.borderRadiusLG,
        ),
        child: Padding(
          padding: AppTheme.paddingMD,
          child: Text(
            'Hello',
            style: AppTheme.textStyleTitle.copyWith(
              color: AppTheme.primaryGreen,
            ),
          ),
        ),
      ),
    ),
  );
}
```

## Benefits

1. **Consistency** - All screens use the same design tokens
2. **Maintainability** - Change colors/spacing in one place
3. **Type Safety** - No magic numbers or hardcoded values
4. **Dark Mode** - Automatically supported
5. **Scalability** - Easy to add new design tokens

## Next Steps

1. Start refactoring screens one by one
2. Replace hardcoded colors with `AppTheme` constants
3. Replace magic numbers with spacing constants
4. Use predefined text styles for consistency

