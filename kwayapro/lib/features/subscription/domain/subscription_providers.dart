import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../choir/domain/choir_providers.dart';
import '../data/subscription_repository.dart';
import '../domain/models/subscription.dart';
import '../../../shared/models/enums.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

final subscriptionProvider = StreamProvider.family<Subscription?, String>((ref, choirId) {
  return ref.read(subscriptionRepositoryProvider).watchSubscription(choirId);
});

final currentSubscriptionProvider = StreamProvider<Subscription?>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value(null);
  return ref.read(subscriptionRepositoryProvider).watchSubscription(choirId);
});

final selectedPlanProvider = StateProvider<ChoirPlan?>((ref) => null);
final selectedProviderProvider = StateProvider<PaymentProvider?>((ref) => null);