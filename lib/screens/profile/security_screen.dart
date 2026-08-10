import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/firebase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/firebase_error_mapper.dart';
import '../../models/user_profile.dart';
import '../../widgets/settings/settings_widgets.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final local = date.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  String _providerLabel(User? user) {
    final providers =
        user?.providerData.map((p) => p.providerId).toList() ?? [];
    if (providers.contains('phone') || (user?.phoneNumber ?? '').isNotEmpty) {
      return 'Phone number';
    }
    if (providers.isEmpty) return 'Phone number';
    return providers.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    final user = FirebaseAuth.instance.currentUser;
    final phone = user?.phoneNumber;
    final uid = user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: StreamBuilder<UserProfile?>(
        stream: firebaseService.profileStream(),
        builder: (context, snapshot) {
          final createdAt = snapshot.data?.createdAt;

          return ListView(
            children: [
              const _SecurityBanner(),
              const SettingsSection(header: 'ACCOUNT', children: []),
              SettingsTile(
                icon: Icons.phone_outlined,
                title: 'Phone number',
                subtitle: (phone != null && phone.isNotEmpty)
                    ? phone
                    : 'Not available',
              ),
              const SettingsDivider(indent: 56),
              SettingsTile(
                icon: Icons.verified_user_outlined,
                title: 'Signed in with',
                subtitle: _providerLabel(user),
              ),
              const SettingsSection(header: 'DETAILS', children: []),
              SettingsTile(
                icon: Icons.tag,
                title: 'User ID',
                subtitle: uid.isEmpty ? 'Not available' : uid,
                trailing: uid.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Copy User ID',
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: uid));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(content: Text('User ID copied.')),
                            );
                        },
                      ),
              ),
              const SettingsDivider(indent: 56),
              SettingsTile(
                icon: Icons.event_outlined,
                title: 'Account created',
                subtitle: snapshot.hasError
                    ? FirebaseErrorMapper.message(
                        snapshot.error!,
                        context: 'securityStream',
                      )
                    : (snapshot.connectionState == ConnectionState.waiting
                          ? 'Loading…'
                          : _formatDate(createdAt)),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.secondary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Your account is secured by phone-number verification. Voxa never '
              'stores your password because sign-in uses a one-time SMS code.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
