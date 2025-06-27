import 'package:flutter/material.dart';

class GuardianDashboardScreen extends StatelessWidget {
  const GuardianDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text('Welcome, Guardian!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          // User Monitoring
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.visibility, size: 36, color: Colors.blue),
              title: const Text('User Monitoring'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SizedBox(height: 4),
                  Text('Status: Online'),
                  Text('Last activity: 2 min ago'),
                  Text('Last OpenAI response: "A person wearing smart glasses, standing outdoors."'),
                ],
              ),
              isThreeLine: true,
              onTap: () {},
            ),
          ),
          const SizedBox(height: 20),
          // Location Tracking
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.location_on, size: 36, color: Colors.red),
              title: const Text('Location Tracking'),
              subtitle: const Text('Current location: 123 Main St, City (mock)'),
              trailing: IconButton(
                icon: const Icon(Icons.map),
                onPressed: () {}, // To be implemented: show map
              ),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 20),
          // Notifications & Alerts
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: const Icon(Icons.warning, size: 36, color: Colors.orange),
              title: const Text('Notifications & Alerts'),
              children: [
                ListTile(
                  leading: const Icon(Icons.error, color: Colors.red),
                  title: const Text('Device disconnected'),
                  subtitle: const Text('5 min ago'),
                  trailing: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () {}, // Acknowledge
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info, color: Colors.blue),
                  title: const Text('Low battery'),
                  subtitle: const Text('10 min ago'),
                  trailing: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Settings & Permissions
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: const Icon(Icons.settings, size: 36, color: Colors.deepPurple),
              title: const Text('Settings & Permissions'),
              children: [
                SwitchListTile(
                  title: const Text('User Notifications'),
                  value: true,
                  onChanged: (val) {},
                ),
                ListTile(
                  title: const Text('Master Volume'),
                  subtitle: Slider(
                    value: 0.7,
                    min: 0,
                    max: 1,
                    divisions: 10,
                    label: '70',
                    onChanged: (val) {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Accessibility/Safety Features
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: const Icon(Icons.accessibility_new, size: 36, color: Colors.green),
              title: const Text('Accessibility & Safety'),
              children: [
                SwitchListTile(
                  title: const Text('Enable Safety Mode'),
                  value: false,
                  onChanged: (val) {},
                ),
                SwitchListTile(
                  title: const Text('Bone Conduction Alerts'),
                  value: true,
                  onChanged: (val) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Communication
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.message, size: 36, color: Colors.teal),
              title: const Text('Communication'),
              subtitle: const Text('Send a message or alert to the user.'),
              trailing: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {}, // To be implemented: send message
              ),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person),
              label: const Text('Log in as User'),
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
            ),
          ),
        ],
      ),
    );
  }
} 