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
import 'package:voxa/screens/profile/linked_devices_screen.dart';
import 'package:voxa/screens/chat/starred_messages_screen.dart';
import 'package:voxa/screens/contacts/contacts_screen.dart';
import 'package:voxa/screens/group/create_group_screen.dart';
import 'package:voxa/screens/profile/profile_screen.dart';
import 'package:voxa/widgets/call/calls_view.dart';
import 'package:voxa/widgets/chat/chats_view.dart';
import 'package:voxa/widgets/status/status_view.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/status_service.dart';
import '../../core/utils/voxa_snackbar.dart';

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
        builder: (sheetContext) => SingleChildScrollView(
          child: SafeArea(
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
            child: SingleChildScrollView(
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
          ),
        );
      },
    );
  }

  void _showLinkedDevicesModal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LinkedDevicesScreen()),
    );
  }

  void _showStarredMessagesModal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StarredMessagesScreen()),
    );
  }

  Future<void> _pickAndUploadStatus({bool isVideo = false}) async {
    final picker = ImagePicker();
    XFile? file;
    if (isVideo) {
      file = await picker.pickVideo(source: ImageSource.gallery);
    } else {
      file = await picker.pickImage(source: ImageSource.gallery);
    }

    if (file == null) return;
    if (!mounted) return;
    _showStatusConfirmDialog(File(file.path), isVideo ? 'video' : 'image');
  }

  void _showStatusConfirmDialog(File file, String type) {
    final captionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Post ${type == 'video' ? 'Video' : 'Image'} Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'image')
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(file, height: 200, fit: BoxFit.cover),
              )
            else
              const Icon(Icons.videocam, size: 64, color: AppColors.secondary),
            TextField(
              controller: captionController,
              decoration: const InputDecoration(hintText: 'Add a caption...'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _handleStatusUpload(file, captionController.text.trim(), type);
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStatusUpload(File file, String caption, String type) async {
    try {
      VoxaSnackBar.show(
        context,
        message: 'Uploading status...',
        icon: Icons.cloud_upload_outlined,
      );

      final imageUrl = await const CloudinaryService().uploadMediaFile(
        file: file,
        resourceType: type,
      );

      final user = await _firebaseService.getUserProfile();
      if (user == null) return;

      final privacy = user.privacy['status'] as String? ?? 'everyone';

      await StatusService.instance.uploadStatus(
        imageUrl: imageUrl,
        caption: caption,
        displayName: user.displayName,
        profilePhoto: user.photoUrl,
        type: type,
        privacy: privacy,
      );

      if (!mounted) return;
      VoxaSnackBar.success(context, 'Status uploaded!');
    } catch (e) {
      if (!mounted) return;
      VoxaSnackBar.error(context, 'Failed to upload status.');
    }
  }

  void _showTextStatusModal() {
    final textController = TextEditingController();
    int currentBgColor = Colors.teal.value;
    final List<int> bgColors = [
      Colors.teal.value,
      Colors.blueGrey.value,
      Colors.purple.value,
      Colors.pink.value,
      Colors.orange.value,
      Colors.blue.value,
      Colors.brown.value,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              height: MediaQuery.of(context).size.height,
              color: Color(currentBgColor),
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.palette, color: Colors.white),
                          onPressed: () {
                            setModalState(() {
                              final nextIndex = (bgColors.indexOf(currentBgColor) + 1) % bgColors.length;
                              currentBgColor = bgColors[nextIndex];
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: TextField(
                        controller: textController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Type a status',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: FloatingActionButton(
                      onPressed: () async {
                        final text = textController.text.trim();
                        if (text.isNotEmpty) {
                          Navigator.pop(context);
                          _handleTextStatusUpload(text, currentBgColor);
                        }
                      },
                      backgroundColor: Colors.white,
                      child: Icon(Icons.send, color: Color(currentBgColor)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleTextStatusUpload(String text, int bgColor) async {
    try {
      VoxaSnackBar.show(
        context,
        message: 'Uploading status...',
        icon: Icons.cloud_upload_outlined,
      );

      final user = await _firebaseService.getUserProfile();
      if (user == null) return;

      final privacy = user.privacy['status'] as String? ?? 'everyone';

      await StatusService.instance.uploadStatus(
        type: 'text',
        text: text,
        backgroundColor: bgColor,
        displayName: user.displayName,
        profilePhoto: user.photoUrl,
        privacy: privacy,
      );

      if (!mounted) return;
      VoxaSnackBar.success(context, 'Status uploaded!');
    } catch (e) {
      if (!mounted) return;
      VoxaSnackBar.error(context, 'Failed to upload status.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ChatsView(searchQuery: _searchQuery),
      const StatusView(),
      const CallsView(),
      const ProfileScreen(),
    ];

    final String appBarTitle;
    switch (_selectedIndex) {
      case 0:
        appBarTitle = 'Voxa';
        break;
      case 1:
        appBarTitle = 'Status';
        break;
      case 2:
        appBarTitle = 'Calls';
        break;
      case 3:
        appBarTitle = 'Profile';
        break;
      default:
        appBarTitle = 'Voxa';
    }

    return Scaffold(
      appBar: _selectedIndex == 3
          ? null
          : AppBar(
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
                  : Text(
                      appBarTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
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
            icon: Icon(Icons.circle_outlined),
            selectedIcon: Icon(Icons.circle),
            label: "Status",
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: "Calls",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "Profile",
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
          : (_selectedIndex == 1
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'edit_status',
                      onPressed: () {
                        _showTextStatusModal();
                      },
                      backgroundColor: Theme.of(context).cardColor,
                      child: const Icon(Icons.edit, color: AppColors.secondary),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      heroTag: 'camera_status',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.image),
                                  title: const Text('Image Status'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickAndUploadStatus(isVideo: false);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.videocam),
                                  title: const Text('Video Status'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickAndUploadStatus(isVideo: true);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      backgroundColor: AppColors.accent,
                      child: const Icon(Icons.camera_alt, color: Colors.white),
                    ),
                  ],
                )
              : null),
    );
  }
}
