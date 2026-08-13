import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/status_model.dart';

class StatusService {
  static final StatusService instance = StatusService._internal();
  StatusService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  Future<void> uploadStatus({
    String? imageUrl,
    String? text,
    int? backgroundColor,
    String? caption,
    required String displayName,
    String? profilePhoto,
    String type = 'image',
    String privacy = 'everyone',
  }) async {
    try {
      await _firestore.collection('status').add({
        'uid': _uid,
        'displayName': displayName,
        'profilePhoto': profilePhoto,
        'type': type,
        'imageUrl': imageUrl,
        'text': text,
        'backgroundColor': backgroundColor,
        'caption': caption,
        'privacy': privacy,
        'timestamp': FieldValue.serverTimestamp(),
        'viewers': [],
      });
    } catch (e) {
      debugPrint('[StatusService] uploadStatus error: $e');
    }
  }

  Stream<List<StatusModel>> getStatuses() {
    final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    
    return _firestore
        .collection('status')
        .where('timestamp', isGreaterThan: twentyFourHoursAgo)
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      return snap.docs.map((doc) => StatusModel.fromSnapshot(doc)).toList();
    });
  }

  Future<void> markStatusAsViewed(String statusId) async {
    try {
      await _firestore.collection('status').doc(statusId).update({
        'viewers': FieldValue.arrayUnion([_uid]),
      });
    } catch (e) {
      debugPrint('[StatusService] markStatusAsViewed error: $e');
    }
  }

  Future<void> deleteStatus(String statusId) async {
    try {
      await _firestore.collection('status').doc(statusId).delete();
    } catch (e) {
      debugPrint('[StatusService] deleteStatus error: $e');
    }
  }
}
