# Screen Refactoring Checklist

This document lists all screens that need to be refactored to use the centralized `AppTheme` system.

## Priority Levels
- 🔴 **High Priority** - Many hardcoded values, frequently used screens
- 🟡 **Medium Priority** - Moderate hardcoded values
- 🟢 **Low Priority** - Few hardcoded values, less frequently used

---

## Screens to Refactor

### 1. 🔴 **home_screen.dart** - HIGH PRIORITY
**Issues Found:**
- Hardcoded colors: `Color(0xFF388E3C)`, `Color(0xFF66BB6A)`
- Hardcoded spacing: `EdgeInsets.all(24.0)`, `EdgeInsets.all(16.0)`
- Hardcoded border radius: `BorderRadius.circular(16)`
- Hardcoded font sizes: `fontSize: 28`, `fontSize: 18`, `fontSize: 16`, `fontSize: 12`
- Hardcoded font weights: `FontWeight.bold`
- Hardcoded elevations: `elevation: 3`, `elevation: 4`, `elevation: 1`
- Multiple card widgets with inline styling

**Estimated Refactoring:**
- Replace ~15+ hardcoded color instances
- Replace ~20+ hardcoded spacing values
- Replace ~10+ hardcoded border radius values
- Replace ~15+ hardcoded text styles

---

### 2. 🔴 **guardian_dashboard_screen.dart** - HIGH PRIORITY
**Issues Found:**
- Hardcoded color: `Color(0xFF388E3C)`
- Hardcoded spacing: `EdgeInsets.all(24.0)`, `EdgeInsets.all(16.0)`, `EdgeInsets.only(bottom: 12)`
- Hardcoded border radius: `BorderRadius.circular(12)`
- Hardcoded font sizes: `fontSize: 28`, `fontSize: 18`, `fontSize: 16`, `fontSize: 14`, `fontSize: 12`
- Hardcoded font weights: `FontWeight.bold`, `FontWeight.w500`
- Hardcoded elevations: `elevation: 2`
- Multiple card widgets with inline styling

**Estimated Refactoring:**
- Replace ~10+ hardcoded color instances
- Replace ~25+ hardcoded spacing values
- Replace ~15+ hardcoded border radius values
- Replace ~20+ hardcoded text styles

---

### 3. 🟡 **login_screen.dart** - MEDIUM PRIORITY
**Issues Found:**
- Hardcoded colors: `Color(0xFF388E3C)`, `Color(0xFF66BB6A)`
- Hardcoded spacing: `EdgeInsets.symmetric(horizontal: 32.0)`
- Hardcoded font sizes: `fontSize: 28`, `fontSize: 16`
- Hardcoded letter spacing: `letterSpacing: 1.2`
- Uses `CustomButton` and `CustomTextField` (which may also need refactoring)

**Estimated Refactoring:**
- Replace ~5+ hardcoded color instances
- Replace ~8+ hardcoded spacing values
- Replace ~5+ hardcoded text styles

---

### 4. 🟡 **bluetooth_screen.dart** - MEDIUM PRIORITY
**Issues Found:**
- Hardcoded spacing: `EdgeInsets.all(12)`, `EdgeInsets.all(16.0)`, `EdgeInsets.symmetric(vertical: 4)`
- Hardcoded border radius: `BorderRadius.circular(10)`
- Hardcoded font sizes: `fontSize: 18`, `fontSize: 16`
- Hardcoded font weights: `FontWeight.bold`, `FontWeight.w500`
- Hardcoded elevations: `elevation: 2`
- Status color logic that could use `AppTheme.getStatusColor()`

**Estimated Refactoring:**
- Replace ~15+ hardcoded spacing values
- Replace ~8+ hardcoded border radius values
- Replace ~10+ hardcoded text styles
- Refactor status color logic

---

### 5. 🟡 **settings_screen.dart** - MEDIUM PRIORITY
**Issues Found:**
- Hardcoded colors: `Color(0xFF388E3C)`, `Color(0xFF66BB6A)`
- Hardcoded spacing: `EdgeInsets.all(20.0)`, `EdgeInsets.all(16)`, `EdgeInsets.symmetric(horizontal: 8.0)`
- Hardcoded border radius: `BorderRadius.circular(16)`, `BorderRadius.circular(12)`, `BorderRadius.circular(8)`
- Hardcoded font sizes: `fontSize: 18`, `fontSize: 16`, `fontSize: 12`
- Hardcoded font weights: `FontWeight.bold`, `FontWeight.w500`
- Hardcoded elevations: `elevation: 2`
- Multiple section cards with inline styling

