import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kwayapro/features/auth/domain/models/app_user.dart';
import 'package:kwayapro/features/choir/domain/models/choir.dart';
import 'package:kwayapro/features/songs/domain/models/song.dart';
import 'package:kwayapro/features/songs/domain/models/audio_part.dart';
import 'package:kwayapro/features/songs/domain/models/score_attachment.dart';
import 'package:kwayapro/features/songs/domain/models/song_section.dart';
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

  // Phase 4 Fix 1: these three models previously hard-cast every field
  // (`json['x'] as String`, `as Timestamp`, etc.) with no fallback — a
  // document missing any field would throw inside fromJson, which
  // song_repository.dart's watchSections/watchAudioParts/
  // watchAudioPartsByVoicePart mapped with no per-doc error handling,
  // taking down the entire stream for every listener on one bad document.
  // These tests confirm the fix: a document missing required fields no
  // longer throws, matching every other model in the codebase.
  group('AudioPart Model (Phase 4 Fix 1)', () {
    test('fromJson handles a document missing every field without throwing', () {
      final part = AudioPart.fromJson(const {});

      expect(part.audioPartId, '');
      expect(part.sectionId, '');
      expect(part.songId, '');
      expect(part.choirId, '');
      expect(part.voicePart, VoicePart.S);
      expect(part.audioUrl, '');
      expect(part.durationSeconds, 0);
      expect(part.uploadedBy, '');
      expect(part.createdAt, isA<DateTime>());
    });

    test('fromJson and toJson with valid data', () {
      final now = DateTime.now();
      final json = {
        'audioPartId': 'ap1',
        'sectionId': 'sec1',
        'songId': 'song1',
        'choirId': 'choir1',
        'voicePart': 'A',
        'audioUrl': 'https://example.com/a.m4a',
        'durationSeconds': 120,
        'uploadedBy': 'user1',
        'createdAt': Timestamp.fromDate(now),
      };
      final part = AudioPart.fromJson(json);
      expect(part.audioPartId, 'ap1');
      expect(part.voicePart, VoicePart.A);
      expect(part.durationSeconds, 120);
    });
  });

  group('ScoreAttachment Model (Phase 4 Fix 1)', () {
    test('fromJson handles a document missing every field without throwing', () {
      final score = ScoreAttachment.fromJson(const {});

      expect(score.scoreId, '');
      expect(score.songId, '');
      expect(score.choirId, '');
      expect(score.type, ScoreType.pdf);
      expect(score.fileUrl, '');
      expect(score.label, '');
      expect(score.uploadedBy, '');
      expect(score.createdAt, isA<DateTime>());
    });

    test('fromJson and toJson with valid data', () {
      final now = DateTime.now();
      final json = {
        'scoreId': 's1',
        'songId': 'song1',
        'choirId': 'choir1',
        'type': 'image',
        'fileUrl': 'https://example.com/s.jpg',
        'label': 'Lead sheet',
        'uploadedBy': 'user1',
        'createdAt': Timestamp.fromDate(now),
      };
      final score = ScoreAttachment.fromJson(json);
      expect(score.scoreId, 's1');
      expect(score.type, ScoreType.image);
    });
  });

  group('SongSection Model (Phase 4 Fix 1)', () {
    test('fromJson handles a document missing every field without throwing', () {
      final section = SongSection.fromJson(const {});

      expect(section.sectionId, '');
      expect(section.songId, '');
      expect(section.choirId, '');
      expect(section.title, '');
      expect(section.order, 0);
      expect(section.status, SectionStatus.comingSoon);
    });

    test('fromJson and toJson with valid data', () {
      final json = {
        'sectionId': 'sec1',
        'songId': 'song1',
        'choirId': 'choir1',
        'title': 'Verse 1',
        'order': 2,
        'status': 'ready',
      };
      final section = SongSection.fromJson(json);
      expect(section.sectionId, 'sec1');
      expect(section.order, 2);
      expect(section.status, SectionStatus.ready);
    });
  });
}
