import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/number_check.dart';

void main() {
  test('finds numbers, grouped thousands as one', () {
    expect(numbersIn('PHP 1,200 for 12 people, 45 minutes'), ['1200', '12', '45']);
    expect(numbersIn('no numbers'), isEmpty);
  });

  test('non-breaking spaces group thousands like commas', () {
    expect(numbersIn('1\u00A0200 and 2\u202F500'), ['1200', '2500']);
  });

  test('reads full-width digits from Japanese and Chinese output', () {
    expect(numbersIn('ツアーは３５０ペソです'), ['350']);
  });

  test('same numbers in any order match', () {
    expect(numbersMatch('PHP 350, up to 12 guests', '최대 12명, 350페소'), isTrue);
    expect(numbersMatch('Thank you!', 'ありがとうございます！'), isTrue);
  });

  test('changed, dropped or added numbers do not match', () {
    expect(numbersMatch('PHP 350', '530페소'), isFalse);
    expect(numbersMatch('PHP 350 for 12', '350페소'), isFalse);
    expect(numbersMatch('PHP 350', 'PHP 350.00'), isFalse);
  });

  test('a very long run of digits is compared, not parsed', () {
    final long = '9' * 40;
    expect(numbersMatch('PHP 350', 'PHP $long'), isFalse);
    expect(numbersMatch('code $long', 'コード $long'), isTrue);
  });

  test('numbers written as words fail, which is the safe side', () {
    expect(numbersMatch('PHP 350', '三百五十ペソ'), isFalse);
  });
}
