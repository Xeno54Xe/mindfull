// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not configured yet. Focus on Android for now.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    // 1. Look for "current_key" in google-services.json
    apiKey: 'AIzaSyDHzTXyEam1NP4biLsAMSDft1pxBb0BdoU', 
    
    // 2. Look for "mobilesdk_app_id" in google-services.json
    appId: '1:1069402233046:android:8558555b1d57e92cee9177', 
    
    // 3. Look for "project_number" in google-services.json
    messagingSenderId: '1069402233046', 
    
    // 4. Look for "project_id" in google-services.json
    projectId: 'mindfull-app', 
    
    // 5. Look for "storage_bucket" in google-services.json
    storageBucket: 'mindfull-app.appspot.com', 
  );
}