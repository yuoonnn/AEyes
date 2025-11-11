import 'package:flutter/material.dart';

/// AEyes User App - Professional Design System
/// 
/// A comprehensive, scalable theme system following Material 3 specifications
/// with enhanced accessibility, responsive design, and developer experience.
class AppTheme {
  // Prevent instantiation and extension
  AppTheme._();

  // ============================================================================
  // DESIGN TOKENS - FOUNDATIONAL SYSTEM
  // ============================================================================

  /// Base design unit (4px grid system)
  static const double _baseUnit = 4.0;

  // ============================================================================
  // COLOR SYSTEM - Material 3 Compliant
  // ============================================================================

  /// Primary brand color palette (Pampanga State Agricultural University)
  static const Color _primaryBase = Color(0xFF388E3C);
  static const Color _onPrimaryBase = Color(0xFFFFFFFF);
  
  static const MaterialColor primaryPalette = MaterialColor(0xFF388E3C, {
    50: Color(0xFFE8F5E8),
    100: Color(0xFFC8E6C9),
    200: Color(0xFFA5D6A7),
    300: Color(0xFF81C784),
    400: Color(0xFF66BB6A),
    500: _primaryBase,
    600: Color(0xFF338033),
    700: Color(0xFF2E7D32),
    800: Color(0xFF286C2B),
    900: Color(0xFF1B5E20),
  });

  /// Secondary/Accent palette
  static const MaterialColor secondaryPalette = MaterialColor(0xFF2196F3, {
    50: Color(0xFFE3F2FD),
    100: Color(0xFFBBDEFB),
    200: Color(0xFF90CAF9),
    300: Color(0xFF64B5F6),
    400: Color(0xFF42A5F5),
    500: Color(0xFF2196F3),
    600: Color(0xFF1E88E5),
    700: Color(0xFF1976D2),
    800: Color(0xFF1565C0),
    900: Color(0xFF0D47A1),
  });

  /// Neutral palette for surfaces, backgrounds, and text
  static const MaterialColor neutralPalette = MaterialColor(0xFF747775, {
    0: Color(0xFFFFFFFF),
    10: Color(0xFFF5F5F5),
    50: Color(0xFFF8F9FA),
    100: Color(0xFFE9ECEF),
    200: Color(0xFFDEE2E6),
    300: Color(0xFFCED4DA),
    400: Color(0xFFADB5BD),
    500: Color(0xFF6C757D),
    600: Color(0xFF495057),
    700: Color(0xFF343A40),
    800: Color(0xFF212529),
    900: Color(0xFF121212),
    1000: Color(0xFF000000),
  });

  /// Semantic colors with accessibility contrast
  static const Color _success = Color(0xFF4CAF50);
  static const Color _onSuccess = Color(0xFFFFFFFF);
  static const Color _warning = Color(0xFFFF9800);
  static const Color _onWarning = Color(0xFF000000);
  static const Color _error = Color(0xFFE53935);
  static const Color _onError = Color(0xFFFFFFFF);
  static const Color _info = Color(0xFF2196F3);
  static const Color _onInfo = Color(0xFFFFFFFF);
  
  // Public accessors for semantic colors (backward compatibility)
  static const Color success = _success;
  static const Color warning = _warning;
  static const Color error = _error;
  static const Color info = _info;
  
  // Public accessors for primary colors (backward compatibility)
  static const Color primaryGreen = _primaryBase;
  static Color get accentGreen => primaryPalette.shade400; // 0xFF66BB6A

  // ============================================================================
  // SPACING SYSTEM - 8px Grid with 4px increments
  // ============================================================================

