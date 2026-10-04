import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/guardrail.dart';
import 'package:turaista/core/intents.dart';

bool blocked(String text) => !checkGuardrail(classifyKeywords(text)).allowed;

void main() {
  const cases = <(String, GuestIntent)>[
    ('How much is the tour?', GuestIntent.price),
    ('안녕하세요, 가격은 얼마인가요?', GuestIntent.price),
    ('ツアーの料金はいくらですか？', GuestIntent.price),
    ('Can we book for Saturday?', GuestIntent.booking),
    ('My son has a severe peanut allergy', GuestIntent.dietarySafety),
    ('How do we get there from Baguio?', GuestIntent.directions),
  ];

  for (final (text, expected) in cases) {
    test('classifies "$text" as ${expected.code}', () {
      expect(classifyKeywords(text), contains(expected));
    });
  }

  test('unknown questions are OTHER', () {
    expect(classifyKeywords('Do you like dogs?'), {GuestIntent.other});
    expect(classifyKeywords('Hello!'), {GuestIntent.other});
  });

  test('words inside other words do not match', () {
    // 'fee' in coffee, 'book' in Facebook, 'rate' in separate, 'road' in broad.
    expect(classifyKeywords('We love coffee'), isNot(contains(GuestIntent.price)));
    expect(classifyKeywords('I found you on Facebook'), isNot(contains(GuestIntent.booking)));
    expect(classifyKeywords('Two separate groups'), isNot(contains(GuestIntent.price)));
    expect(classifyKeywords('A broad view'), isNot(contains(GuestIntent.directions)));
    // Korean 아이스 (iced) is not 아이 (child).
    expect(classifyKeywords('아이스 커피 가격이 얼마예요?'), {GuestIntent.price});
  });

  group('safety questions are blocked in every guest language', () {
    const safety = [
      'Is it OK for a diabetic?',
      'Any shellfish in the lunch?',
      'Is the trail safe for kids?',
      'My wife is pregnant',
      'He uses a wheelchair',
      'peanut alergy', // typo
      'Ligtas ba para sa mga bata?',
      '아이들한테 안전한가요?',
      '견과류 들어가나요?',
      '妊娠中です',
      'ハラールに対応していますか？',
      '我们是素食者',
      '有花生吗？',
    ];
    for (final text in safety) {
      test(text, () {
        expect(classifyKeywords(text), contains(GuestIntent.dietarySafety));
        expect(blocked(text), isTrue);
      });
    }
  });

  group('a safety or unknown topic inside an allowed question blocks the message', () {
    const mixed = [
      'How much is the lunch? My mother is diabetic.',
      'Can we bring our dog? How much is the entrance fee?',
      'Do you accept GCash for the tour price?',
      '아이 둘이랑 가요. 가격은요?',
      '妊娠中ですが、料金を教えてください。',
      '可以预订吗？我奶奶80岁了。',
    ];
    for (final text in mixed) {
      test(text, () {
        final intents = classifyKeywords(text);
        expect(intents.length, greaterThan(1), reason: 'the allowed part is still seen');
        expect(blocked(text), isTrue);
      });
    }
  });

  group('age, family and care needs without a classic safety word are blocked', () {
    const cases = [
      'Can my 3-year-old come? How much?',
      'Is it okay for my grandma? Price?',
      'We have a stroller. How much is the entrance?',
      '7살 아들이랑 가요, 가격 얼마예요?',
      '3歳の息子がいます。料金は?',
      '带着3岁的女儿，多少钱？',
      'ハラルですか？料金も教えて',
      'Is the lunch ok for celiac? price?',
      'Magkano po? Kasama ko si lola.',
    ];
    for (final text in cases) {
      test(text, () => expect(blocked(text), isTrue));
    }
  });

  group('payment and logistics questions are blocked, not half answered', () {
    const cases = [
      'How much is it and can I pay online?',
      'Can you pick us up from Baguio? How do we get to the farm?',
      '가격이 얼마예요? 계좌이체 되나요?',
      '料金はいくらですか？現金のみですか？',
      '多少钱？可以用支付宝吗？',
    ];
    for (final text in cases) {
      test(text, () => expect(blocked(text), isTrue));
    }
  });

  group('questions about places and services outside the farm are blocked', () {
    const cases = [
      'How far is the nearest hospital?',
      'Where is the nearest ATM?',
      'How much is a bus ticket from Manila?',
      'Is the road OK for a van?',
      '호텔 주소가 어떻게 되나요',
      'Can we stay 2 nights? price',
      'Please tell me how to pay and the price',
    ];
    for (final text in cases) {
      test(text, () => expect(blocked(text), isTrue));
    }
  });

  group('questions without a question mark still count', () {
    const cases = [
      '입장료 얼마예요 점심 포함인가요',
      '入場料はいくらですか。昼食は付いていますか',
      '门票多少钱 有导游吗',
      'How much is it. Do you have a guide',
      'How much is the tour? Do you have a gift shop?)', // trailing bracket
      'Can I book for my aunt, ages 4 and 6?',
      '魚は大丈夫ですか。予約したいです',
    ];
    for (final text in cases) {
      test(text, () => expect(blocked(text), isTrue));
    }
  });

  test('abbreviations and decimals do not break a question apart', () {
    expect(blocked('Can we book at 3 p.m. on Saturday?'), isFalse);
    expect(blocked('Is the tour 1.5 hours? How much is it?'), isTrue, reason: 'duration unknown');
    expect(blocked('Can we book 2 months ahead?'), isFalse, reason: 'not an age');
    expect(blocked('Is it free?'), isFalse);
  });

  test('a question no keyword can place blocks the message', () {
    // "Do you have a gift shop?" has no keyword at all; it must not be dropped.
    expect(classifyKeywords('How much is the tour? Do you have a gift shop?'), {
      GuestIntent.price,
      GuestIntent.other,
    });
    // Statements without a question mark are not questions.
    expect(blocked('Hello, we are 4 friends. Can we book for Saturday?'), isFalse);
  });

  test('plain allowed questions still get a draft', () {
    for (final text in [
      'whats the pric for the coffee tour?',
      'Is it possible to reserve for Sunday?',
      'Which jeepney gets to your farm?',
      'Where are you located? How much is the entrance fee?',
      'We love coffee! How much is the tour?',
      '아이스 커피 가격이 얼마예요?',
      '딸기 따기 체험 가격이 얼마예요?', // 딸기 = strawberry, not 딸 = daughter
      '예약 준비가 필요한가요? 가격은 얼마예요?', // 준비가 is not 비가 (rain)
      '来週の月曜日に2名で予約できますか？',
      '从碧瑶怎么去你们的农场？',
      'Magkano po ang tour?',
    ]) {
      expect(blocked(text), isFalse, reason: text);
    }
  });
}
