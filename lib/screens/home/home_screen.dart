import 'dart:async';

import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
    _listenToIncomingCalls();
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
    _setPresence(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const ChatsView(),
      const Center(child: Text("Updates")),
      const Center(child: Text("Communities")),
      const CallsView(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Voxa",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () {},
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
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
              } else if (value == 'Profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'New group', child: Text('New group')),
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
              const PopupMenuItem(value: 'Profile', child: Text('Profile')),
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
