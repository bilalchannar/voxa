import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class LinkedDevicesScreen extends StatelessWidget {
  const LinkedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linked devices'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.devices,
                    size: 80,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Use Voxa on other devices',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Link your account to Voxa Web or Desktop to send and receive messages from your computer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('QR Scanner ready. Scan code on web.voxa.com'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('LINK A DEVICE'),
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'YOUR DEVICES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone_android, color: AppColors.accent),
            title: const Text('Android (This device)'),
            subtitle: const Text('Active now'),
            trailing: const Text(
              'Online',
              style: TextStyle(color: AppColors.accent, fontSize: 12),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.laptop, color: AppColors.secondaryText),
            title: Text('Windows (Voxa Desktop)'),
            subtitle: Text('Last active yesterday at 4:30 PM'),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Your personal messages are end-to-end encrypted on all your linked devices.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
