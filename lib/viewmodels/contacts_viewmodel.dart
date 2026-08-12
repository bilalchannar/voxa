import 'package:flutter/foundation.dart';

import '../core/services/firebase_service.dart';
import '../models/user_profile.dart';

class ContactsViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService;

  List<UserProfile> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  Set<String> _contactUids = {};

  ContactsViewModel({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService();

  List<UserProfile> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  Set<String> get contactUids => _contactUids;
  String get currentUid => _firebaseService.currentUid;
  bool get isEmpty => !_isLoading && _errorMessage == null && _contacts.isEmpty;

  Future<void> loadContacts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUid = _firebaseService.currentUid;
      _contactUids = await _firebaseService.getContactUids();
      final results = await _firebaseService.searchUsers(_searchQuery);

      // We want to show the current user at the top (Message Yourself)
      // and others below. If results already contain current user, we re-order.
      final List<UserProfile> filteredResults = results.where((u) {
        // Always include current user
        if (u.uid == currentUid) return true;
        
        // Filter out generic "Voxa User" entries if they don't have a photo or phone
        // OR simply filter all "Voxa User" if that's what the user wants.
        // The user specifically said "kaafi zyada voxa users ajate hen jo ni chaiya".
        if (u.displayName == UserProfile.defaultDisplayName) return false;
        
        return true;
      }).toList();

      final List<UserProfile> sorted = [];
      UserProfile? currentUser;

      for (final u in filteredResults) {
        if (u.uid == currentUid) {
          currentUser = u;
        } else {
          sorted.add(u);
        }
      }

      currentUser ??= await _firebaseService.getUserProfile();

      if (currentUser != null) {
        sorted.insert(0, currentUser);
      }

      _contacts = sorted;
    } catch (e) {
      debugPrint('[ContactsViewModel] loadContacts error: $e');
      _errorMessage = 'Could not load contacts. Please check connection.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void search(String query) {
    _searchQuery = query;
    loadContacts();
  }

  Future<String?> startChat(String targetUid) async {
    try {
      return await _firebaseService.createOrGetChat(targetUid);
    } catch (e) {
      debugPrint('[ContactsViewModel] startChat error: $e');
      return null;
    }
  }
}
