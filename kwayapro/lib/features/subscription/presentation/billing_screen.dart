import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/enums.dart';
import '../../choir/domain/choir_providers.dart';
import '../domain/subscription_providers.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  int _currentStep = 0;
  bool _isProcessing = false;

  static const _proDurationDays = 30;

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);
    final currentPlan = subscriptionAsync.valueOrNull?.plan ?? ChoirPlan.free;

    final isOnPro = currentPlan == ChoirPlan.pro;

    return Scaffold(
      appBar: AppBar(title: const Text('Billing'), centerTitle: true),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _handleStepContinue,
        onStepCancel: _handleStepCancel,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (_currentStep < 3)
                  FilledButton(
                    onPressed: details.onStepContinue,
                    child: Text(_currentStep == 2 ? 'Pay Now' : 'Continue'),
                  )
                else if (_currentStep == 3 && _isProcessing)
                  const FilledButton(
                    onPressed: null,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  FilledButton(
                    onPressed: details.onStepContinue,
                    child: const Text('Done'),
                  ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Select Plan'),
            content: _PlanSelectionStep(
              isOnPro: isOnPro,
              currentPlan: currentPlan,
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Payment Method'),
            content: const _PaymentMethodStep(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Confirm'),
            content: const _ConfirmationStep(),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Processing'),
            content: _ProcessingStep(
              isProcessing: _isProcessing,
              onComplete: () {
                setState(() => _currentStep = 4);
              },
            ),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
          ),
        ],
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
      _processPayment();
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

  Future<void> _processPayment() async {
    setState(() {
      _currentStep = 3;
      _isProcessing = true;
    });

    try {
      final choirId = ref.read(activeChoirIdProvider) ?? '';
      final plan = ref.read(selectedPlanProvider)!;
      final provider = ref.read(selectedProviderProvider)!;
      final txRef = 'TX_${DateTime.now().millisecondsSinceEpoch}';

      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(days: _proDurationDays));

      await ref
          .read(subscriptionRepositoryProvider)
          .createSubscription(
            choirId: choirId,
            plan: plan,
            provider: provider,
            startDate: startDate,
            endDate: endDate,
            txRef: txRef,
          );

      await Future.delayed(const Duration(seconds: 2));

      await ref
          .read(subscriptionRepositoryProvider)
          .updateSubscriptionStatus(txRef, SubscriptionStatus.active);

      setState(() => _isProcessing = false);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      }
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
        _ProviderCard(
          name: 'Airtel Money',
          logo: Icons.signal_cellular_alt_1_bar,
          isSelected: selectedProvider == PaymentProvider.airtel,
          onSelect: () => ref.read(selectedProviderProvider.notifier).state =
              PaymentProvider.airtel,
        ),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final String name;
  final IconData logo;
  final bool isSelected;
  final VoidCallback onSelect;

  const _ProviderCard({
    required this.name,
    required this.logo,
    required this.isSelected,
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
        ),
        child: Row(
          children: [
            Icon(logo, size: 32),
            const SizedBox(width: 16),
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationStep extends ConsumerWidget {
  const _ConfirmationStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
  final VoidCallback onComplete;

  const _ProcessingStep({required this.isProcessing, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    if (isProcessing) {
      return Column(
        children: [
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Processing payment...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your phone for the STK push',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      );
    }

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
