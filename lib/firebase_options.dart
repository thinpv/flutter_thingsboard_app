// File generated manually from android/app/google-services.json
// (FlutterFire CLI not run yet — re-generate via `flutterfire configure --project=mhome-1f026`
// to add iOS/Web platforms).
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Project: mhome-1f026
/// Android package: org.mpipe.mhome
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'run `flutterfire configure --project=mhome-1f026` to add web platform.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS - '
          'run `flutterfire configure --project=mhome-1f026` to add iOS platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAc4vRyffI05ghYq_KkJQIWoR1ZRQl88jc',
    appId: '1:140386562942:android:4c67224dffc83a7bec392f',
    messagingSenderId: '140386562942',
    projectId: 'mhome-1f026',
    storageBucket: 'mhome-1f026.firebasestorage.app',
  );
}
