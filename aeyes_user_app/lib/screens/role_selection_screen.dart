import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Role')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Who are you?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.person, size: 32),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                  child: Text('User', style: TextStyle(fontSize: 22)),
                ),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.shield, size: 32),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                  child: Text('Guardian', style: TextStyle(fontSize: 22)),
                ),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
                onPressed: () => Navigator.pushReplacementNamed(context, '/guardian_login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 