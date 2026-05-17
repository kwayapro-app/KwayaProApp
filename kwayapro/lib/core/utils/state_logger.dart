import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_logger.dart';

class StateLogger extends ProviderObserver {
  const StateLogger();

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    AppLogger.debug(
      'Provider initialized | Value: $value',
      tag: provider.name ?? provider.runtimeType.toString(),
    );
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    AppLogger.debug(
      'Provider updated | Prev: $previousValue | Next: $newValue',
      tag: provider.name ?? provider.runtimeType.toString(),
    );
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    AppLogger.debug(
      'Provider disposed',
      tag: provider.name ?? provider.runtimeType.toString(),
    );
  }
}
