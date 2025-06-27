import 'package:flutter/material.dart';
import '../widgets/main_scaffold.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        _opacity = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF388E3C);
    final greenAccent = const Color(0xFF66BB6A);

    return MainScaffold(
      currentIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/AEye Logo.png',
                height: 32,
              ),
              const SizedBox(width: 12),
              const Text(
                'AEyes Dashboard',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
            ),
          ],
        ),
        body: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 800),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Here's your quick access dashboard.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: green.withOpacity(0.08),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: greenAccent,
                      child: const Icon(Icons.account_circle, size: 32, color: Colors.white),
                    ),
                    title: const Text(
                      'Your Name',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: const Text('your@email.com'),
                    trailing: IconButton(
                      icon: Icon(Icons.edit, color: green),
                      onPressed: () => Navigator.pushNamed(context, '/profile'),
                      tooltip: 'Edit Profile',
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _AnimatedQuickActionCard(
                        icon: Icons.bluetooth,
                        label: 'Bluetooth',
                        color: green,
                        onTap: () => Navigator.pushNamed(context, '/bluetooth'),
                      ),
                      _AnimatedQuickActionCard(
                        icon: Icons.settings,
                        label: 'Settings',
                        color: greenAccent,
                        onTap: () => Navigator.pushNamed(context, '/settings'),
                      ),
                      _AnimatedQuickActionCard(
                        icon: Icons.person,
                        label: 'Profile',
                        color: green,
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                      ),
                      _AnimatedQuickActionCard(
                        icon: Icons.image,
                        label: 'OpenAI',
                        color: greenAccent,
                        onTap: () {}, // Placeholder for OpenAI feature
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedQuickActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedQuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  State<_AnimatedQuickActionCard> createState() => _AnimatedQuickActionCardState();
}

class _AnimatedQuickActionCardState extends State<_AnimatedQuickActionCard> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.95;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
    });
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Card(
          color: widget.color.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 40, color: widget.color),
                const SizedBox(height: 12),
                Text(
                  widget.label,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 