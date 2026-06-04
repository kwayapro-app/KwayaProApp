import 'package:flutter_test/flutter_test.dart';
import 'package:kwayapro/core/utils/phone_normaliser.dart';

void main() {
  group('PhoneNormaliser', () {
    test('normalises 0772123456 to +256772123456', () {
      expect(PhoneNormaliser.normalise('0772123456'), '+256772123456');
    });

    test('leaves +256772123456 unchanged', () {
      expect(PhoneNormaliser.normalise('+256772123456'), '+256772123456');
    });

    test('throws ArgumentError for 0414123', () {
      expect(() => PhoneNormaliser.normalise('0414123'), throwsArgumentError);
    });

    test('throws ArgumentError for empty string', () {
      expect(() => PhoneNormaliser.normalise(''), throwsArgumentError);
    });

    test('normalises 772123456 to +256772123456', () {
      expect(PhoneNormaliser.normalise('772123456'), '+256772123456');
    });
  });
}
