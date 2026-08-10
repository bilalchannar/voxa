import 'package:flutter/material.dart';

import '../../core/services/settings_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/firebase_error_mapper.dart';
import '../../models/app_settings.dart';
import '../../widgets/settings/settings_widgets.dart';

class StorageDataScreen extends StatefulWidget {
  const StorageDataScreen({super.key});

  @override
  State<StorageDataScreen> createState() => _StorageDataScreenState();
}

class _StorageDataScreenState extends State<StorageDataScreen> {
  final SettingsService _settingsService = SettingsService();

  Future<void> _save(StorageSettings next) async {
    try {
      await _settingsService.saveStorage(next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              FirebaseErrorMapper.message(e, context: 'saveStorage'),
            ),
          ),
        );
    }
  }

  Future<void> _editPolicy({
    required String title,
    required AutoDownloadPolicy current,
    required ValueChanged<AutoDownloadPolicy> onSelected,
  }) async {
    final selected = await showModalBottomSheet<AutoDownloadPolicy>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              for (final option in AutoDownloadPolicy.values)
                ListTile(
                  leading: Icon(
                    option == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: option == current
                        ? AppColors.secondary
                        : AppColors.secondaryText,
                  ),
                  title: Text(option.label),
                  onTap: () => Navigator.pop(ctx, option),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null && selected != current) onSelected(selected);
  }

  Widget _policyTrailing(AutoDownloadPolicy value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value.label,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
          ),
        ),
        const Icon(Icons.chevron_right, size: 22),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage and Data')),
      body: StreamBuilder<StorageSettings>(
        stream: _settingsService.storageStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CenteredMessage(
              icon: Icons.cloud_off,
              message: FirebaseErrorMapper.message(
                snapshot.error!,
                context: 'storageStream',
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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  'Choose when media should download automatically. Your '
                  'choices are saved to your account.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SettingsSection(
                header: 'MEDIA AUTO-DOWNLOAD',
                children: [],
              ),
              SettingsTile(
                icon: Icons.photo_outlined,
                title: 'Photos',
                trailing: _policyTrailing(s.photos),
                onTap: () => _editPolicy(
                  title: 'Auto-download photos',
                  current: s.photos,
                  onSelected: (p) => _save(s.copyWith(photos: p)),
                ),
              ),
              const SettingsDivider(indent: 56),
              SettingsTile(
                icon: Icons.audiotrack_outlined,
                title: 'Audio',
                trailing: _policyTrailing(s.audio),
                onTap: () => _editPolicy(
                  title: 'Auto-download audio',
                  current: s.audio,
                  onSelected: (p) => _save(s.copyWith(audio: p)),
                ),
              ),
              const SettingsDivider(indent: 56),
              SettingsTile(
                icon: Icons.videocam_outlined,
                title: 'Video',
                trailing: _policyTrailing(s.video),
                onTap: () => _editPolicy(
                  title: 'Auto-download video',
                  current: s.video,
                  onSelected: (p) => _save(s.copyWith(video: p)),
                ),
              ),
              const SettingsDivider(indent: 56),
              SettingsTile(
                icon: Icons.insert_drive_file_outlined,
                title: 'Documents',
                trailing: _policyTrailing(s.documents),
                onTap: () => _editPolicy(
                  title: 'Auto-download documents',
                  current: s.documents,
                  onSelected: (p) => _save(s.copyWith(documents: p)),
                ),
              ),
              const SettingsSection(header: 'CALLS', children: []),
              SettingsSwitchTile(
                icon: Icons.data_saver_off_outlined,
                title: 'Use less data for calls',
                subtitle: 'Reduce data usage during Voxa calls',
                value: s.useLessDataForCalls,
                onChanged: (v) => _save(s.copyWith(useLessDataForCalls: v)),
              ),
              const SizedBox(height: 24),
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
