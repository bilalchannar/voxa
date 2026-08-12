import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:voxa/core/services/cloudinary_service.dart';
import 'package:voxa/core/services/firebase_service.dart';
import 'package:voxa/core/theme/app_colors.dart';
import 'package:voxa/core/utils/voxa_snackbar.dart';
import 'package:voxa/models/user_profile.dart';
import 'package:voxa/screens/chat/chat_screen.dart';
import 'package:voxa/widgets/profile/profile_avatar.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final CloudinaryService _cloudinaryService = const CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  List<UserProfile> _allUsers = [];
  Set<String> _contactUids = {};
  final Set<String> _selectedUids = {};
  bool _isLoadingUsers = true;
  bool _isCreating = false;
  File? _groupPhotoFile;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _firebaseService.getAllUsers();
      final contacts = await _firebaseService.getContactUids();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _contactUids = contacts;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _pickGroupPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() => _groupPhotoFile = File(picked.path));
    }
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      VoxaSnackBar.error(context, 'Please enter a group name.');
      return;
    }

    if (_selectedUids.isEmpty) {
      VoxaSnackBar.error(context, 'Please select at least one member.');
      return;
    }

    setState(() => _isCreating = true);

    try {
      String? photoUrl;
      if (_groupPhotoFile != null) {
        photoUrl = await _cloudinaryService.uploadMediaFile(
          file: _groupPhotoFile!,
          resourceType: 'image',
        );
      }

      final groupId = await _firebaseService.createGroup(
        groupName: name,
        groupPhoto: photoUrl,
        groupDescription: _descController.text.trim(),
        memberUids: _selectedUids.toList(),
      );

      if (!mounted) return;

      final recipient = UserProfile(
        uid: groupId,
        phoneNumber: '',
        displayName: name,
        photoUrl: photoUrl,
        about: _descController.text.trim(),
        isOnline: true,
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: groupId,
            recipient: recipient,
            isGroup: true,
          ),
        ),
      );
      VoxaSnackBar.success(context, 'Group created successfully!');
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        VoxaSnackBar.error(
          context,
          'Failed to create group. Please try again.',
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Group'),
        actions: [
          if (_isCreating)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check, color: AppColors.accent),
              onPressed: _createGroup,
            ),
        ],
      ),
      body: _isLoadingUsers
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickGroupPhoto,
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.secondary.withValues(
                            alpha: 0.1,
                          ),
                          backgroundImage: _groupPhotoFile != null
                              ? FileImage(_groupPhotoFile!)
                              : null,
                          child: _groupPhotoFile == null
                              ? const Icon(
                                  Icons.camera_alt,
                                  color: AppColors.secondary,
                                  size: 28,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Group Name',
                            hintText: 'Enter group name...',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Group Description (Optional)',
                      hintText: 'Add group description...',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Members',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_selectedUids.length} selected',
                        style: const TextStyle(color: AppColors.secondaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_allUsers.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No contacts available.',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _allUsers.length,
                      itemBuilder: (context, index) {
                        final user = _allUsers[index];
                        final isSelected = _selectedUids.contains(user.uid);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedUids.add(user.uid);
                              } else {
                                _selectedUids.remove(user.uid);
                              }
                            });
                          },
                          secondary: ProfileAvatar(
                            photoUrl: user.canSeePhoto(
                                    _firebaseService.currentUid,
                                    viewerContacts: _contactUids)
                                ? user.photoUrl
                                : null,
                            initial: user.initial,
                            radius: 20,
                          ),
                          title: Text(user.displayName),
                          subtitle: Text(user.phoneNumber),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