**Estimated Refactoring:**
- Replace ~8+ hardcoded color instances
- Replace ~20+ hardcoded spacing values
- Replace ~10+ hardcoded border radius values
- Replace ~15+ hardcoded text styles

---

### 6. 🟡 **profile_screen.dart** - MEDIUM PRIORITY
**Issues Found:**
- Hardcoded color: `Color(0xFF388E3C)` (multiple instances)
- Hardcoded spacing: `EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0)`, `EdgeInsets.all(24.0)`, `EdgeInsets.all(16)`, `EdgeInsets.all(12)`, `EdgeInsets.all(6)`
- Hardcoded border radius: `BorderRadius.circular(16)`, `BorderRadius.circular(8)`
- Hardcoded font sizes: `fontSize: 24`, `fontSize: 18`, `fontSize: 14`, `fontSize: 12`
- Hardcoded font weights: `FontWeight.bold`, `FontWeight.w500`
- Hardcoded elevations: `elevation: 2`

**Estimated Refactoring:**
- Replace ~8+ hardcoded color instances
- Replace ~15+ hardcoded spacing values
- Replace ~8+ hardcoded border radius values
- Replace ~12+ hardcoded text styles

---

### 7. 🟡 **guardian_login_screen.dart** - MEDIUM PRIORITY
**Issues Found:**
- Hardcoded colors: `Color(0xFF388E3C)`, `Color(0xFF66BB6A)`
- Hardcoded spacing: `EdgeInsets.symmetric(horizontal: 32.0)`, `EdgeInsets.all(12)`
- Hardcoded border radius: `BorderRadius.circular(8)`
- Hardcoded font sizes: `fontSize: 24`, `fontSize: 16`
- Hardcoded font weights: `FontWeight.bold`

**Estimated Refactoring:**
- Replace ~5+ hardcoded color instances
- Replace ~8+ hardcoded spacing values
- Replace ~3+ hardcoded border radius values
- Replace ~5+ hardcoded text styles

---

### 8. 🟢 **map_screen.dart** - LOW PRIORITY
**Issues Found:**
- Hardcoded spacing: `EdgeInsets.all(16.0)`
- Hardcoded border radius: `BorderRadius.circular(8)`
- Hardcoded font sizes: `fontSize: 20`, `fontSize: 18`, `fontSize: 16`, `fontSize: 12`
- Hardcoded font weights: `FontWeight.bold`
- Hardcoded elevations: `elevation: 4`

**Estimated Refactoring:**
- Replace ~5+ hardcoded spacing values
- Replace ~3+ hardcoded border radius values
- Replace ~8+ hardcoded text styles

---

### 9. 🟢 **messages_screen.dart** - LOW PRIORITY
**Issues Found:**
- Hardcoded spacing: `EdgeInsets.all(8)`, `EdgeInsets.symmetric(vertical: 4, horizontal: 8)`
- Hardcoded font sizes: `fontSize: 18`, `fontSize: 14`, `fontSize: 12`
- Hardcoded font weights: `FontWeight.normal`, `FontWeight.bold`
- Hardcoded elevations: `elevation: 1`, `elevation: 3`

**Estimated Refactoring:**
- Replace ~5+ hardcoded spacing values
- Replace ~8+ hardcoded text styles
- Replace ~2+ hardcoded elevations

---

### 10. 🟢 **role_selection_screen.dart** - LOW PRIORITY
**Issues Found:**
- Hardcoded spacing: `EdgeInsets.all(32.0)`, `EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0)`
- Hardcoded font sizes: `fontSize: 28`, `fontSize: 22`
- Hardcoded font weights: `FontWeight.bold`
- Simple screen, minimal styling

**Estimated Refactoring:**
- Replace ~4+ hardcoded spacing values
- Replace ~3+ hardcoded text styles

---

### 11. 🟢 **registration_screen.dart** - LOW PRIORITY
**Issues Found:**
- Hardcoded spacing: `EdgeInsets.symmetric(horizontal: 32.0)`
- Hardcoded font sizes: `fontSize: 24`
- Hardcoded font weights: `FontWeight.bold`
- Uses `CustomButton` and `CustomTextField`

**Estimated Refactoring:**
- Replace ~4+ hardcoded spacing values
- Replace ~2+ hardcoded text styles

---

### 12. 🟢 **guardian_registration_screen.dart** - LOW PRIORITY
**Issues Found:**
- Hardcoded color: `Color(0xFF388E3C)` (likely, based on pattern)
- Similar structure to other registration/login screens

**Estimated Refactoring:**
- Similar to `guardian_login_screen.dart` and `registration_screen.dart`

---

## Widgets to Refactor

