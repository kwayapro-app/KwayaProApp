import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/enums.dart';
import '../domain/models/subscription.dart';

class SubscriptionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<Subscription?> watchSubscription(String choirId) {
    return _db
        .collection('subscriptions')
        .where('choirId', isEqualTo: choirId)
        .where('status', whereIn: ['active', 'pending'])
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : Subscription.fromJson(snap.docs.first.data()));
  }

  Future<Subscription?> getSubscription(String choirId) async {
    final snap = await _db
        .collection('subscriptions')
        .where('choirId', isEqualTo: choirId)
        .where('status', whereIn: ['active', 'pending'])
        .limit(1)
        .get();
    
    return snap.docs.isEmpty ? null : Subscription.fromJson(snap.docs.first.data());
  }

  Future<void> createSubscription({
    required String choirId,
    required ChoirPlan plan,
    required PaymentProvider provider,
    required DateTime startDate,
    required DateTime endDate,
    required String txRef,
  }) async {
    final subscription = Subscription(
      choirId: choirId,
      plan: plan,
      provider: provider,
      startDate: startDate,
      endDate: endDate,
      txRef: txRef,
      status: SubscriptionStatus.pending,
    );

    await _db.collection('subscriptions').add(subscription.toJson());
  }

  Future<void> updateSubscriptionStatus(String txRef, SubscriptionStatus status) async {
    final snap = await _db
        .collection('subscriptions')
        .where('txRef', isEqualTo: txRef)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({'status': status.name});
    }
  }

  Future<void> upgradePlan(String choirId, ChoirPlan newPlan) async {
    final snap = await _db
        .collection('subscriptions')
        .where('choirId', isEqualTo: choirId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({'plan': newPlan.name});
    }
  }

  Future<void> cancelSubscription(String choirId) async {
    final snap = await _db
        .collection('subscriptions')
        .where('choirId', isEqualTo: choirId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({'status': SubscriptionStatus.expired.name});
    }
  }
}