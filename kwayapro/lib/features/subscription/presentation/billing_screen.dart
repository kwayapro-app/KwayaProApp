import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/enums.dart';
import '../../auth/domain/auth_providers.dart';
import '../../choir/domain/choir_providers.dart';
import '../data/subscription_repository.dart';
import '../domain/models/subscription.dart';
import '../domain/subscription_providers.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

enum _PaymentOutcome { success, downgraded, failed, timeout }

class _BillingScreenState extends ConsumerState<BillingScreen> {
  int _currentStep = 0;
  bool _isProcessing = false;
  _PaymentOutcome? _paymentOutcome;
  String? _paymentError;
  StreamSubscription<String?>? _paymentStatusSub;
  StreamSubscription<Subscription?>? _downgradeWatchSub;

  static const _proMonthlyAmountUgx = 40000;

  @override
  void dispose() {
    _paymentStatusSub?.cancel();
    _downgradeWatchSub?.cancel();
    super.dispose();
  }

  static const _stepTitles = ['Select Plan', 'Payment Method', 'Confirm', 'Processing'];

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);
    final currentPlan = subscriptionAsync.valueOrNull?.plan ?? ChoirPlan.free;
    final selectedPlan = ref.watch(selectedPlanProvider);

    final isOnPro = currentPlan == ChoirPlan.pro;
    final isDowngrade = selectedPlan == ChoirPlan.free && currentPlan == ChoirPlan.pro;

    final Widget stepContent = switch (_currentStep) {
      0 => _PlanSelectionStep(isOnPro: isOnPro, currentPlan: currentPlan),
      1 => const _PaymentMethodStep(),
      2 => const _ConfirmationStep(),
      _ => _ProcessingStep(
          isProcessing: _isProcessing,
          isDowngrade: isDowngrade,
          outcome: _paymentOutcome,
          errorMessage: _paymentError,
        ),
    };

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Billing'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _stepTitles[_currentStep],
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            stepContent,
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Row(
                children: [
                  if (_currentStep < 3)
                    Expanded(
                      child: FilledButton(
                        onPressed: _handleStepContinue,
                        child: Text(_currentStep == 2 ? 'Pay Now' : 'Continue'),
                      ),
                    )
                  else if (_isProcessing)
                    const Expanded(
                      child: FilledButton(
                        onPressed: null,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: FilledButton(
                        onPressed: _handleStepContinue,
                        child: const Text('Done'),
                      ),
                    ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    Material(
                      color: Colors.transparent,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: _handleStepCancel,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Text('Back'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleStepContinue() {
    if (_currentStep == 0) {
      final selectedPlan = ref.read(selectedPlanProvider);
      if (selectedPlan == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a plan')));
        return;
      }
    } else if (_currentStep == 1) {
      final selectedProvider = ref.read(selectedProviderProvider);
      if (selectedProvider == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a payment method')),
        );
        return;
      }
    } else if (_currentStep == 2) {
      final plan = ref.read(selectedPlanProvider)!;
      final currentPlan = ref.read(currentSubscriptionProvider).valueOrNull?.plan ?? ChoirPlan.free;
      if (plan == ChoirPlan.free && currentPlan == ChoirPlan.pro) {
        _confirmAndProcessDowngrade();
      } else {
        _processPayment();
      }
      return;
    } else if (_currentStep == 3) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _currentStep++);
  }

  void _handleStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // Phase 3 fix: this used to fake success with a Future.delayed and write
  // the subscription directly from the client — that write was always
  // rejected by firestore.rules (`allow write: if false` on subscriptions),
  // it just never surfaced as a visible failure. Now it calls the real
  // initiatePayment Cloud Function and watches the server-written
  // payment_requests status for the webhook-driven outcome. Nothing here
  // ever marks a subscription active client-side.
  Future<void> _processPayment() async {
    final plan = ref.read(selectedPlanProvider)!;

    if (plan == ChoirPlan.free) {
      // Already free (or no active subscription) — nothing to charge or
      // change. The Pro -> Free downgrade path is handled separately by
      // _confirmAndProcessDowngrade, invoked from _handleStepContinue
      // before this method is ever reached in that case.
      setState(() {
        _currentStep = 3;
        _isProcessing = false;
        _paymentOutcome = _PaymentOutcome.success;
        _paymentError = null;
      });
      return;
    }

    setState(() {
      _currentStep = 3;
      _isProcessing = true;
      _paymentOutcome = null;
      _paymentError = null;
    });

    await _paymentStatusSub?.cancel();

    try {
      final choirId = ref.read(activeChoirIdProvider) ?? '';
      final provider = ref.read(selectedProviderProvider)!;
      final phone = ref.read(currentUserProvider).valueOrNull?.phone ?? '';
      if (phone.isEmpty) {
        throw PaymentInitiationException(
          "We don't have a phone number on file for you. Update your profile and try again.",
        );
      }

      final txRef = await ref.read(subscriptionRepositoryProvider).initiatePayment(
            choirId: choirId,
            provider: provider,
            phone: phone,
            amount: _proMonthlyAmountUgx,
          );

      // Poll the payment_requests doc for the webhook-driven status update
      // rather than trusting anything client-side. MTN sends an STK-style
      // prompt to the user's phone; we wait here for mtnWebhook to record
      // the outcome once the user approves/rejects it on-device.
      var settled = false;
      final timeoutTimer = Timer(const Duration(minutes: 2), () {
        if (settled || !mounted) return;
        settled = true;
        setState(() {
          _isProcessing = false;
          _paymentOutcome = _PaymentOutcome.timeout;
        });
      });

      _paymentStatusSub = ref
          .read(subscriptionRepositoryProvider)
          .watchPaymentRequestStatus(txRef)
          .listen((status) {
        if (settled || status == null || status == 'pending') return;
        settled = true;
        timeoutTimer.cancel();
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _paymentOutcome = status == 'completed' ? _PaymentOutcome.success : _PaymentOutcome.failed;
        });
      });
    } on PaymentInitiationException catch (e) {
      setState(() {
        _isProcessing = false;
        _paymentOutcome = _PaymentOutcome.failed;
        _paymentError = e.message;
      });
    } catch (_) {
      setState(() {
        _isProcessing = false;
        _paymentOutcome = _PaymentOutcome.failed;
        _paymentError = 'Something went wrong starting the payment. Please try again.';
      });
    }
  }

  // Phase 3b Fix B: Pro -> Free downgrade. Shows a confirmation dialog
  // explaining the consequences (see the dialog copy below for the
  // reasoning on what happens to songs over the Free cap), then calls the
  // cancelSubscription Cloud Function and watches the real resulting
  // subscription state — the same "never assume success client-side"
  // discipline Fix 4 established for the payment path.
  Future<void> _confirmAndProcessDowngrade() async {
    final choir = ref.read(activeChoirProvider).valueOrNull;
    final songCount = choir?.songCount ?? 0;
    final overCap = songCount > 3;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Switch to Free plan?'),
        content: Text(
          overCap
              ? "You'll lose Pro features immediately — advanced attendance analytics, "
                  'score uploads, and priority support. Your choir currently has $songCount '
                  'songs; all of them stay visible and playable, but you won\'t be able to add '
                  "new songs until you're back under the Free plan's 3-song limit or upgrade again."
              : "You'll lose Pro features immediately — advanced attendance analytics, "
                  'score uploads, and priority support. The Free plan\'s 3-song limit will '
                  'apply going forward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Pro'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Switch to Free'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final choirId = ref.read(activeChoirIdProvider) ?? '';

    setState(() {
      _currentStep = 3;
      _isProcessing = true;
      _paymentOutcome = null;
      _paymentError = null;
    });

    await _downgradeWatchSub?.cancel();

    try {
      await ref.read(subscriptionRepositoryProvider).cancelSubscription(choirId);

      // The Cloud Function writes synchronously before responding, but we
      // confirm the real resulting state rather than trusting the HTTP 200
      // alone — a short timeout guards against a delayed/failed write
      // rather than assuming success or hanging the UI indefinitely.
      var settled = false;
      final timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (settled || !mounted) return;
        settled = true;
        setState(() {
          _isProcessing = false;
          _paymentOutcome = _PaymentOutcome.timeout;
        });
      });

      _downgradeWatchSub = ref
          .read(subscriptionRepositoryProvider)
          .watchSubscription(choirId)
          .listen((subscription) {
        if (settled || subscription?.status != SubscriptionStatus.cancelled) return;
        settled = true;
        timeoutTimer.cancel();
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _paymentOutcome = _PaymentOutcome.downgraded;
        });
      });
    } on PaymentInitiationException catch (e) {
      setState(() {
        _isProcessing = false;
        _paymentOutcome = _PaymentOutcome.failed;
        _paymentError = e.message;
      });
    } catch (_) {
      setState(() {
        _isProcessing = false;
        _paymentOutcome = _PaymentOutcome.failed;
        _paymentError = 'Something went wrong. Please try again.';
      });
    }
  }
}

