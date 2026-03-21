import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kora/utils/experiment_service.dart';

void main() {
  group('ExperimentService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('assigns deterministic variant for same seed', () async {
      final a = await ExperimentService.getOrAssignVariant(
        experiment: 'search_ranking_v1',
        userSeed: 'user-123',
      );
      final b = await ExperimentService.getOrAssignVariant(
        experiment: 'search_ranking_v1',
        userSeed: 'user-123',
      );
      expect(a, equals(b));
      expect(['control', 'treatment'], contains(a));
    });

    test('markExposedOnce returns true only first time', () async {
      final first = await ExperimentService.markExposedOnce('exp_x');
      final second = await ExperimentService.markExposedOnce('exp_x');
      expect(first, isTrue);
      expect(second, isFalse);
    });
  });
}

