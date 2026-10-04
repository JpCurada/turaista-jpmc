import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/guardrail.dart';
import 'package:turaista/core/intent_model.dart';
import 'package:turaista/core/intents.dart';

/// Returns a fixed model output, or never answers when [hang] is set.
class FakeIntentModel implements IntentModel {
  FakeIntentModel(this.output, {this.hang = false});

  final String output;
  final bool hang;
  int calls = 0;

  @override
  Future<String> complete(String guestMessage) {
    calls++;
    if (hang) return Future.delayed(const Duration(days: 1), () => output);
    return Future.value(output);
  }
}

void main() {
  group('parseIntentOutput', () {
    test('reads the JSON shape, even with stray text around it', () {
      final p =
          parseIntentOutput(
            'ok {"intent": "BOOKING", "slots": {"party_size": "4", "date": "Saturday"}} done',
            'Can 4 of us come on Saturday?',
          )!;
      expect(p.intent, GuestIntent.booking);
      expect(p.slots, {'party_size': '4', 'date': 'Saturday'});
    });

    test('drops slots the model did not copy from the message', () {
      final p =
          parseIntentOutput(
            '{"intent": "PRICE", "slots": {"item": "lunch", "party_size": "12"}}',
            'How much is lunch?',
          )!;
      expect(p.slots, {'item': 'lunch'});
    });

    test('drops unknown slot names and non-string values', () {
      final p =
          parseIntentOutput(
            '{"intent": "PRICE", "slots": {"price": "350", "item": 5}}',
            'How much? 350?',
          )!;
      expect(p.slots, isEmpty);
    });

    test('bad output is null, so keywords decide', () {
      for (final raw in ['', 'PRICE', '{"intent": "REFUND"}', '{"intent": ', '[1, 2]']) {
        expect(parseIntentOutput(raw, 'x'), isNull, reason: raw);
      }
    });
  });

  group('classifyGuestMessage', () {
    test('keyword safety wins over the model', () async {
      final c = await classifyGuestMessage(
        'How much is lunch? My son has a peanut allergy.',
        model: FakeIntentModel('{"intent": "PRICE", "slots": {}}'),
      );
      expect(c.intents, containsAll([GuestIntent.price, GuestIntent.dietarySafety]));
      expect(checkGuardrail(c.intents).allowed, isFalse);
    });

    test('model safety wins over keywords', () async {
      // The metrics' one missed case for keywords-free Tagalog phrasing.
      final c = await classifyGuestMessage(
        'Magkano po? Bawal po ako sa gatas.',
        model: FakeIntentModel('{"intent": "DIETARY_SAFETY", "slots": {}}'),
      );
      expect(checkGuardrail(c.intents).allowed, isFalse);
    });

    test('the model alone never unlocks a draft', () async {
      // No keyword matches; an allowed label from the model is not enough.
      for (final message in [
        'hw much 4 the strawberry thing',
        'Can I bring my goat?',
        'Is there a spot for us? One of us is lactose-sensitive-ish.',
      ]) {
        final c = await classifyGuestMessage(
          message,
          model: FakeIntentModel('{"intent": "BOOKING", "slots": {}}'),
        );
        expect(checkGuardrail(c.intents).allowed, isFalse, reason: message);
      }
    });

    test('the model alone can make a message stricter', () async {
      final c = await classifyGuestMessage(
        'pwede po ba yung ano',
        model: FakeIntentModel('{"intent": "DIETARY_SAFETY", "slots": {}}'),
      );
      expect(c.intents, contains(GuestIntent.dietarySafety));
    });

    test('the model adds a topic only next to a keyword match', () async {
      final c = await classifyGuestMessage(
        'Can we book for Saturday?',
        model: FakeIntentModel('{"intent": "BOOKING", "slots": {"date": "Saturday"}}'),
      );
      expect(c.intents, {GuestIntent.booking});
      expect(c.source, IntentSource.both);
      expect(c.slots, {'date': 'Saturday'});
    });

    test('Tagalog food words the model missed are caught by keywords', () async {
      final c = await classifyGuestMessage(
        'Pa-book po, bawal po ako sa gatas.',
        model: FakeIntentModel('{"intent": "BOOKING", "slots": {}}'),
      );
      expect(checkGuardrail(c.intents).allowed, isFalse);
    });

    test('an out-of-profile keyword still blocks a model answer', () async {
      final c = await classifyGuestMessage(
        'May wifi po ba?',
        model: FakeIntentModel('{"intent": "PRICE", "slots": {}}'),
      );
      expect(checkGuardrail(c.intents).allowed, isFalse);
    });

    test('a slow, broken or missing model falls back to keywords', () async {
      const message = 'How much is the tour?';
      final slow = await classifyGuestMessage(
        message,
        model: FakeIntentModel('{"intent": "OTHER", "slots": {}}', hang: true),
        timeout: const Duration(milliseconds: 10),
      );
      final broken = await classifyGuestMessage(message, model: FakeIntentModel('nope'));
      final none = await classifyGuestMessage(message);
      for (final c in [slow, broken, none]) {
        expect(c.intents, {GuestIntent.price});
        expect(c.source, IntentSource.keywords);
      }
    });
  });

  test('the grammar only allows the five intents and known slots', () {
    for (final intent in GuestIntent.values) {
      expect(intentGrammar, contains('"\\"${intent.code}\\""'));
    }
    for (final slot in intentSlotNames) {
      expect(intentGrammar, contains('"\\"$slot\\""'));
    }
  });
}