  /// Spacing scale following 8px grid with 4px increments
  static const double spacingNone = 0.0;
  static const double spacingXXS = _baseUnit * 1; // 4px
  static const double spacingXS = _baseUnit * 2;  // 8px
  static const double spacingSM = _baseUnit * 3;  // 12px
  static const double spacingMD = _baseUnit * 4;  // 16px
  static const double spacingLG = _baseUnit * 6;  // 24px
  static const double spacingXL = _baseUnit * 8;  // 32px
  static const double spacingXXL = _baseUnit * 12; // 48px
  static const double spacingXXXL = _baseUnit * 16; // 64px

  /// Predefined padding constants for consistent layout
  static const EdgeInsets paddingNone = EdgeInsets.zero;
  static const EdgeInsets paddingXS = EdgeInsets.all(spacingXS);
  static const EdgeInsets paddingSM = EdgeInsets.all(spacingSM);
  static const EdgeInsets paddingMD = EdgeInsets.all(spacingMD);
  static const EdgeInsets paddingLG = EdgeInsets.all(spacingLG);
  static const EdgeInsets paddingXL = EdgeInsets.all(spacingXL);

  /// Responsive padding variants
  static const EdgeInsets paddingHorizontalSM = EdgeInsets.symmetric(horizontal: spacingSM);
  static const EdgeInsets paddingHorizontalMD = EdgeInsets.symmetric(horizontal: spacingMD);
  static const EdgeInsets paddingHorizontalLG = EdgeInsets.symmetric(horizontal: spacingLG);
  
  static const EdgeInsets paddingVerticalSM = EdgeInsets.symmetric(vertical: spacingSM);
  static const EdgeInsets paddingVerticalMD = EdgeInsets.symmetric(vertical: spacingMD);
  static const EdgeInsets paddingVerticalLG = EdgeInsets.symmetric(vertical: spacingLG);

  // ============================================================================
  // BORDER RADIUS - Consistent corner styling
  // ============================================================================

  static const double radiusNone = 0.0;
  static const double radiusXS = _baseUnit * 1; // 4px
  static const double radiusSM = _baseUnit * 2; // 8px
  static const double radiusMD = _baseUnit * 3; // 12px
  static const double radiusLG = _baseUnit * 4; // 16px
  static const double radiusXL = _baseUnit * 6; // 24px
  static const double radiusRound = 9999.0; // Fully rounded

  /// Predefined BorderRadius objects
  static const BorderRadius borderRadiusNone = BorderRadius.zero;
  static const BorderRadius borderRadiusXS = BorderRadius.all(Radius.circular(radiusXS));
  static const BorderRadius borderRadiusSM = BorderRadius.all(Radius.circular(radiusSM));
  static const BorderRadius borderRadiusMD = BorderRadius.all(Radius.circular(radiusMD));
  static const BorderRadius borderRadiusLG = BorderRadius.all(Radius.circular(radiusLG));
  static const BorderRadius borderRadiusXL = BorderRadius.all(Radius.circular(radiusXL));
  static const BorderRadius borderRadiusRound = BorderRadius.all(Radius.circular(radiusRound));

  // ============================================================================
  // ELEVATION & SHADOWS - Material depth system
  // ============================================================================

  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
  static const double elevationXHigh = 16.0;

