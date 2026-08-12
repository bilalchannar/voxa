import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/status_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/status_model.dart';
import '../../models/user_profile.dart';
import '../profile/profile_avatar.dart';
import 'package:intl/intl.dart';

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

  Future<void> _pickAndUploadStatus() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // Show loading or confirm dialog with caption
    if (!mounted) return;
    _showUploadDialog(File(image.path));
  }

  void _showUploadDialog(File file) {
    final captionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(file, height: 200, fit: BoxFit.cover),
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
              _handleUpload(file, captionController.text.trim());
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpload(File file, String caption) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading status...')),
      );

      final imageUrl = await _cloudinaryService.uploadMediaFile(
        file: file,
        resourceType: 'image',
      );

      final user = await _firebaseService.getUserProfile();
      if (user == null) return;

      await _statusService.uploadStatus(
        imageUrl: imageUrl,
        caption: caption,
        displayName: user.displayName,
        profilePhoto: user.photoUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status uploaded!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: _pickAndUploadStatus,
          leading: Stack(
            children: [
              FutureBuilder<UserProfile?>(
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
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          title: const Text(
            'My status',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Tap to add status update'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Recent updates',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<StatusModel>>(
            stream: _statusService.getStatuses(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final statuses = snapshot.data!;
              if (statuses.isEmpty) {
                return const Center(
                  child: Text(
                    'No status updates',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                );
              }

              // Group by user for simple UI
              final Map<String, List<StatusModel>> grouped = {};
              for (var s in statuses) {
                grouped.putIfAbsent(s.uid, () => []).add(s);
              }

              final users = grouped.keys.toList();

              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (context, index) => const Divider(indent: 80),
                itemBuilder: (context, index) {
                  final uid = users[index];
                  final userStatuses = grouped[uid]!;
                  final latest = userStatuses.first;

                  return ListTile(
                    onTap: () {
                      _showStatus(userStatuses);
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent, width: 2),
                      ),
                      child: ProfileAvatar(
                        photoUrl: latest.profilePhoto,
                        initial: latest.displayName[0],
                        radius: 24,
                      ),
                    ),
                    title: Text(
                      latest.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      DateFormat('hh:mm a').format(latest.timestamp),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
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

  @override
  void initState() {
    super.initState();
    _startTimer();
    StatusService.instance.markStatusAsViewed(widget.statuses[_currentIndex].statusId);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), () {
      if (_currentIndex < widget.statuses.length - 1) {
        setState(() {
          _currentIndex++;
        });
        _startTimer();
        StatusService.instance.markStatusAsViewed(widget.statuses[_currentIndex].statusId);
      } else {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.statuses[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Image.network(
              status.imageUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
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
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
