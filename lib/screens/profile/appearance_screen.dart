import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/firebase_error_mapper.dart';
import '../../models/app_settings.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final ThemeController _controller = ThemeController.instance;
  bool _saving = false;

  Future<void> _select(ThemeMode mode) async {
    if (_saving || mode == _controller.themeMode) return;
    setState(() => _saving = true);
    try {
      await _controller.setThemeMode(mode);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Theme changed, but saving your preference failed: '
              '${FirebaseErrorMapper.message(e, context: 'saveThemeMode')}',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final current = _controller.themeMode;
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  'Choose how Voxa looks. "System default" follows your '
                  "device's light or dark setting.",
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              for (final mode in ThemeMode.values)
                ListTile(
                  leading: Icon(
                    _iconFor(mode),
                    color: mode == current
                        ? AppColors.secondary
                        : AppColors.secondaryText,
                  ),
                  title: Text(AppearanceSettings.themeModeLabel(mode)),
                  trailing: mode == current
                      ? const Icon(Icons.check, color: AppColors.secondary)
                      : null,
                  onTap: _saving ? null : () => _select(mode),
                ),
            ],
          );
        },
      ),
    );
  }

  IconData _iconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
    }
  }
}