  /// Shadow system matching Material 3 specifications
  static List<BoxShadow> get shadowLow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 4.0,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get shadowMedium => [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 8.0,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowHigh => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 16.0,
      offset: const Offset(0, 4),
    ),
  ];

  // ============================================================================
  // TYPOGRAPHY SCALE - Material 3 Type Scale
  // ============================================================================

  static const String _fontFamily = 'Roboto';
  static const String _fontFamilyMono = 'RobotoMono';

  /// Font sizes following Material 3 type scale
  static const double _fontSizeScale = 1.125; // Major second scale

  static const double fontSizeXS = 12.0;
  static const double fontSizeSM = 14.0;
  static const double fontSizeMD = 16.0;
  static const double fontSizeLG = 18.0;
  static const double fontSizeXL = 20.0;
  static const double fontSizeXXL = 24.0;
  static const double fontSizeH3 = 28.0;
  static const double fontSizeH2 = 32.0;
  static const double fontSizeH1 = 36.0;
  static const double fontSizeDisplay = 40.0;

  /// Font weights with semantic names
  static const FontWeight fontWeightLight = FontWeight.w300;
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;

  /// Text styles following Material 3 typography system
  static const TextStyle _textBase = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: fontWeightRegular,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static TextStyle get displayLarge => _textBase.copyWith(
    fontSize: fontSizeDisplay,
    fontWeight: fontWeightBold,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle get displayMedium => _textBase.copyWith(
    fontSize: fontSizeH1,
    fontWeight: fontWeightBold,
    letterSpacing: -0.25,
    height: 1.3,
  );

  static TextStyle get displaySmall => _textBase.copyWith(
    fontSize: fontSizeH2,
    fontWeight: fontWeightSemiBold,
    letterSpacing: 0,
    height: 1.4,
  );

  static TextStyle get headlineMedium => _textBase.copyWith(
    fontSize: fontSizeH3,
    fontWeight: fontWeightSemiBold,
    letterSpacing: 0.15,
  );

  static TextStyle get titleLarge => _textBase.copyWith(
    fontSize: fontSizeXXL,
    fontWeight: fontWeightSemiBold,
    letterSpacing: 0.15,
  );

  static TextStyle get titleMedium => _textBase.copyWith(
    fontSize: fontSizeXL,
    fontWeight: fontWeightMedium,
    letterSpacing: 0.1,
  );

  static TextStyle get titleSmall => _textBase.copyWith(
    fontSize: fontSizeLG,
    fontWeight: fontWeightMedium,
    letterSpacing: 0.1,
  );

  static TextStyle get bodyLarge => _textBase.copyWith(
    fontSize: fontSizeLG,
    fontWeight: fontWeightRegular,
    letterSpacing: 0.25,
  );

  static TextStyle get bodyMedium => _textBase.copyWith(
    fontSize: fontSizeMD,
    fontWeight: fontWeightRegular,
    letterSpacing: 0.25,
  );

  static TextStyle get bodySmall => _textBase.copyWith(
    fontSize: fontSizeSM,
    fontWeight: fontWeightRegular,
    letterSpacing: 0.4,
  );

  static TextStyle get labelLarge => _textBase.copyWith(
    fontSize: fontSizeMD,
    fontWeight: fontWeightMedium,
    letterSpacing: 0.1,
  );

  static TextStyle get labelMedium => _textBase.copyWith(
    fontSize: fontSizeSM,
    fontWeight: fontWeightMedium,
    letterSpacing: 0.1,
  );

  static TextStyle get labelSmall => _textBase.copyWith(
    fontSize: fontSizeXS,
    fontWeight: fontWeightMedium,
    letterSpacing: 0.5,
  );
  
  // Backward compatibility aliases for text styles
  static TextStyle get textStyleHeadline1 => displayLarge;
  static TextStyle get textStyleHeadline2 => displaySmall;
  static TextStyle get textStyleHeadline3 => headlineMedium;
  static TextStyle get textStyleTitle => titleMedium;
  static TextStyle get textStyleSubtitle => titleSmall;
  static TextStyle get textStyleBody => bodyMedium;
  static TextStyle get textStyleBodyLarge => bodyLarge;
  static TextStyle get textStyleCaption => bodySmall;
  static TextStyle get textStyleOverline => labelSmall;

  // ============================================================================
  // ANIMATION & MOTION
  // ============================================================================

  static const Duration durationShort = Duration(milliseconds: 200);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationLong = Duration(milliseconds: 500);
  static const Curve standardEasing = Curves.easeInOut;
  static const Curve emphasizedEasing = Curves.easeOutBack;

  // ============================================================================
  // BREAKPOINTS - Responsive design
  // ============================================================================

  static const double breakpointMobile = 600.0;
  static const double breakpointTablet = 904.0;
  static const double breakpointDesktop = 1440.0;

  // ============================================================================
  // COMPONENT THEMES - Professional implementation
  // ============================================================================

  /// Elevated Button Styles
  static ButtonStyle get elevatedButtonPrimary => ElevatedButton.styleFrom(
    backgroundColor: primaryPalette,
    foregroundColor: _onPrimaryBase,
    elevation: elevationMedium,
    padding: const EdgeInsets.symmetric(horizontal: spacingLG, vertical: spacingMD),
    textStyle: labelLarge,
    shape: RoundedRectangleBorder(borderRadius: borderRadiusMD),
    shadowColor: Colors.transparent,
    enabledMouseCursor: SystemMouseCursors.click,
    disabledMouseCursor: SystemMouseCursors.forbidden,
    visualDensity: VisualDensity.standard,
    animationDuration: durationMedium,
  ).copyWith(
    elevation: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.pressed)) return elevationHigh;
      if (states.contains(MaterialState.hovered)) return elevationXHigh;
      return elevationMedium;
    }),
  );

  static ButtonStyle get elevatedButtonSecondary => ElevatedButton.styleFrom(
    backgroundColor: neutralPalette.shade50,
    foregroundColor: primaryPalette,
    elevation: elevationNone,
    padding: const EdgeInsets.symmetric(horizontal: spacingLG, vertical: spacingMD),
    textStyle: labelLarge,
    shape: RoundedRectangleBorder(
      borderRadius: borderRadiusMD,
      side: BorderSide(color: primaryPalette, width: 1.5),
    ),
  );

  /// Filled Button Styles
  static ButtonStyle get filledButtonTertiary => ElevatedButton.styleFrom(
    backgroundColor: primaryPalette.withOpacity(0.08),
    foregroundColor: primaryPalette,
    elevation: elevationNone,
    padding: const EdgeInsets.symmetric(horizontal: spacingLG, vertical: spacingMD),
    textStyle: labelLarge,
    shape: RoundedRectangleBorder(borderRadius: borderRadiusMD),
  );

  /// Text Button Styles
  static ButtonStyle get textButton => TextButton.styleFrom(
    foregroundColor: primaryPalette,
    padding: const EdgeInsets.symmetric(horizontal: spacingMD, vertical: spacingSM),
    textStyle: labelLarge,
    shape: RoundedRectangleBorder(borderRadius: borderRadiusMD),
  );

  /// Outlined Button Styles
  static ButtonStyle get outlinedButton => OutlinedButton.styleFrom(
    foregroundColor: primaryPalette,
    side: BorderSide(color: neutralPalette.shade300),
    padding: const EdgeInsets.symmetric(horizontal: spacingLG, vertical: spacingMD),
    textStyle: labelLarge,
    shape: RoundedRectangleBorder(borderRadius: borderRadiusMD),
  );

  // ============================================================================
  // CARD THEMING
  // ============================================================================

  static CardThemeData get cardTheme => CardThemeData(
    elevation: elevationLow,
    shape: RoundedRectangleBorder(borderRadius: borderRadiusLG),
    margin: const EdgeInsets.all(spacingMD),
    color: neutralPalette.shade50,
    shadowColor: Colors.black.withOpacity(0.1),
    surfaceTintColor: Colors.transparent,
  );

  static BoxDecoration get surfaceContainerLow => BoxDecoration(
    color: neutralPalette.shade50,
    borderRadius: borderRadiusLG,
    boxShadow: shadowLow,
  );

  static BoxDecoration get surfaceContainerHigh => BoxDecoration(
    color: neutralPalette.shade50,
    borderRadius: borderRadiusLG,
    boxShadow: shadowMedium,
  );

  // ============================================================================
  // INPUT DECORATION THEMING
  // ============================================================================

  static InputDecorationTheme get inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: neutralPalette.shade50,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: spacingMD,
      vertical: spacingMD,
    ),
    border: OutlineInputBorder(
      borderRadius: borderRadiusMD,
      borderSide: BorderSide(color: neutralPalette.shade300),
      gapPadding: 0,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadiusMD,
      borderSide: BorderSide(color: neutralPalette.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadiusMD,
      borderSide: BorderSide(color: primaryPalette, width: 2.0),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadiusMD,
      borderSide: BorderSide(color: _error, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: borderRadiusMD,
      borderSide: BorderSide(color: _error, width: 2.0),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: borderRadiusMD,
      borderSide: BorderSide(color: neutralPalette.shade200),
    ),
    errorStyle: bodySmall.copyWith(color: _error),
    helperStyle: bodySmall.copyWith(color: neutralPalette.shade500),
    hintStyle: bodyLarge.copyWith(color: neutralPalette.shade500),
    labelStyle: bodyLarge.copyWith(color: neutralPalette.shade600),
    floatingLabelStyle: bodySmall.copyWith(color: primaryPalette),
    prefixStyle: bodyLarge.copyWith(color: neutralPalette.shade600),
    suffixStyle: bodyLarge.copyWith(color: neutralPalette.shade600),
  );

  // ============================================================================
  // APP BAR THEMING
  // ============================================================================

  static AppBarTheme get appBarTheme => AppBarTheme(
    backgroundColor: primaryPalette,
    foregroundColor: _onPrimaryBase,
    elevation: elevationLow,
    centerTitle: false,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: titleLarge.copyWith(color: _onPrimaryBase),
    toolbarTextStyle: bodyLarge.copyWith(color: _onPrimaryBase),
    iconTheme: const IconThemeData(color: _onPrimaryBase),
    actionsIconTheme: const IconThemeData(color: _onPrimaryBase),
  );

  // ============================================================================
  // BOTTOM NAVIGATION BAR THEMING
  // ============================================================================

  static BottomNavigationBarThemeData get bottomNavigationBarTheme => BottomNavigationBarThemeData(
    backgroundColor: neutralPalette.shade50,
    selectedItemColor: primaryPalette,
    unselectedItemColor: neutralPalette.shade500,
    selectedLabelStyle: labelSmall,
    unselectedLabelStyle: labelSmall,
    type: BottomNavigationBarType.fixed,
    elevation: elevationMedium,
    showSelectedLabels: true,
    showUnselectedLabels: true,
    landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
  );

  // ============================================================================
  // DIALOG THEMING
  // ============================================================================

  static DialogThemeData get dialogTheme => DialogThemeData(
    backgroundColor: neutralPalette.shade50,
    surfaceTintColor: Colors.transparent,
    elevation: elevationHigh,
    shape: RoundedRectangleBorder(borderRadius: borderRadiusXL),
    alignment: Alignment.center,
    titleTextStyle: titleLarge,
    contentTextStyle: bodyMedium,
    iconColor: primaryPalette,
  );

  // ============================================================================
  // SNACKBAR THEMING
  // ============================================================================

  static SnackBarThemeData get snackBarTheme => SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: borderRadiusMD),
    backgroundColor: neutralPalette.shade800,
    actionTextColor: secondaryPalette,
    contentTextStyle: bodyMedium.copyWith(color: neutralPalette.shade50),
    elevation: elevationHigh,
    // Width removed - let it be responsive. If you need a max width, set it per-SnackBar
    showCloseIcon: true,
    closeIconColor: neutralPalette.shade50,
  );

  static SnackBarThemeData get snackBarThemeDark => SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: borderRadiusMD),
    backgroundColor: neutralPalette.shade700,
    actionTextColor: secondaryPalette.shade300,
    contentTextStyle: bodyMedium.copyWith(color: neutralPalette.shade50),
    elevation: elevationHigh,
    showCloseIcon: true,
    closeIconColor: neutralPalette.shade50,
  );

  // ============================================================================
  // THEME DATA CONFIGURATION
  // ============================================================================

  /// Light Theme Configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryPalette,
        onPrimary: _onPrimaryBase,
        secondary: secondaryPalette,
        onSecondary: _onPrimaryBase,
        error: _error,
        onError: _onError,
        background: neutralPalette.shade50,
        onBackground: neutralPalette.shade900,
        surface: neutralPalette.shade50,
        onSurface: neutralPalette.shade900,
        surfaceVariant: neutralPalette.shade100,
        onSurfaceVariant: neutralPalette.shade600,
        outline: neutralPalette.shade300,
        outlineVariant: neutralPalette.shade200,
      ),
      scaffoldBackgroundColor: neutralPalette.shade50,
      appBarTheme: appBarTheme,
      cardTheme: cardTheme,
      inputDecorationTheme: inputDecorationTheme,
      bottomNavigationBarTheme: bottomNavigationBarTheme,
      dialogTheme: dialogTheme,
      snackBarTheme: snackBarTheme,
      textTheme: TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineMedium: headlineMedium,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonPrimary),
      filledButtonTheme: FilledButtonThemeData(style: filledButtonTertiary),
      textButtonTheme: TextButtonThemeData(style: textButton),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButton),
      visualDensity: VisualDensity.standard,
      applyElevationOverlayColor: false,
    );
  }

  /// Dark Theme Configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryPalette,
        onPrimary: _onPrimaryBase,
        secondary: secondaryPalette,
        onSecondary: _onPrimaryBase,
        error: _error,
        onError: _onError,
        background: neutralPalette.shade900,
        onBackground: neutralPalette.shade50,
        surface: neutralPalette.shade800,
        onSurface: neutralPalette.shade50,
        surfaceVariant: neutralPalette.shade700,
        onSurfaceVariant: neutralPalette.shade300,
        outline: neutralPalette.shade600,
        outlineVariant: neutralPalette.shade700,
      ),
      scaffoldBackgroundColor: neutralPalette.shade900,
      appBarTheme: appBarTheme.copyWith(
        backgroundColor: neutralPalette.shade800,
      ),
      cardTheme: cardTheme.copyWith(
        color: neutralPalette.shade800,
      ),
      inputDecorationTheme: inputDecorationTheme.copyWith(
        fillColor: neutralPalette.shade800,
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadiusMD,
          borderSide: BorderSide(color: neutralPalette.shade600),
        ),
      ),
      bottomNavigationBarTheme: bottomNavigationBarTheme.copyWith(
        backgroundColor: neutralPalette.shade800,
        selectedItemColor: primaryPalette.shade300,
        unselectedItemColor: neutralPalette.shade400,
      ),
      dialogTheme: dialogTheme.copyWith(
        backgroundColor: neutralPalette.shade800,
      ),
      snackBarTheme: snackBarThemeDark,
      textTheme: TextTheme(
        displayLarge: displayLarge.copyWith(color: neutralPalette.shade50),
        displayMedium: displayMedium.copyWith(color: neutralPalette.shade50),
        displaySmall: displaySmall.copyWith(color: neutralPalette.shade50),
        headlineMedium: headlineMedium.copyWith(color: neutralPalette.shade50),
        titleLarge: titleLarge.copyWith(color: neutralPalette.shade50),
        titleMedium: titleMedium.copyWith(color: neutralPalette.shade50),
        titleSmall: titleSmall.copyWith(color: neutralPalette.shade50),
        bodyLarge: bodyLarge.copyWith(color: neutralPalette.shade50),
        bodyMedium: bodyMedium.copyWith(color: neutralPalette.shade50),
        bodySmall: bodySmall.copyWith(color: neutralPalette.shade300),
        labelLarge: labelLarge.copyWith(color: neutralPalette.shade50),
        labelMedium: labelMedium.copyWith(color: neutralPalette.shade50),
        labelSmall: labelSmall.copyWith(color: neutralPalette.shade300),
      ),
    );
  }

  // ============================================================================
  // PROFESSIONAL UTILITIES
  // ============================================================================

  /// Responsive layout helper
  static T responsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    
    if (width >= breakpointDesktop && desktop != null) return desktop;
    if (width >= breakpointTablet && tablet != null) return tablet;
    return mobile;
  }

  /// Status color mapping with proper contrast
  static Color getStatusColor(String status, [Brightness brightness = Brightness.light]) {
    final lowerStatus = status.toLowerCase();
    final isDark = brightness == Brightness.dark;
    
    if (lowerStatus.contains('connected') || lowerStatus.contains('active') || lowerStatus.contains('success')) {
      return isDark ? _success.withOpacity(0.8) : _success;
    } else if (lowerStatus.contains('scanning') || lowerStatus.contains('processing')) {
      return isDark ? _info.withOpacity(0.8) : _info;
    } else if (lowerStatus.contains('failed') || lowerStatus.contains('error') || lowerStatus.contains('disconnected')) {
      return isDark ? _error.withOpacity(0.8) : _error;
    } else if (lowerStatus.contains('warning')) {
      return isDark ? _warning.withOpacity(0.8) : _warning;
    }
    
    return isDark ? neutralPalette.shade400 : neutralPalette.shade500;
  }

  /// Elevation animation helper
  static double getElevation(Set<MaterialState> states) {
    if (states.contains(MaterialState.pressed)) return elevationHigh;
    if (states.contains(MaterialState.hovered)) return elevationXHigh;
    if (states.contains(MaterialState.focused)) return elevationMedium;
    return elevationLow;
  }

  /// Opacity utilities with semantic names
  static double get disabledOpacity => 0.38;
  static double get emphasisLow => 0.60;
  static double get emphasisMedium => 0.74;
  static double get emphasisHigh => 0.87;
  static double get emphasisFull => 1.0;

  /// Professional color with opacity
  static Color withEmphasis(Color color, double emphasis) {
    assert(emphasis >= 0.0 && emphasis <= 1.0, 'Emphasis must be between 0.0 and 1.0');
    return color.withOpacity(emphasis);
  }

  /// Accessibility text scale helper
  static double scaledFontSize(BuildContext context, double baseSize) {
    final scale = MediaQuery.of(context).textScaleFactor;
    return baseSize * scale.clamp(0.8, 2.0);
  }
  
  // ============================================================================
  // BACKWARD COMPATIBILITY - Additional properties
  // ============================================================================
  
  // Color aliases
  static Color get lightGreen => primaryPalette.shade200;
  static Color get darkGreen => primaryPalette.shade700;
  
  // Background colors
  static Color get backgroundLight => neutralPalette.shade50;
  static Color get backgroundDark => neutralPalette.shade900;
  static Color get surfaceLight => neutralPalette.shade50;
  static Color get surfaceDark => neutralPalette.shade800;
  
  // Text colors
  static Color get textPrimary => neutralPalette.shade900;
  static Color get textSecondary => neutralPalette.shade500;
  static Color get textDisabled => neutralPalette.shade400;
  static Color get textPrimaryDark => neutralPalette.shade50;
  static Color get textSecondaryDark => neutralPalette.shade300;
  
  // Border colors
  static Color get borderLight => neutralPalette.shade300;
  static Color get borderDark => neutralPalette.shade600;
  
  // Button styles (backward compatibility)
  static ButtonStyle get primaryButtonStyle => elevatedButtonPrimary;
  static ButtonStyle get secondaryButtonStyle => elevatedButtonSecondary;
  static ButtonStyle get accentButtonStyle => filledButtonTertiary;
  static ButtonStyle get textButtonStyle => textButton;
  
  // Helper methods
  static Color primaryWithOpacity(double opacity) {
    return primaryPalette.withOpacity(opacity);
  }
  
  static Color accentWithOpacity(double opacity) {
    return accentGreen.withOpacity(opacity);
  }
}