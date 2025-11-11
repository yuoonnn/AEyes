import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  const MainScaffold({Key? key, required this.child, required this.currentIndex}) : super(key: key);

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/analysis');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/bluetooth');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    // Use shifting type on smaller screens to prevent overflow, fixed on larger screens
    final useShifting = screenWidth < 360;
    
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => _onTabTapped(context, i),
        type: useShifting ? BottomNavigationBarType.shifting : BottomNavigationBarType.fixed,
        backgroundColor: useShifting 
            ? null 
            : (isDark ? AppTheme.surfaceDark : AppTheme.backgroundLight),
        selectedItemColor: isDark ? AppTheme.accentGreen : AppTheme.primaryGreen,
        unselectedItemColor: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
        selectedLabelStyle: TextStyle(
          fontSize: AppTheme.fontSizeSM,
          fontWeight: AppTheme.fontWeightMedium,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: AppTheme.fontSizeSM,
          fontWeight: AppTheme.fontWeightRegular,
        ),
        elevation: AppTheme.elevationHigh,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: 'Home',
            backgroundColor: useShifting ? AppTheme.primaryGreen : null,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.analytics_outlined),
            label: 'AI',
            backgroundColor: useShifting ? AppTheme.primaryGreen : null,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bluetooth),
            label: 'Bluetooth',
            backgroundColor: useShifting ? AppTheme.primaryGreen : null,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: 'Profile',
            backgroundColor: useShifting ? AppTheme.primaryGreen : null,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: 'Settings',
            backgroundColor: useShifting ? AppTheme.primaryGreen : null,
          ),
        ],
      ),
    );
  }
} 