import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../shared/models/enums.dart';
import '../domain/models/subscription.dart';

class PaymentInitiationException implements Exception {
  final String message;
  PaymentInitiationException(this.message);
  @override
  String toString() => message;
}

class SubscriptionRepository {
  SubscriptionRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // Confirmed project ID: kwayapro-app (see PHASE_2B_REPORT.md / PHASE_3_REPORT.md).
  //
  // URL format verified live in Phase 3c: both initiatePayment and
  // cancelSubscription respond correctly (their own real error bodies, not
  // a 404) at this legacy cloudfunctions.net format, same as confirmed for
  // mtnWebhook's Cloud Run-native *.run.app equivalent — both formats route
  // to the same deployed 2nd-gen functions. See PHASE_3C_REPORT.md.
  static const _initiatePaymentUrl =
      'https://us-central1-kwayapro-app.cloudfunctions.net/initiatePayment';
  static const _cancelSubscriptionUrl =
      'https://us-central1-kwayapro-app.cloudfunctions.net/cancelSubscription';

  // Phase 3 fix: subscriptions/{choirId} is a single doc per choir — the
  // server (mtnWebhook/paymentWebhook) always writes it by that exact doc
  // ID. The previous implementation queried by a 'choirId' field with
  // .add()-generated IDs instead, which never matched what the server
  // actually writes and would have silently returned nothing forever.
  Stream<Subscription?> watchSubscription(String choirId) {
    return _db
        .collection('subscriptions')
        .doc(choirId)
        .snapshots()
        .map((snap) => snap.exists ? Subscription.fromJson(snap.data()!) : null);
  }

  Future<Subscription?> getSubscription(String choirId) async {
    final snap = await _db.collection('subscriptions').doc(choirId).get();
    return snap.exists ? Subscription.fromJson(snap.data()!) : null;
  }

  // Phase 3 fix: the subscription document is now exclusively written by
  // the mtnWebhook/paymentWebhook Cloud Functions (via the Admin SDK, which
  // bypasses firestore.rules) after MTN confirms payment — never by the
  // client. firestore.rules already enforces `allow write: if false` on
  // this collection, so the old client-side createSubscription/
  // updateSubscriptionStatus(active) calls this replaced were always going
  // to fail with PERMISSION_DENIED in practice; they simulated success by
  // never actually being blocked in a way the UI surfaced. This calls the
  // real initiatePayment Cloud Function instead, which requires the caller
  // to hold a valid Firebase ID token and be an actual member of choirId
  // (enforced server-side).
  Future<String> initiatePayment({
    required String choirId,
    required PaymentProvider provider,
    required String phone,
    required int amount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw PaymentInitiationException('You must be signed in to make a payment.');
    }
    final idToken = await user.getIdToken();

    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse(_initiatePaymentUrl),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'provider': provider.name,
          'phone': phone,
          'amount': amount,
          'choirId': choirId,
        }),
      );
    } catch (_) {
      throw PaymentInitiationException('Could not reach the server. Check your connection and try again.');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw PaymentInitiationException('Something went wrong starting the payment. Please try again.');
    }

    if (response.statusCode != 200 || body['success'] != true) {
      throw PaymentInitiationException(body['error'] as String? ?? 'Payment could not be started.');
    }

    return body['txRef'] as String;
  }

  // Lets the UI poll/watch the pending payment while waiting for MTN's
  // webhook confirmation — status transitions from 'pending' to either
  // 'completed' or 'failed', written server-side only.
  Stream<String?> watchPaymentRequestStatus(String txRef) {
    return _db
        .collection('payment_requests')
        .doc(txRef)
        .snapshots()
        .map((snap) => snap.data()?['status'] as String?);
  }

  // Phase 3b: Pro -> Free downgrade. Same trust-boundary discipline as
  // initiatePayment — the client never writes subscriptions/choirs plan
  // fields directly (firestore.rules still blocks it); this calls the
  // cancelSubscription Cloud Function, which verifies the caller's ID token
  // and server-side checks they hold leader/director role in choirId before
  // writing anything.
  Future<void> cancelSubscription(String choirId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw PaymentInitiationException('You must be signed in to do this.');
    }
    final idToken = await user.getIdToken();

    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse(_cancelSubscriptionUrl),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'choirId': choirId}),
      );
    } catch (_) {
      throw PaymentInitiationException('Could not reach the server. Check your connection and try again.');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw PaymentInitiationException('Something went wrong. Please try again.');
    }

    if (response.statusCode != 200 || body['success'] != true) {
      throw PaymentInitiationException(body['error'] as String? ?? 'Could not switch to the Free plan.');
    }
  }
}