class _PlanSelectionStep extends ConsumerWidget {
  final bool isOnPro;
  final ChoirPlan currentPlan;

  const _PlanSelectionStep({required this.isOnPro, required this.currentPlan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPlan = ref.watch(selectedPlanProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlanCard(
          title: 'Free',
          price: 'UGX 0',
          features: const [
            'Up to 3 songs',
            'Basic attendance',
            'Member management',
          ],
          isSelected:
              selectedPlan == ChoirPlan.free || currentPlan == ChoirPlan.free,
          isCurrent: currentPlan == ChoirPlan.free,
          onSelect: () =>
              ref.read(selectedPlanProvider.notifier).state = ChoirPlan.free,
        ),
        const SizedBox(height: 16),
        _PlanCard(
          title: 'Pro',
          price: 'UGX 40,000/month',
          features: const [
            'Unlimited songs',
            'Advanced attendance analytics',
            'Score uploads',
            'Priority support',
          ],
          isSelected:
              selectedPlan == ChoirPlan.pro || currentPlan == ChoirPlan.pro,
          isCurrent: currentPlan == ChoirPlan.pro,
          onSelect: () =>
              ref.read(selectedPlanProvider.notifier).state = ChoirPlan.pro,
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final List<String> features;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.features,
    required this.isSelected,
    required this.isCurrent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Current',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(f),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodStep extends ConsumerWidget {
  const _PaymentMethodStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProvider = ref.watch(selectedProviderProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select your mobile money provider',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        _ProviderCard(
          name: 'MTN Mobile Money',
          logo: Icons.signal_cellular_alt,
          isSelected: selectedProvider == PaymentProvider.mtn,
          onSelect: () => ref.read(selectedProviderProvider.notifier).state =
              PaymentProvider.mtn,
        ),
        const SizedBox(height: 12),
        const _ProviderCard(
          name: 'Airtel Money',
          logo: Icons.signal_cellular_alt_1_bar,
          isSelected: false,
          onSelect: null,
          badge: 'Coming soon',
        ),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final String name;
  final IconData logo;
  final bool isSelected;
  final VoidCallback? onSelect;
  final String? badge;

  const _ProviderCard({
    required this.name,
    required this.logo,
    required this.isSelected,
    required this.onSelect,
    this.badge,
  });

  bool get _isDisabled => onSelect == null;

  @override
  Widget build(BuildContext context) {
    final outlineColor = Theme.of(context).colorScheme.outline;
    return GestureDetector(
      onTap: onSelect,
      child: Opacity(
        opacity: _isDisabled ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : outlineColor,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(logo, size: 32),
              const SizedBox(width: 16),
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: outlineColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              const Spacer(),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmationStep extends ConsumerWidget {
  const _ConfirmationStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPlan = ref.watch(selectedPlanProvider);
    final currentPlan = ref.watch(currentSubscriptionProvider).valueOrNull?.plan ?? ChoirPlan.free;
    final isDowngrade = selectedPlan == ChoirPlan.free && currentPlan == ChoirPlan.pro;

    if (isDowngrade) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Switch to Free Plan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const _SummaryRow(label: 'Plan', value: 'Free'),
            const _SummaryRow(label: 'Amount', value: 'UGX 0'),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              "No payment is involved — you'll be asked to confirm before this takes effect.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Divider(),
          const _SummaryRow(label: 'Plan', value: '-'),
          const _SummaryRow(label: 'Amount', value: 'UGX 40,000'),
          const _SummaryRow(label: 'Duration', value: '30 days'),
          const _SummaryRow(label: 'Payment', value: '-'),
          const Divider(),
          const _SummaryRow(label: 'Total', value: 'UGX 40,000', isBold: true),
          const SizedBox(height: 16),
          Text(
            'You will receive an STK push on your phone to complete the payment.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                : null,
          ),
          Text(
            value,
            style: isBold
                ? Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                : null,
          ),
        ],
      ),
    );
  }
}

class _ProcessingStep extends StatelessWidget {
  final bool isProcessing;
  final bool isDowngrade;
  final _PaymentOutcome? outcome;
  final String? errorMessage;

  const _ProcessingStep({
    required this.isProcessing,
    required this.isDowngrade,
    required this.outcome,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isProcessing) {
      return Column(
        children: [
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            isDowngrade ? 'Switching to Free...' : 'Processing payment...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isDowngrade ? 'This only takes a moment.' : 'Please check your phone for the STK push',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      );
    }

    switch (outcome) {
      case _PaymentOutcome.failed:
        return Column(
          children: [
            const SizedBox(height: 32),
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 24),
            Text(
              'Payment Failed',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'The payment could not be completed. Please try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        );
      case _PaymentOutcome.timeout:
        return Column(
          children: [
            const SizedBox(height: 32),
            Icon(Icons.hourglass_bottom, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 24),
            Text(
              'Still Waiting',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "We haven't heard back yet. If you approved the prompt on your phone, "
              'this can take a few minutes — check back shortly.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        );
      case _PaymentOutcome.downgraded:
        return Column(
          children: [
            const SizedBox(height: 32),
            Icon(
              Icons.check_circle,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              "You're on the Free Plan",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Pro subscription has been cancelled',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        );
      case _PaymentOutcome.success:
      case null:
        return Column(
          children: [
            const SizedBox(height: 32),
            Icon(
              Icons.check_circle,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Payment Successful!',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Pro subscription is now active',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        );
    }
  }
}
