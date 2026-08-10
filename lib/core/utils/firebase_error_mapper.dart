import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Converts Firebase exceptions into short, user-friendly messages while
/// logging the technical detail via [debugPrint] for developers.
///
/// Raw stack traces and internal codes are never shown to end users.
class FirebaseErrorMapper {
  FirebaseErrorMapper._();

  static String message(Object error, {String? context}) {
    // Log the real error for developers, not the user.
    debugPrint('[Voxa]${context != null ? ' ($context)' : ''} error: $error');

    if (error is FirebaseAuthException) {
      return _authMessage(error);
    }
    if (error is FirebaseException) {
      return _firestoreMessage(error);
    }
    return 'Something went wrong. Please try again.';
  }

  static String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a while and try again.';
      case 'invalid-phone-number':
        return 'That phone number looks invalid. Please check and retry.';
      case 'invalid-verification-code':
        return 'The code you entered is incorrect. Please try again.';
      case 'invalid-verification-id':
      case 'session-expired':
        return 'That code has expired. Please request a new one.';
      case 'missing-verification-code':
        return 'Please enter the 6-digit code we sent you.';
      case 'quota-exceeded':
        return 'SMS limit reached. Please try again later.';
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return 'That phone number is already linked to another account.';
      case 'requires-recent-login':
        return 'For your security, please log out and sign in again before '
            'making this change.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support for help.';
      case 'user-not-found':
      case 'user-token-expired':
        return 'Your session expired. Please sign in again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled for Voxa.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  static String _firestoreMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return "You don't have permission to do that.";
      case 'unauthenticated':
        return 'You are signed out. Please sign in again.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'deadline-exceeded':
        return 'The request timed out. Please try again.';
      case 'not-found':
        return 'The requested data could not be found.';
      case 'resource-exhausted':
        return 'Service is busy right now. Please try again shortly.';
      default:
        return e.message ?? 'Could not complete the request. Please try again.';
    }
  }
}
