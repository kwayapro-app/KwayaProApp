class PhoneNormaliser {
  static String normalise(String input) {
    // Remove all non-numeric characters except leading +
    String digitsOnly = input.replaceAll(RegExp(r'[^\d+]'), '');

    if (digitsOnly.startsWith('+256')) {
      if (digitsOnly.length != 13) {
        throw ArgumentError('Invalid phone number length');
      }
      return digitsOnly;
    }

    if (digitsOnly.startsWith('0')) {
      digitsOnly = digitsOnly.substring(1);
    }

    if (digitsOnly.length == 9) {
      return '+256$digitsOnly';
    }

    throw ArgumentError('Invalid phone number length');
  }
}
