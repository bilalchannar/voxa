import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/services/notification_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/cloudinary_service.dart';
import '../core/services/firebase_service.dart';
import '../models/user_profile.dart';

class ProfileViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final CloudinaryService _cloudinaryService;
  final AuthService _authService;
  final ImagePicker _picker;

  UserProfile? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploading = false;
  String? _errorMessage;

  ProfileViewModel({
    FirebaseService? firebaseService,
    CloudinaryService? cloudinaryService,
    AuthService? authService,
    ImagePicker? picker,
  }) : _firebaseService = firebaseService ?? FirebaseService(),
       _cloudinaryService = cloudinaryService ?? const CloudinaryService(),
       _authService = authService ?? AuthService(),
       _picker = picker ?? ImagePicker();

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isUploading => _isUploading;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _isSaving || _isUploading;

  bool get isCloudinaryConfigured => _cloudinaryService.isConfigured;
  String? get authPhoneNumber => _firebaseService.authPhoneNumber;

  Stream<UserProfile?> profileStream() {
    return _firebaseService.profileStream();
  }

  Future<void> ensureProfileExists() async {
    try {
      _profile = await _firebaseService.ensureProfileExists();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[ProfileViewModel] ensureProfileExists failed: $e');
    }
  }

  Future<void> loadProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _firebaseService.getUserProfile();
    } catch (e) {
      _errorMessage = 'Failed to load profile.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveProfile({
    required String displayName,
    required String about,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firebaseService.updateUserProfile(
        displayName: displayName,
        about: about,
      );
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save profile changes.';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> uploadProfilePhoto(ImageSource source) async {
    if (!isCloudinaryConfigured) {
      throw const CloudinaryNotConfiguredException();
    }

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (picked == null) {
      return null;
    }

    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = await _cloudinaryService.uploadImage(File(picked.path));
      await _firebaseService.updateProfilePhoto(url);
      _isUploading = false;
      notifyListeners();
      return url;
    } catch (e) {
      _isUploading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> removeProfilePhoto() async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firebaseService.removeProfilePhoto();
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to remove photo.';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePrivacy(String field, String value) async {
    try {
      await _firebaseService.updatePrivacy(field, value);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update privacy setting.';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isSaving = true;
    notifyListeners();

    try {
      await _firebaseService.setOnline(false);
      await NotificationService.instance.removeFcmToken();
    } catch (_) {}

    try {
      await _authService.signOut();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
