import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/firebase_error_mapper.dart';
import '../../models/user_profile.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/profile/profile_header.dart';
import '../../widgets/profile/profile_settings_tile.dart';
import '../../widgets/settings/settings_widgets.dart';
import '../auth/phone_number_screen.dart';
import 'appearance_screen.dart';
import 'change_phone_screen.dart';
import 'chat_settings_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_screen.dart';
import 'security_screen.dart';
import 'storage_data_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileViewModel _viewModel = ProfileViewModel();

  bool _ensureTriggered = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _ensureProfile();
  }

  Future<void> _ensureProfile() async {
    if (_ensureTriggered) return;
    _ensureTriggered = true;
    try {
      await _viewModel.ensureProfileExists();
    } catch (e) {
      debugPrint('[Voxa] ensureProfileExists failed: $e');
      _ensureTriggered = false;
    }
  }

  void _showPhotoOptions(UserProfile profile) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_circle_outlined,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Profile photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (profile.hasPhoto)
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: const Text('View photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _viewPhoto(profile.photoUrl!);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _changePhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _changePhoto(ImageSource.camera);
                },
              ),
              if (profile.hasPhoto)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                  title: const Text(
                    'Remove photo',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removePhoto();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _viewPhoto(String url) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _PhotoViewerScreen(url: url)));
  }

  Future<void> _changePhoto(ImageSource source) async {
    if (_isBusy) return;

    if (!_viewModel.isCloudinaryConfigured) {
      _showCloudinaryNotConfigured();
      return;
    }

    setState(() => _isBusy = true);
    _showBlockingProgress('Uploading photo…');
    try {
      final url = await _viewModel.uploadProfilePhoto(source);
      if (!mounted) return;
      _dismissBlockingProgress();
      if (url != null) {
        _snack('Profile photo updated.');
      }
    } catch (e) {
      if (!mounted) return;
      _dismissBlockingProgress();
      _snack(FirebaseErrorMapper.message(e, context: 'updatePhotoUrl'));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    if (_isBusy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove profile photo?'),
        content: const Text(
          'Your photo will be removed and replaced with your initial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isBusy = true);
    _showBlockingProgress('Removing photo…');
    try {
      final success = await _viewModel.removeProfilePhoto();
      if (!mounted) return;
      _dismissBlockingProgress();
      if (success) {
        _snack('Profile photo removed.');
      } else {
        _snack(_viewModel.errorMessage ?? 'Could not remove photo.');
      }
    } catch (e) {
      if (!mounted) return;
      _dismissBlockingProgress();
      _snack(FirebaseErrorMapper.message(e, context: 'removePhoto'));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showCloudinaryNotConfigured() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Photo upload not set up yet'),
        content: const Text(
          'Profile photos upload to Cloudinary, which has not been configured '
          'for this build yet.\n\n'
          'Add your Cloudinary cloud name and unsigned upload preset in '
          'lib/core/services/cloudinary_service.dart (CloudinaryConfig) to '
          'enable uploads. Everything else in your profile works normally.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    if (_isBusy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out of Voxa?'),
        content: const Text(
          'You will need to verify your phone number to log back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isBusy = true);
    _showBlockingProgress('Logging out…');
    try {
      await _viewModel.signOut();
      if (!mounted) return;
      _dismissBlockingProgress();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PhoneNumberScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _dismissBlockingProgress();
      setState(() => _isBusy = false);
      _snack(FirebaseErrorMapper.message(e, context: 'signOut'));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showBlockingProgress(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 18),
                Flexible(child: Text(message)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dismissBlockingProgress() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _viewModel.profileStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            message: FirebaseErrorMapper.message(
              snapshot.error!,
              context: 'profileStream',
            ),
            onRetry: () => setState(() {}),
          );
        }

        if (!snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.active &&
              snapshot.data == null) {
            _ensureProfile();
          }
          return const _LoadingState();
        }

        final profile = snapshot.data!;
        return _buildContent(profile);
      },
    );
  }

  Widget _buildContent(UserProfile profile) {
    final authPhone = _viewModel.authPhoneNumber;
    final phone = (authPhone != null && authPhone.isNotEmpty)
        ? authPhone
        : (profile.phoneNumber.isNotEmpty
              ? profile.phoneNumber
              : 'Number hidden');

    return RefreshIndicator(
      onRefresh: () async => _ensureProfile(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          ProfileHeader(
            profile: profile,
            phoneNumber: phone,
            onEditPhoto: _isBusy ? null : () => _showPhotoOptions(profile),
            onEditProfile: () =>
                _open(EditProfileScreen(initialProfile: profile)),
          ),
          const SizedBox(height: 8),
          SettingsSection(
            header: 'Account',
            children: [
              ProfileSettingsTile(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                subtitle: 'Name and about',
                onTap: () => _open(EditProfileScreen(initialProfile: profile)),
              ),
              const SettingsDivider(indent: 56),
              ProfileSettingsTile(
                icon: Icons.lock_outline,
                title: 'Privacy',
                subtitle: 'Last seen, photo, about, online status',
                onTap: () => _open(const PrivacyScreen()),
              ),
              const SettingsDivider(indent: 56),
              ProfileSettingsTile(
                icon: Icons.shield_outlined,
                title: 'Security',
                subtitle: 'Account and sign-in details',
                onTap: () => _open(const SecurityScreen()),
              ),
              const SettingsDivider(indent: 56),
              ProfileSettingsTile(
                icon: Icons.phone_iphone_outlined,
                title: 'Change Phone Number',
                subtitle: 'Move your account to a new number',
                onTap: () => _open(const ChangePhoneScreen()),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 8),
          SettingsSection(
            header: 'Settings',
            children: [
              ProfileSettingsTile(
                icon: Icons.notifications_none,
                title: 'Notifications',
                subtitle: 'Messages, calls, sound, vibration',
                onTap: () => _open(const NotificationSettingsScreen()),
              ),
              const SettingsDivider(indent: 56),
              ProfileSettingsTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: 'Theme',
                onTap: () => _open(const AppearanceScreen()),
              ),
              const SettingsDivider(indent: 56),
              ProfileSettingsTile(
                icon: Icons.chat_bubble_outline,
                title: 'Chats',
                subtitle: 'Enter key, media, font size, wallpaper',
                onTap: () => _open(const ChatSettingsScreen()),
              ),
              const SettingsDivider(indent: 56),
              ProfileSettingsTile(
                icon: Icons.data_usage_outlined,
                title: 'Storage & Data',
                subtitle: 'Auto-download and network use',
                onTap: () => _open(const StorageDataScreen()),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isBusy ? null : _confirmLogout,
                icon: const Icon(Icons.logout, color: AppColors.danger),
                label: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Voxa',
              style: TextStyle(
                color: AppColors.secondary.withValues(alpha: 0.8),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.secondary),
          SizedBox(height: 16),
          Text(
            'Loading your profile…',
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 56,
              color: AppColors.secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoViewerScreen extends StatelessWidget {
  final String url;
  const _PhotoViewerScreen({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Profile photo'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
            errorBuilder: (context, error, stack) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
                SizedBox(height: 12),
                Text(
                  'Could not load photo',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
