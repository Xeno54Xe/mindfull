// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // 1. IF RUNNING ON CHROME (WEB)
    if (kIsWeb) {
      return web;
    }
    // 2. IF RUNNING ON PHONE (ANDROID)
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for ios.');
      case TargetPlatform.macOS:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for macos.');
      case TargetPlatform.windows:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for windows.');
      case TargetPlatform.linux:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for linux.');
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  // --- 🌍 WEB CONFIGURATION (Paste keys from Firebase Console) ---
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB0asG0c4MtyWGSa9BKvgy6jip08g1ClOI', 
    appId: '1:1069402233046:web:47e92e31de2c8a45ee9177', 
    messagingSenderId: '1069402233046', 
    projectId: 'mindfull-app', 
    authDomain: 'mindfull-app.firebaseapp.com',
    storageBucket: 'mindfull-app.appspot.com',
    measurementId: 'G-2R999VLRSE', // Optional
  );

  // --- 📱 ANDROID CONFIGURATION (I kept these for you!) ---
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDHzTXyEam1NP4biLsAMSDft1pxBb0BdoU', 
    appId: '1:1069402233046:android:8558555b1d57e92cee9177', 
    messagingSenderId: '1069402233046', 
    projectId: 'mindfull-app', 
    storageBucket: 'mindfull-app.appspot.com', 
  );
}