import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../choir/domain/choir_providers.dart';
import '../data/subscription_repository.dart';
import '../domain/models/subscription.dart';
import '../../../shared/models/enums.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

// Phase 5 Fix 4: previously not autoDispose — see song_providers.dart for
// the same fix and reasoning.
final subscriptionProvider = StreamProvider.autoDispose.family<Subscription?, String>((ref, choirId) {
  final sub = ref.watch(subscriptionRepositoryProvider).watchSubscription(choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});

final currentSubscriptionProvider = StreamProvider.autoDispose<Subscription?>((ref) {
  final choirId = ref.watch(activeChoirIdProvider);
  if (choirId == null) return Stream.value(null);
  final sub = ref.watch(subscriptionRepositoryProvider).watchSubscription(choirId);
  ref.onDispose(() => sub.drain());
  return sub;
});

final selectedPlanProvider = StateProvider<ChoirPlan?>((ref) => null);
final selectedProviderProvider = StateProvider<PaymentProvider?>((ref) => null);
