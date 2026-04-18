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
    docId: 'doc',
    senderName: 'sender',
    senderProfileImageUrl: '',
    ownerId: 'owner',
    message: 'msg',
    timestamp: DateTime.now(),
    likes: const [],
    comments: const [],
    weight: weight,
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
}
