import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kwayapro/features/auth/domain/models/app_user.dart';
import 'package:kwayapro/features/choir/domain/models/choir.dart';
import 'package:kwayapro/features/songs/domain/models/song.dart';
import 'package:kwayapro/shared/models/enums.dart';

void main() {
  group('AppUser Model', () {
    test('fromJson and toJson with valid data', () {
      final now = DateTime.now();
      final json = {
        'userId': 'user123',
        'name': 'Test User',
        'phone': '+256772123456',
        'profilePhotoUrl': 'https://example.com/photo.jpg',
        'fcmToken': 'token123',
        'createdAt': Timestamp.fromDate(now),
      };

      final user = AppUser.fromJson(json);

      expect(user.userId, 'user123');
      expect(user.name, 'Test User');
      expect(user.phone, '+256772123456');
      expect(user.profilePhotoUrl, 'https://example.com/photo.jpg');
      expect(user.fcmToken, 'token123');
      // DateTime might lose some precision on milliseconds if not careful, but fromDate keeps it identical mostly.
      expect(user.createdAt.millisecondsSinceEpoch, now.millisecondsSinceEpoch);

      final tojson = user.toJson();
      expect(tojson['userId'], 'user123');
      expect(tojson['name'], 'Test User');
      expect(tojson['createdAt'], isA<Timestamp>());
    });

    test('fromJson handles null values gracefully', () {
      final json = {
        'userId': 'user123',
        'name': 'Test User',
        'phone': '+256772123456',
        // missing profilePhotoUrl
        // missing fcmToken
        // missing createdAt (simulate bad data)
      };

      final user = AppUser.fromJson(json);

      expect(user.userId, 'user123');
      expect(user.name, 'Test User');
      expect(user.phone, '+256772123456');
      expect(user.profilePhotoUrl, isNull);
      expect(user.fcmToken, isNull);
      expect(user.createdAt, isA<DateTime>()); // Falls back to DateTime.now()
    });
  });

  group('Choir Model', () {
    test('fromJson and toJson', () {
      final now = DateTime.now();
      final json = {
        'choirId': 'choir123',
        'name': 'Test Choir',
        'churchName': 'Test Church',
        'leaderId': 'leader123',
        'inviteCode': 'ABCDEF',
        'plan': 'pro',
        'songCount': 10,
        'createdAt': Timestamp.fromDate(now),
      };

      final choir = Choir.fromJson(json);

      expect(choir.choirId, 'choir123');
      expect(choir.name, 'Test Choir');
      expect(choir.churchName, 'Test Church');
      expect(choir.leaderId, 'leader123');
      expect(choir.inviteCode, 'ABCDEF');
      expect(choir.plan, ChoirPlan.pro);
      expect(choir.songCount, 10);
      expect(choir.createdAt.millisecondsSinceEpoch, now.millisecondsSinceEpoch);

      final tojson = choir.toJson();
      expect(tojson['plan'], 'pro');
      expect(tojson['createdAt'], isA<Timestamp>());
    });
  });

  group('Song Model', () {
    test('fromJson and toJson with arrays', () {
      final now = DateTime.now();
      final json = {
        'songId': 'song123',
        'choirId': 'choir123',
        'title': 'Holy Holy',
        'key': 'G Major',
        'language': 'English',
        'category': 'Hymn',
        'uploadedBy': 'user123',
        'createdAt': Timestamp.fromDate(now),
      };

      final song = Song.fromJson(json);

      expect(song.songId, 'song123');
      expect(song.choirId, 'choir123');
      expect(song.title, 'Holy Holy');
      expect(song.key, 'G Major');
      expect(song.language, 'English');
      expect(song.category, 'Hymn');
      expect(song.uploadedBy, 'user123');

      final tojson = song.toJson();
      expect(tojson['language'], 'English');
      expect(tojson['createdAt'], isA<Timestamp>());
    });
  });
}