### 1. 🔴 **custom_button.dart** - HIGH PRIORITY
**Issues Found:**
- Hardcoded border radius: `BorderRadius.circular(12)`
- Hardcoded spacing: `EdgeInsets.symmetric(vertical: 16, horizontal: 20)`
- Hardcoded font sizes: `fontSize: 16`
- Hardcoded font weights: `FontWeight.w600`
- Hardcoded elevations: `elevation: 2`

**Estimated Refactoring:**
- Replace all hardcoded values with `AppTheme` constants
- Consider using `AppTheme.primaryButtonStyle`, `AppTheme.secondaryButtonStyle`, etc.

---

### 2. 🟡 **custom_textfield.dart** - MEDIUM PRIORITY
**Issues Found:**
- Uses default `OutlineInputBorder()` which may not match theme
- Should use `AppTheme.inputDecorationTheme`

**Estimated Refactoring:**
- Apply `AppTheme.inputDecorationTheme` or use theme-aware styling

---

### 3. 🟡 **main_scaffold.dart** - MEDIUM PRIORITY
**Issues Found:**
- Uses default `BottomNavigationBar` styling
- Should use `AppTheme.bottomNavigationBarTheme`

**Estimated Refactoring:**
- Apply `AppTheme.bottomNavigationBarTheme`

---

## Refactoring Summary

### Total Screens: 12
- 🔴 High Priority: 2 screens
- 🟡 Medium Priority: 6 screens
- 🟢 Low Priority: 4 screens

### Total Widgets: 3
- 🔴 High Priority: 1 widget
- 🟡 Medium Priority: 2 widgets

### Estimated Total Changes:
- **Colors**: ~60+ instances
- **Spacing**: ~150+ instances
- **Border Radius**: ~80+ instances
- **Text Styles**: ~120+ instances
- **Elevations**: ~30+ instances

---

## Recommended Refactoring Order

1. **Start with widgets** (custom_button.dart, custom_textfield.dart, main_scaffold.dart)
   - These are used across multiple screens
   - Fixing them will automatically improve all screens

2. **High priority screens** (home_screen.dart, guardian_dashboard_screen.dart)
   - Most visible and frequently used
   - Biggest impact on user experience

3. **Medium priority screens** (login_screen.dart, bluetooth_screen.dart, settings_screen.dart, profile_screen.dart, guardian_login_screen.dart)
   - Important but less frequently accessed
   - Good balance of effort vs. impact

4. **Low priority screens** (map_screen.dart, messages_screen.dart, role_selection_screen.dart, registration_screen.dart, guardian_registration_screen.dart)
   - Less frequently used
   - Quick wins for consistency

---

## Quick Reference: Common Replacements

### Colors
```dart
// Before
const Color(0xFF388E3C)  →  AppTheme.primaryGreen
const Color(0xFF66BB6A)  →  AppTheme.accentGreen
Colors.green             →  AppTheme.success
Colors.red               →  AppTheme.error
Colors.orange            →  AppTheme.warning
Colors.blue              →  AppTheme.info
```

### Spacing
```dart
// Before
EdgeInsets.all(16.0)                    →  AppTheme.paddingMD
EdgeInsets.all(24.0)                     →  AppTheme.paddingLG
EdgeInsets.symmetric(horizontal: 32.0)  →  AppTheme.paddingHorizontalXL
const SizedBox(height: 16)               →  SizedBox(height: AppTheme.spacingMD)
```

### Border Radius
```dart
// Before
BorderRadius.circular(12)  →  AppTheme.borderRadiusMD
BorderRadius.circular(16)  →  AppTheme.borderRadiusLG
BorderRadius.circular(8)   →  AppTheme.borderRadiusSM
```

### Text Styles
```dart
// Before
TextStyle(fontSize: 28, fontWeight: FontWeight.bold)  →  AppTheme.textStyleHeadline2
TextStyle(fontSize: 18, fontWeight: FontWeight.bold)   →  AppTheme.textStyleTitle
TextStyle(fontSize: 16)                                →  AppTheme.textStyleBodyLarge
TextStyle(fontSize: 12)                                →  AppTheme.textStyleCaption
```

### Elevations
```dart
// Before
elevation: 1  →  AppTheme.elevationLow
elevation: 2  →  AppTheme.elevationMedium
elevation: 3  →  AppTheme.elevationHigh
elevation: 4  →  AppTheme.elevationXHigh
```

---

## Notes

- All screens should import: `import 'package:aeyes_user_app/theme/app_theme.dart';`
- Test each screen after refactoring to ensure visual consistency
- Consider creating a refactoring branch for easier review
- Some screens may have conditional styling (dark mode) - ensure these work correctly

