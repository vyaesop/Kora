import 'package:flutter_test/flutter_test.dart';
import 'package:kora/model/thread_message.dart';
import 'package:kora/utils/recommendation_service.dart';

ThreadMessage _thread({
  required String start,
  required String end,
  required double weight,
}) {
  return ThreadMessage(
    id: 'id',
    senderName: 'sender',
    senderProfileImageUrl: '',
    ownerId: 'owner',
    message: 'msg',
    timestamp: DateTime.now(),
    weight: weight,
    category: 'Retail',
    type: 'Food',
    start: start,
    end: end,
    packaging: 'Box',
    weightUnit: 'kg',
    startLat: 0,
    startLng: 0,
    endLat: 0,
    endLng: 0,
  );
}

void main() {
  group('RecommendationService.scoreLoad', () {
    test('rewards route fit and route token matches', () {
      final thread = _thread(
        start: 'Addis Ababa, Addis Ababa',
        end: 'Adama, Oromia',
        weight: 3000,
      );
      final score = RecommendationService.scoreLoad(
        thread: thread,
        routeFits: true,
        recentTokens: const ['Addis Ababa', 'Adama'],
        driverMaxWeightKg: 10000,
      );
      expect(score, greaterThan(60));
    });

    test('penalizes overweight loads', () {
      final thread = _thread(start: 'A', end: 'B', weight: 20000);
      final score = RecommendationService.scoreLoad(
        thread: thread,
        routeFits: false,
        recentTokens: const [],
        driverMaxWeightKg: 8000,
      );
      expect(score, lessThan(0));
    });
  });

  group('RecommendationService.scoreReturnLoad', () {
    test('strongly prefers loads that start from the destination city', () {
      final thread = _thread(
        start: 'Adama, Oromia',
        end: 'Dire Dawa, Dire Dawa',
        weight: 4000,
      );
      final score = RecommendationService.scoreReturnLoad(
        thread: thread,
        returnOrigin: 'Adama, Oromia',
        originalStart: 'Addis Ababa, Addis Ababa',
        recentTokens: const ['Dire Dawa'],
      );
      expect(score, greaterThanOrEqualTo(70));
    });

    test('rewards routes that head back toward the original start', () {
      final directReturn = _thread(
        start: 'Adama, Oromia',
        end: 'Addis Ababa, Addis Ababa',
        weight: 5000,
      );
      final unrelated = _thread(
        start: 'Adama, Oromia',
        end: 'Bahir Dar, Amhara',
        weight: 5000,
      );

      final directScore = RecommendationService.scoreReturnLoad(
        thread: directReturn,
        returnOrigin: 'Adama, Oromia',
        originalStart: 'Addis Ababa, Addis Ababa',
        recentTokens: const [],
      );
      final unrelatedScore = RecommendationService.scoreReturnLoad(
        thread: unrelated,
        returnOrigin: 'Adama, Oromia',
        originalStart: 'Addis Ababa, Addis Ababa',
        recentTokens: const [],
      );

      expect(directScore, greaterThan(unrelatedScore));
    });
  });
}
