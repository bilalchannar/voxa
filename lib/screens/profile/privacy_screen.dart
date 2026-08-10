import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/firebase_error_mapper.dart';
import '../../models/user_profile.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/settings/settings_widgets.dart';

enum PrivacyVisibility {
  everyone,
  contacts,
  nobody;

  String get label {
    switch (this) {
      case PrivacyVisibility.everyone:
        return 'Everyone';
      case PrivacyVisibility.contacts:
        return 'My Contacts';
      case PrivacyVisibility.nobody:
        return 'Nobody';
    }
  }

  static PrivacyVisibility fromString(String? value) {
    return PrivacyVisibility.values.firstWhere(
      (v) => v.name == value,
      orElse: () => PrivacyVisibility.everyone,
    );
  }
}

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final ProfileViewModel _viewModel = ProfileViewModel();
  String? _savingField;

  Future<void> _edit({
    required String field,
    required String title,
    required PrivacyVisibility current,
  }) async {
    final selected = await showModalBottomSheet<PrivacyVisibility>(
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
              for (final option in PrivacyVisibility.values)
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

    if (selected == null || selected == current) return;

    setState(() => _savingField = field);
    try {
      await _viewModel.updatePrivacy(field, selected.name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              FirebaseErrorMapper.message(e, context: 'updatePrivacy'),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _savingField = null);
    }
  }

  Widget _trailingFor(String field, PrivacyVisibility value) {
    if (_savingField == field) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.label,
          style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
        ),
        const Icon(Icons.chevron_right, size: 22),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: StreamBuilder<UserProfile?>(
        stream: _viewModel.profileStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CenteredMessage(
              icon: Icons.cloud_off,
              message: FirebaseErrorMapper.message(
                snapshot.error!,
                context: 'privacyStream',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            );
          }

          final privacyMap = snapshot.data!.privacy;
          final lastSeen = PrivacyVisibility.fromString(
            privacyMap['lastSeen'] as String?,
          );
          final profilePhoto = PrivacyVisibility.fromString(
            privacyMap['profilePhoto'] as String?,
          );
          final about = PrivacyVisibility.fromString(
            privacyMap['about'] as String?,
          );
          final onlineStatus = PrivacyVisibility.fromString(
            privacyMap['onlineStatus'] as String?,
          );

          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  'Choose who can see your information. These preferences are '
                  'saved to your account.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SettingsTile(
                icon: Icons.access_time,
                title: 'Last Seen',
                trailing: _trailingFor('lastSeen', lastSeen),
                onTap: () => _edit(
                  field: 'lastSeen',
                  title: 'Who can see my last seen',
                  current: lastSeen,
                ),
              ),
              const SettingsDivider(indent: 56),
              SettingsTile(
                icon: Icons.account_circle_outlined,
                title: 'Profile Photo',
                trailing: _trailingFor('profilePhoto', profilePhoto),
                onTap: () => _edit(
                  field: 'profilePhoto',
                  title: 'Who can see my profile photo',
                  current: profilePhoto,
                ),
              ),
              const SettingsDivider(indent: 56),
              SettingsTile(
                icon: Icons.info_outline,
                title: 'About',
                trailing: _trailingFor('about', about),
                onTap: () => _edit(
                  field: 'about',
                  title: 'Who can see my about',
                  current: about,
                ),
              ),
              const SettingsDivider(indent: 56),
              SettingsTile(
                icon: Icons.circle,
                iconColor: AppColors.accent,
                title: 'Online Status',
                trailing: _trailingFor('onlineStatus', onlineStatus),
                onTap: () => _edit(
                  field: 'onlineStatus',
                  title: 'Who can see when I am online',
                  current: onlineStatus,
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
