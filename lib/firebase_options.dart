import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAyuTN62zeKVVCnA_2Fl2rX5EoMQejwq6w',
    appId: '1:959070188236:web:2de981c0e5bbd9a79c4869',
    messagingSenderId: '959070188236',
    projectId: 'start-of-firebase',
    authDomain: 'start-of-firebase.firebaseapp.com',
    databaseURL: 'https://start-of-firebase-default-rtdb.firebaseio.com',
    storageBucket: 'start-of-firebase.firebasestorage.app',
    measurementId: 'G-14G19DV495',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBa9mH7T0n2bq7pJqqpHbwy8MmMSWkAOdE',
    appId: '1:959070188236:android:5b5ccf3d3b7220ff9c4869',
    messagingSenderId: '959070188236',
    projectId: 'start-of-firebase',
    databaseURL: 'https://start-of-firebase-default-rtdb.firebaseio.com',
    storageBucket: 'start-of-firebase.firebasestorage.app',
  );
}
