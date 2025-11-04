import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.account_circle),
                  title: const Text('Account'),
                  subtitle: Text(auth.email.isNotEmpty ? auth.email : 'Not signed in'),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.dns),
                  title: const Text('Server URL'),
                  subtitle: Text(auth.serverUrl),
                ),
              ),
              const SizedBox(height: 32),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    try {
                      await auth.logout();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error signing out: $e')),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}