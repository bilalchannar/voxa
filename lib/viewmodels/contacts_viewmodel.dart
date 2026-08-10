import 'package:flutter/foundation.dart';

import '../core/services/firebase_service.dart';
import '../models/user_profile.dart';

class ContactsViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService;

  List<UserProfile> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  ContactsViewModel({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService();

  List<UserProfile> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  bool get isEmpty => !_isLoading && _errorMessage == null && _contacts.isEmpty;

  Future<void> loadContacts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _contacts = await _firebaseService.searchUsers(_searchQuery);
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
