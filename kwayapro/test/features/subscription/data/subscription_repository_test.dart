// Phase 7 test-coverage backfill: SubscriptionRepository's Firestore read
// path (watchSubscription/getSubscription) had zero test coverage despite
// being a direct regression-prone spot — PHASE_3_REPORT.md documents that
// this exact method silently returned nothing forever before being fixed
// from a field-query-on-.add()-docs pattern to a direct .doc(choirId)
// lookup, because the server (mtnWebhook) has always written subscriptions
// by choirId as the doc ID, not as a queryable field on an auto-ID doc. This
// test locks that fix in place. The HTTP-calling methods (initiatePayment,
// cancelSubscription) are deliberately not covered here — their server-side
// behavior is covered end-to-end by functions/test/integration.js against
// the real Functions emulator; re-mocking package:http here would test
// request-building only, which is lower value than the real coverage that
// already exists on the other side of that call.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwayapro/features/subscription/data/subscription_repository.dart';
import 'package:kwayapro/features/subscription/domain/models/subscription.dart';
import 'package:kwayapro/shared/models/enums.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late SubscriptionRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = SubscriptionRepository(firestore: firestore);
  });

  group('SubscriptionRepository Firestore reads (Phase 3 doc-ID fix)', () {
    test('getSubscription returns null when no subscription doc exists for the choir', () async {
      final result = await repository.getSubscription('choirNoSub');
      expect(result, isNull);
    });

    test('getSubscription finds a subscription written by choirId as the doc ID '
        '(matching how mtnWebhook actually writes it)', () async {
      await firestore.collection('subscriptions').doc('choirWithSub').set({
        'choirId': 'choirWithSub',
        'plan': 'pro',
        'provider': 'mtn',
        'startDate': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'endDate': Timestamp.fromDate(DateTime(2026, 1, 31)),
        'txRef': 'TXN-choirWithSub-1',
        'status': 'active',
      });

      final result = await repository.getSubscription('choirWithSub');

      expect(result, isNotNull);
      expect(result!.plan, ChoirPlan.pro);
      expect(result.status, SubscriptionStatus.active);
      expect(result.txRef, 'TXN-choirWithSub-1');
    });

    test('watchSubscription emits null then the subscription once written', () async {
      final stream = repository.watchSubscription('choirStreamed');
      final emissions = <Subscription?>[];
      final sub = stream.listen(emissions.add);

      await Future<void>.delayed(Duration.zero);
      expect(emissions, [null]);

      await firestore.collection('subscriptions').doc('choirStreamed').set({
        'choirId': 'choirStreamed',
        'plan': 'pro',
        'provider': 'mtn',
        'startDate': Timestamp.fromDate(DateTime(2026, 2, 1)),
        'endDate': Timestamp.fromDate(DateTime(2026, 3, 3)),
        'txRef': 'TXN-choirStreamed-1',
        'status': 'active',
      });
      await Future<void>.delayed(Duration.zero);

      expect(emissions.length, 2);
      expect(emissions.last, isNotNull);
      expect(emissions.last!.status, SubscriptionStatus.active);

      await sub.cancel();
    });

    test('watchSubscription reflects a cancelSubscription-style downgrade '
        '(status flips to cancelled, doc is not deleted)', () async {
      await firestore.collection('subscriptions').doc('choirDowngraded').set({
        'choirId': 'choirDowngraded',
        'plan': 'pro',
        'provider': 'mtn',
        'startDate': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'endDate': Timestamp.fromDate(DateTime(2026, 1, 31)),
        'txRef': 'TXN-choirDowngraded-1',
        'status': 'active',
      });

      final stream = repository.watchSubscription('choirDowngraded');
      final emissions = <Subscription?>[];
      final sub = stream.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      await firestore.collection('subscriptions').doc('choirDowngraded').update({
        'status': 'cancelled',
      });
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last, isNotNull);
      expect(emissions.last!.status, SubscriptionStatus.cancelled);

      await sub.cancel();
    });

    test('watchPaymentRequestStatus emits the status field as it changes '
        '(the field the billing UI polls while waiting for the MTN webhook)', () async {
      await firestore.collection('payment_requests').doc('TXN-poll-1').set({
        'choirId': 'choirPoll',
        'provider': 'mtn',
        'amount': 40000,
        'phone': '+256700000001',
        'status': 'pending',
      });

      final stream = repository.watchPaymentRequestStatus('TXN-poll-1');
      final emissions = <String?>[];
      final sub = stream.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, ['pending']);

      await firestore.collection('payment_requests').doc('TXN-poll-1').update({
        'status': 'completed',
      });
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last, 'completed');

      await sub.cancel();
    });
  });
}
