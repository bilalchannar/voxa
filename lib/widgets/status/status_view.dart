import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/status_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/status_model.dart';
import '../../models/user_profile.dart';
import '../profile/profile_avatar.dart';
import '../../core/utils/voxa_snackbar.dart';

class StatusView extends StatefulWidget {
  const StatusView({super.key});

  @override
  State<StatusView> createState() => _StatusViewState();
}

class _StatusViewState extends State<StatusView> {
  final StatusService _statusService = StatusService.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final CloudinaryService _cloudinaryService = const CloudinaryService();
  final ImagePicker _picker = ImagePicker();
  Set<String> _contactUids = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _firebaseService.getContactUids();
      if (mounted) setState(() => _contactUids = contacts);
    } catch (_) {
      // Non-fatal: without contacts, "contacts"-only statuses stay hidden.
    }
  }

  Future<void> _pickStatus(ImageSource source, {bool isVideo = false}) async {
    XFile? file;
    if (isVideo) {
      file = await _picker.pickVideo(source: source);
    } else {
      file = await _picker.pickImage(source: source);
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

      final imageUrl = await _cloudinaryService.uploadMediaFile(
        file: file,
        resourceType: type,
      );

      final user = await _firebaseService.getUserProfile();
      if (user == null) return;

      final privacy = user.privacy['status'] as String? ?? 'everyone';

      await _statusService.uploadStatus(
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StatusModel>>(
      stream: _statusService.getStatuses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', 
            style: const TextStyle(color: AppColors.danger)),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final statuses = snapshot.data ?? [];
        final myUid = _firebaseService.currentUid;

        // Filter based on the poster's status privacy (client-side).
        // A status stamped 'contacts' is only shown if I'm a contact of the
        // poster — i.e. we share a 1:1 chat (symmetric relationship).
        final filteredStatuses = statuses.where((s) {
          if (s.uid == myUid) return true;
          switch (s.privacy) {
            case 'nobody':
              return false;
            case 'contacts':
              return _contactUids.contains(s.uid);
            default:
              return true;
          }
        }).toList();

        final myStatuses = filteredStatuses.where((s) => s.uid == myUid).toList();
        final otherStatuses = filteredStatuses.where((s) => s.uid != myUid).toList();

        final Map<String, List<StatusModel>> groupedOthers = {};
        for (var s in otherStatuses) {
          groupedOthers.putIfAbsent(s.uid, () => []).add(s);
        }

        final otherUsers = groupedOthers.keys.toList();

        return ListView(
          children: [
            ListTile(
              onTap: () {
                if (myStatuses.isNotEmpty) {
                  _showStatus(myStatuses);
                } else {
                  _pickStatus(ImageSource.gallery);
                }
              },
              leading: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: myStatuses.isNotEmpty 
                        ? Border.all(color: AppColors.accent, width: 2)
                        : null,
                    ),
                    child: FutureBuilder<UserProfile?>(
                      future: _firebaseService.getUserProfile(),
                      builder: (context, snapshot) {
                        final user = snapshot.data;
                        return ProfileAvatar(
                          photoUrl: user?.photoUrl,
                          initial: user?.initial ?? 'Y',
                          radius: 26,
                        );
                      },
                    ),
                  ),
                  if (myStatuses.isEmpty)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
              title: const Text(
                'My status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                myStatuses.isEmpty
                    ? 'Tap to add status update'
                    : 'You have ${myStatuses.length} updates',
              ),
              trailing: myStatuses.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                      onPressed: () {
                        _showDeleteConfirm(myStatuses);
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.camera_alt_outlined),
                      onPressed: () => _pickStatus(ImageSource.camera),
                    ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Recent updates',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            if (otherUsers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'No recent updates',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ),
              ),
            ...otherUsers.map((uid) {
              final userStatuses = groupedOthers[uid]!;
              final latest = userStatuses.first;

              return StreamBuilder<UserProfile?>(
                stream: _firebaseService.profileStream(uid: uid),
                builder: (context, profileSnap) {
                  final user = profileSnap.data;
                  final displayName = user?.displayName ?? latest.displayName;
                  final profilePhoto = user?.photoUrl ?? latest.profilePhoto;

                  return Column(
                    children: [
                      ListTile(
                        onTap: () => _showStatus(userStatuses),
                        leading: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.accent, width: 2),
                          ),
                          child: ProfileAvatar(
                            photoUrl: user?.canSeePhoto(myUid,
                                        viewerContacts: _contactUids) ==
                                    true
                                ? profilePhoto
                                : null,
                            initial: displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'U',
                            radius: 24,
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          DateFormat('hh:mm a').format(latest.timestamp),
                        ),
                      ),
                      const Divider(indent: 80),
                    ],
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  void _showStatus(List<StatusModel> statuses) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatusFullView(statuses: statuses),
      ),
    );
  }

  void _showDeleteConfirm(List<StatusModel> myStatuses) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Status?'),
        content: Text('This will delete all your ${myStatuses.length} current status updates.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              for (var s in myStatuses) {
                await _statusService.deleteStatus(s.statusId);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Status deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class StatusFullView extends StatefulWidget {
  final List<StatusModel> statuses;
  const StatusFullView({super.key, required this.statuses});

  @override
  State<StatusFullView> createState() => _StatusFullViewState();
}

class _StatusFullViewState extends State<StatusFullView> {
  int _currentIndex = 0;
  Timer? _timer;
  VideoPlayerController? _videoController;
  bool _isVideoLoading = false;

  @override
  void initState() {
    super.initState();
    _playStatus();
  }

  void _playStatus() {
    final status = widget.statuses[_currentIndex];
    StatusService.instance.markStatusAsViewed(status.statusId);

    if (status.type == 'video') {
      _initVideo(status.imageUrl ?? '');
    } else {
      _videoController?.dispose();
      _videoController = null;
      _startTimer(const Duration(seconds: 5));
    }
  }

  Future<void> _initVideo(String url) async {
    _timer?.cancel();
    setState(() => _isVideoLoading = true);
    
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    
    try {
      await _videoController!.initialize();
      if (!mounted) return;
      setState(() => _isVideoLoading = false);
      _videoController!.play();
      _startTimer(_videoController!.value.duration);
    } catch (e) {
      debugPrint('Video init error: $e');
      _nextStatus();
    }
  }

  void _startTimer(Duration duration) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      if (mounted) _nextStatus();
    });
  }

  void _nextStatus() {
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _playStatus();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.statuses[_currentIndex];
    return Scaffold(
      backgroundColor: status.type == 'text'
          ? Color(status.backgroundColor ?? Colors.teal.value)
          : Colors.black,
      body: Stack(
        children: [
          Center(
            child: status.type == 'video'
                ? (_videoController != null &&
                        _videoController!.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : const CircularProgressIndicator())
                : (status.type == 'text'
                    ? Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          status.text ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Image.network(
                        status.imageUrl ?? '',
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      )),
          ),
          if (_isVideoLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: List.generate(widget.statuses.length, (index) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: LinearProgressIndicator(
                          value: index < _currentIndex
                              ? 1
                              : (index == _currentIndex ? null : 0),
                          backgroundColor: Colors.white24,
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    );
                  }),
                ),
                ListTile(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    status.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('hh:mm a').format(status.timestamp),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          if (status.caption != null && status.caption!.isNotEmpty)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black54,
                child: Text(
                  status.caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
