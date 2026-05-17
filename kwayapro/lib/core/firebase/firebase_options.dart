import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'placeholder-api-key-android',
    appId: '1:1234567890:android:placeholder',
    messagingSenderId: '1234567890',
    projectId: 'kwayapro-placeholder',
    storageBucket: 'kwayapro-placeholder.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'placeholder-api-key-ios',
    appId: '1:1234567890:ios:placeholder',
    messagingSenderId: '1234567890',
    projectId: 'kwayapro-placeholder',
    storageBucket: 'kwayapro-placeholder.appspot.com',
    iosBundleId: 'com.kwayapro.kwayapro',
  );
}
