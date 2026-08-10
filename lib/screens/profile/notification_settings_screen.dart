import 'package:flutter/material.dart';

import '../../core/services/settings_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/firebase_error_mapper.dart';
import '../../models/app_settings.dart';
import '../../widgets/settings/settings_widgets.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final SettingsService _settingsService = SettingsService();

  Future<void> _save(NotificationSettings next) async {
    try {
      await _settingsService.saveNotifications(next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              FirebaseErrorMapper.message(e, context: 'saveNotifications'),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<NotificationSettings>(
        stream: _settingsService.notificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CenteredMessage(
              icon: Icons.cloud_off,
              message: FirebaseErrorMapper.message(
                snapshot.error!,
                context: 'notificationsStream',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            );
          }

          final s = snapshot.data!;
          return ListView(
            children: [
              const SettingsSection(header: 'MESSAGES', children: []),
              SettingsSwitchTile(
                icon: Icons.chat_bubble_outline,
                title: 'Message notifications',
                subtitle: 'Show alerts for new messages',
                value: s.messageNotifications,
                onChanged: (v) => _save(s.copyWith(messageNotifications: v)),
              ),
              const SettingsDivider(indent: 56),
              SettingsSwitchTile(
                icon: Icons.call_outlined,
                title: 'Call notifications',
                subtitle: 'Show alerts for incoming calls',
                value: s.callNotifications,
                onChanged: (v) => _save(s.copyWith(callNotifications: v)),
              ),
              const SettingsSection(header: 'ALERTS', children: []),
              SettingsSwitchTile(
                icon: Icons.volume_up_outlined,
                title: 'Sound',
                subtitle: 'Play a sound for notifications',
                value: s.sound,
                onChanged: (v) => _save(s.copyWith(sound: v)),
              ),
              const SettingsDivider(indent: 56),
              SettingsSwitchTile(
                icon: Icons.vibration,
                title: 'Vibration',
                subtitle: 'Vibrate for notifications',
                value: s.vibration,
                onChanged: (v) => _save(s.copyWith(vibration: v)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Text(
                  'These preferences are saved to your account. Delivering '
                  'push notifications also depends on your system permissions '
                  'for Voxa.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
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

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  const _CenteredMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.secondaryText),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
