import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/enums.dart';

class Subscription {
  final String choirId;
  final ChoirPlan plan;
  final PaymentProvider provider;
  final DateTime startDate;
  final DateTime endDate;
  final String txRef;
  final SubscriptionStatus status;

  const Subscription({
    required this.choirId,
    required this.plan,
    required this.provider,
    required this.startDate,
    required this.endDate,
    required this.txRef,
    required this.status,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      choirId: json['choirId'] as String,
      plan: ChoirPlan.values.byName(json['plan'] as String),
      provider: PaymentProvider.values.byName(json['provider'] as String),
      startDate: (json['startDate'] as Timestamp).toDate(),
      endDate: (json['endDate'] as Timestamp).toDate(),
      txRef: json['txRef'] as String,
      status: SubscriptionStatus.values.byName(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'choirId': choirId,
      'plan': plan.name,
      'provider': provider.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'txRef': txRef,
      'status': status.name,
    };
  }

  Subscription copyWith({
    String? choirId,
    ChoirPlan? plan,
    PaymentProvider? provider,
    DateTime? startDate,
    DateTime? endDate,
    String? txRef,
    SubscriptionStatus? status,
  }) {
    return Subscription(
      choirId: choirId ?? this.choirId,
      plan: plan ?? this.plan,
      provider: provider ?? this.provider,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      txRef: txRef ?? this.txRef,
      status: status ?? this.status,
    );
  }
}
