import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/app_settings.dart';
import '../utils/app_spacing.dart';
import '../utils/app_version.dart';

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
            padding: AppSpacing.paddingMD,
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.account_circle),
                  title: const Text('Account'),
                  subtitle: Text(
                    auth.email?.isNotEmpty == true ? auth.email! : 'Not signed in',
                  ),
                ),
              ),
              AppSpacing.gapMD,

              // Display Name Setting
              Consumer<AuthProvider>(
                builder: (context, auth, child) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.account_circle),
                      title: const Text('Display Name'),
                      subtitle: Text(
                        auth.name?.isNotEmpty == true 
                          ? auth.name! 
                          : "Loading...", // Show loading
                      ),
                      trailing: const Icon(Icons.edit), // optional edit icon
                      onTap: () async {
                        // Open dialog to enter new name
                        final newName = await showDialog<String>(
                          context: context,
                          builder: (context) {
                            String tempName = auth.name ?? '';
                            return AlertDialog(
                              title: const Text('Enter new display name'),
                              content: TextField(
                                autofocus: true,
                                decoration: const InputDecoration(hintText: 'New name'),
                                controller: TextEditingController(text: tempName),
                                onChanged: (value) {
                                  tempName = value;
                                },
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context), // cancel
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, tempName), // submit
                                  child: const Text('Save'),
                                ),
                              ],
                            );
                          },
                        );
                        // Update provider if a new name was entered
                        if (newName != null && newName.trim().isNotEmpty && newName.trim() != auth.name) {
                          final trimmedName = newName.trim();                          
                          final success = await auth.updateName(trimmedName);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? 'Name updated successfully' : 'Failed to update name'),
                                backgroundColor: success 
                                    ? Theme.of(context).colorScheme.primary 
                                    : Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              ),
              AppSpacing.gapMD,

              Card(
                child: ListTile(
                  leading: const Icon(Icons.dns),
                  title: const Text('Server URL'),
                  subtitle: Text(auth.serverUrl),
                ),
              ),
              AppSpacing.gapMD,

              // Theme Mode Setting
              Consumer<AppSettingsProvider>(
                builder: (context, settingsController, child) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.brightness_6),
                      title: const Text('Theme'),
                      subtitle: Text(
                        settingsController.themeModeDisplayName,
                      ),
                      trailing: Switch(
                        value: settingsController.isDarkMode,
                        onChanged: (value) {
                          settingsController.toggleThemeMode();
                        },
                      ),
                    ),
                  );
                },
              ),
              AppSpacing.gapMD,

              // Distance Unit Setting
              Consumer<AppSettingsProvider>(
                builder: (context, settingsController, child) {
                  return Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.straighten),
                          title: const Text('Distance Unit'),
                          subtitle: Text(
                            settingsController.metricUnitDisplayName,
                          ),
                        ),
                        RadioListTile<String>(
                          title: const Text('Meters'),
                          value: AppSettingsModel.metersUnit,
                          groupValue: settingsController.metricUnit,
                          onChanged: (String? value) {
                            if (value != null) {
                              settingsController.setMetricUnit(value);
                            }
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('Miles'),
                          value: AppSettingsModel.milesUnit,
                          groupValue: settingsController.metricUnit,
                          onChanged: (String? value) {
                            if (value != null) {
                              settingsController.setMetricUnit(value);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
             AppSpacing.gapMD,

              Consumer<AppSettingsProvider>(
                builder: (context, settingsController, child) {
                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                      title: Text(
                        'Sign Out',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                      onTap: () async {
                        try {
                          await auth.logout();
                          await settingsController.resetToDefaults();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error signing out: $e')),
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              // Version information
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    AppVersion.fullVersion,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
