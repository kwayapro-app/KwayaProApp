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
    apiKey: 'AIzaSyBF0S2YXphQ0xCqWcD9kmD4yu1uStSDDMw',
    appId: '1:432531236139:android:903ae2bc52e6cd2598916e',
    messagingSenderId: '432531236139',
    projectId: 'kwayapro-app',
    storageBucket: 'kwayapro-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBF0S2YXphQ0xCqWcD9kmD4yu1uStSDDMw',
    appId: '1:432531236139:ios:placeholder',
    messagingSenderId: '432531236139',
    projectId: 'kwayapro-app',
    storageBucket: 'kwayapro-app.firebasestorage.app',
    iosBundleId: 'com.kwayapro.kwayapro',
  );
}