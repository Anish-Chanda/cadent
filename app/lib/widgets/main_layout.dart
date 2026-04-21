import 'package:cadent/screens/recorder_screen.dart';
import 'package:cadent/screens/training_plans_screen.dart';
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_size.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    TrainingPlansScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onRecordTapped() {
    // navigate to recorder screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecorderScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      floatingActionButton: SizedBox(
        width: AppSpacing.massive,
        height: AppSpacing.massive,
        child: FloatingActionButton(
          onPressed: _onRecordTapped,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: const CircleBorder(),
          child: Icon(Icons.add, size: AppSpacing.iconLG),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomAppBar(
        child: SizedBox(
          height: AppSpacing.massive,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildNavItem(
                  icon: Icons.home,
                  label: 'Home',
                  index: 0,
                  isSelected: _selectedIndex == 0,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.event_note,
                  label: 'Plans',
                  index: 1,
                  isSelected: _selectedIndex == 1,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  index: 2,
                  isSelected: _selectedIndex == 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: AppSpacing.paddingVerticalXS,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              size: AppSpacing.iconSM,
            ),
            AppSpacing.gapXXS,
            Text(
              label,
              style: TextStyle(
                fontSize: AppTextSize.xs,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                fontWeight: isSelected
                    ? AppTextSize.semiBold
                    : AppTextSize.regular,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
