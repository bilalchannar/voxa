import 'package:flutter/material.dart';

import '../../core/services/settings_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/firebase_error_mapper.dart';
import '../../models/app_settings.dart';
import '../../widgets/settings/settings_widgets.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  final SettingsService _settingsService = SettingsService();

  static const List<int> _wallpaperSwatches = <int>[
    0,
    0xFFD9FDD3,
    0xFFF7EFE6,
    0xFFDDE9F3,
    0xFFE7E0F0,
    0xFFF4E1E6,
    0xFF2A3942,
  ];

  Future<void> _save(ChatSettings next) async {
    try {
      await _settingsService.saveChats(next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(FirebaseErrorMapper.message(e, context: 'saveChats')),
          ),
        );
    }
  }

  Future<void> _editFontSize(ChatSettings s) async {
    final selected = await showModalBottomSheet<ChatFontSize>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Font size',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              for (final option in ChatFontSize.values)
                ListTile(
                  leading: Icon(
                    option == s.fontSize
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: option == s.fontSize
                        ? AppColors.secondary
                        : AppColors.secondaryText,
                  ),
                  title: Text(
                    option.label,
                    style: TextStyle(fontSize: option.fontSize),
                  ),
                  onTap: () => Navigator.pop(ctx, option),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null && selected != s.fontSize) {
      _save(s.copyWith(fontSize: selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: StreamBuilder<ChatSettings>(
        stream: _settingsService.chatsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CenteredMessage(
              icon: Icons.cloud_off,
              message: FirebaseErrorMapper.message(
                snapshot.error!,
                context: 'chatsStream',
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
              _ChatPreview(settings: s),
              const SettingsSection(header: 'DISPLAY', children: []),
              SettingsTile(
                icon: Icons.format_size,
                title: 'Font size',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.fontSize.label,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 22),
                  ],
                ),
                onTap: () => _editFontSize(s),
              ),
              const SettingsDivider(indent: 56),
              _WallpaperTile(
                selected: s.wallpaperColor,
                swatches: _wallpaperSwatches,
                onSelected: (color) => _save(s.copyWith(wallpaperColor: color)),
              ),
              const SettingsSection(header: 'BEHAVIOR', children: []),
              SettingsSwitchTile(
                icon: Icons.keyboard_return,
                title: 'Enter key sends',
                subtitle: 'Pressing enter sends your message',
                value: s.enterKeySends,
                onChanged: (v) => _save(s.copyWith(enterKeySends: v)),
              ),
              const SettingsDivider(indent: 56),
              SettingsSwitchTile(
                icon: Icons.perm_media_outlined,
                title: 'Media visibility',
                subtitle: "Show new media in your device's gallery",
                value: s.mediaVisibility,
                onChanged: (v) => _save(s.copyWith(mediaVisibility: v)),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _ChatPreview extends StatelessWidget {
  final ChatSettings settings;
  const _ChatPreview({required this.settings});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallpaper = settings.wallpaperColor == 0
        ? (isDark ? AppColors.darkBackground : AppColors.lightSectionBackground)
        : Color(settings.wallpaperColor);

    final wallpaperIsDark = wallpaper.computeLuminance() < 0.5;
    final incomingBubble = wallpaperIsDark
        ? AppColors.darkElevated
        : Colors.white;
    final incomingText = wallpaperIsDark ? Colors.white : AppColors.primaryText;
    final outgoingBubble = isDark
        ? AppColors.secondary
        : const Color(0xFFDCF8C6);
    final outgoingText = isDark ? Colors.white : AppColors.primaryText;

    final fontSize = settings.fontSize.fontSize;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: wallpaper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _Bubble(
              text: 'How does this look?',
              color: incomingBubble,
              textColor: incomingText,
              fontSize: fontSize,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _Bubble(
              text: 'Looks great on Voxa!',
              color: outgoingBubble,
              textColor: outgoingText,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final double fontSize;

  const _Bubble({
    required this.text,
    required this.color,
    required this.textColor,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: fontSize),
      ),
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  final int selected;
  final List<int> swatches;
  final ValueChanged<int> onSelected;

  const _WallpaperTile({
    required this.selected,
    required this.swatches,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wallpaper_outlined,
                color: AppColors.secondaryText,
              ),
              const SizedBox(width: 16),
              Text(
                'Chat wallpaper',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final swatch in swatches)
                _Swatch(
                  color: swatch,
                  isSelected: swatch == selected,
                  onTap: () => onSelected(swatch),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final int color;
  final bool isSelected;
  final VoidCallback onTap;

  const _Swatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDefault = color == 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDefault ? Colors.transparent : Color(color),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.secondary : AppColors.divider,
            width: isSelected ? 3 : 1.5,
          ),
        ),
        child: isDefault
            ? const Icon(Icons.block, size: 20, color: AppColors.secondaryText)
            : (isSelected
                  ? const Icon(Icons.check, size: 20, color: AppColors.primary)
                  : null),
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
