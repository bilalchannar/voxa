import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:voxa/core/services/call_service.dart';
import 'package:voxa/core/services/firebase_service.dart';
import 'package:voxa/core/theme/app_colors.dart';
import 'package:voxa/core/theme/theme_controller.dart';
import 'package:voxa/models/call_model.dart';
import 'package:voxa/screens/call/call_screen.dart';
import 'package:voxa/screens/contacts/contacts_screen.dart';
import 'package:voxa/screens/group/create_group_screen.dart';
import 'package:voxa/screens/profile/profile_screen.dart';
import 'package:voxa/widgets/call/calls_view.dart';
import 'package:voxa/widgets/chat/chats_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription<List<CallModel>>? _incomingCallSub;
  String? _currentActiveCallId;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
    _listenToIncomingCalls();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
  }

  void _listenToIncomingCalls() {
    final uid = _firebaseService.currentUid;
    _incomingCallSub = CallService.instance.incomingCallsStream(uid).listen((
      calls,
    ) {
      if (!mounted || calls.isEmpty) return;

      final call = calls.first;
      if (_currentActiveCallId == call.callId) return;

      _currentActiveCallId = call.callId;
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => CallScreen(call: call, isIncoming: true),
            ),
          )
          .then((_) => _currentActiveCallId = null);
    });
  }

  Future<void> _bootstrap() async {
    try {
      await _firebaseService.ensureProfileExists();
    } catch (e) {
      debugPrint('[Voxa] ensureProfileExists on home failed: $e');
    }
    try {
      await ThemeController.instance.loadForCurrentUser();
    } catch (e) {
      debugPrint('[Voxa] loadForCurrentUser failed: $e');
    }
    _firebaseService.markInboundMessagesDelivered();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setPresence(true);
        _firebaseService.markInboundMessagesDelivered();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _setPresence(false);
        break;
    }
  }

  void _setPresence(bool isOnline) {
    try {
      _firebaseService.setOnline(isOnline);
    } catch (e) {
      debugPrint('[Voxa] presence error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingCallSub?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _setPresence(false);
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
  }

  Future<void> _openCamera() async {
    final picker = ImagePicker();
    try {
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null || !mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Photo Captured',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(photo.path),
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.send, color: AppColors.accent),
                  title: const Text('Send to contact'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContactsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_circle, color: AppColors.secondary),
                  title: const Text('Update Profile Photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[HomeScreen] camera error: $e');
    }
  }

  void _showBroadcastModal() {
    final broadcastController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.campaign_outlined, color: AppColors.accent, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'New Broadcast',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Only contacts with your number in their address book will receive your broadcast messages.',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: broadcastController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Type broadcast message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final text = broadcastController.text.trim();
                        if (text.isEmpty) return;
                        Navigator.pop(sheetContext);
                        try {
                          final users = await _firebaseService.getAllUsers();
                          for (final u in users) {
                            final chatId = await _firebaseService.createOrGetChat(u.uid);
                            await _firebaseService.sendMessage(
                              conversationId: chatId,
                              receiverId: u.uid,
                              content: '[Broadcast] $text',
                            );
                          }
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Broadcast message sent!')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Broadcast failed: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.send),
                      label: const Text('Send Broadcast'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLinkedDevicesModal() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.devices, size: 54, color: AppColors.secondary),
                const SizedBox(height: 12),
                const Text(
                  'Linked Devices',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use Voxa on Web, Desktop, and other devices without keeping your phone online.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 13.5),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.phone_android, color: AppColors.accent),
                  title: const Text('Primary Device (This Phone)'),
                  subtitle: const Text('Active now'),
                ),
                ListTile(
                  leading: const Icon(Icons.laptop, color: AppColors.secondaryText),
                  title: const Text('Voxa Web / Desktop'),
                  subtitle: const Text('Linked session ready'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Device pairing ready. Scan QR code to link.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Link a Device'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStarredMessagesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Starred Messages',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Column(
                    children: [
                      SizedBox(height: 20),
                      Icon(Icons.star_outline, size: 48, color: AppColors.secondaryText),
                      SizedBox(height: 12),
                      Text(
                        'Tap and hold on any message in a chat to star it for easy access later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.secondaryText, fontSize: 13.5),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ChatsView(searchQuery: _searchQuery),
      const Center(child: Text("Updates")),
      const Center(child: Text("Communities")),
      const CallsView(),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _stopSearch,
              )
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Search chats...',
                  border: InputBorder.none,
                ),
              )
            : const Text(
                "Voxa",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
        actions: _isSearching
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  onPressed: _openCamera,
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _startSearch,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'New group') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateGroupScreen(),
                        ),
                      );
                    } else if (value == 'New broadcast') {
                      _showBroadcastModal();
                    } else if (value == 'Linked devices') {
                      _showLinkedDevicesModal();
                    } else if (value == 'Starred messages') {
                      _showStarredMessagesModal();
                    } else if (value == 'Profile' || value == 'Settings') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'New group',
                      child: Text('New group'),
                    ),
                    const PopupMenuItem(
                      value: 'New broadcast',
                      child: Text('New broadcast'),
                    ),
                    const PopupMenuItem(
                      value: 'Linked devices',
                      child: Text('Linked devices'),
                    ),
                    const PopupMenuItem(
                      value: 'Starred messages',
                      child: Text('Starred messages'),
                    ),
                    const PopupMenuItem(
                      value: 'Profile',
                      child: Text('Profile'),
                    ),
                  ],
                ),
              ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: "Chats",
          ),
          NavigationDestination(
            icon: Icon(Icons.update_outlined),
            selectedIcon: Icon(Icons.update),
            label: "Updates",
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: "Communities",
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: "Calls",
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ContactsScreen()),
                );
              },
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.message, color: Colors.white),
            )
          : null,
    );
  }
}
