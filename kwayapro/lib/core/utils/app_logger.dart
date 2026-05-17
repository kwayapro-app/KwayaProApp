import 'dart:developer' as developer;

enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

class AppLogger {
  AppLogger._();

  static LogLevel minLogLevel = LogLevel.debug;

  static void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, '🐛', message, tag, error, stackTrace);
  }

  static void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, 'ℹ️', message, tag, error, stackTrace);
  }

  static void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, '⚠️', message, tag, error, stackTrace);
  }

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, '❌', message, tag, error, stackTrace);
  }

  static void critical(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.critical, '🚨', message, tag, error, stackTrace);
  }

  static void _log(
    LogLevel level,
    String emoji,
    String message,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (level.index < minLogLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final tagPart = tag != null ? '[$tag]' : '';
    final logHeader = '$emoji $timestamp $tagPart ${level.name.toUpperCase()}:';
    
    // Format full console output
    developer.log(
      message,
      name: tag ?? 'App',
      error: error,
      stackTrace: stackTrace,
      level: _levelToValue(level),
    );

    // Print to standard stdout for easy terminal inspection in development
    // ignore: avoid_print
    print('$logHeader $message');
    if (error != null) {
      // ignore: avoid_print
      print('  Error: $error');
    }
    if (stackTrace != null) {
      // ignore: avoid_print
      print('  StackTrace:\n$stackTrace');
    }
  }

  static int _levelToValue(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
      case LogLevel.critical:
        return 2000;
    }
  }
}
