import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// IMPORTANT: Replace these placeholder values with your actual Firebase config
/// from the Firebase Console: https://console.firebase.google.com
///
/// Steps:
/// 1. Go to Firebase Console > Project Settings > General
/// 2. Scroll to "Your apps" section
/// 3. Add Android/iOS apps if not already added
/// 4. Copy the configuration values below
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
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

  // TODO: Replace with your Firebase Web config
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    databaseURL: 'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  // TODO: Replace with your Firebase Android config
 static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIzaSyB6zyYDLEfq1HgdQhP6SG7DvykOOBtMlEw',
  appId: '1:937701535388:android:7b893ec94fae7e7d434759',
  messagingSenderId: '937701535388',
  projectId: 'cliotel-cls-driver',
  databaseURL: 'https://cliotel-cls-driver-default-rtdb.europe-west1.firebasedatabase.app',
  storageBucket: 'cliotel-cls-driver.firebasestorage.app',
);

  // TODO: Replace with your Firebase iOS config
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    databaseURL: 'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.cliotel.driver',
  );
}
