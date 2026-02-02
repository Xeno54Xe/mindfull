import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: "AIzaSyB0asG0c4MtyWGSa9BKvgy6jip08g1ClOI",
        authDomain: "mindfull-app-68b82.firebaseapp.com",
        projectId: "mindfull-app-68b82",
        storageBucket: "mindfull-app-68b82.firebasestorage.app",
        messagingSenderId: "1069402233046",
        appId: "1:1069402233046:web:47e92e31de2c8a45ee9177",
        measurementId: "G-2R999VLRSE",
      );
    }
    throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
  }
}