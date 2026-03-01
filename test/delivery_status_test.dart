import 'package:flutter_test/flutter_test.dart';
import 'package:Kora/utils/delivery_status.dart';

void main() {
  group('deliveryStatusLabel', () {
    test('maps canonical statuses', () {
      expect(deliveryStatusLabel('pending_bids'), 'Pending bids');
      expect(deliveryStatusLabel('accepted'), 'Accepted');
      expect(deliveryStatusLabel('driving_to_location'), 'Driving to location');
      expect(deliveryStatusLabel('picked_up'), 'Picked up');
      expect(deliveryStatusLabel('on_the_road'), 'On the road');
      expect(deliveryStatusLabel('delivered'), 'Delivered');
    });

    test('normalizes aliases', () {
      expect(deliveryStatusLabel('completed'), 'Delivered');
      expect(deliveryStatusLabel('driving'), 'Driving to location');
      expect(deliveryStatusLabel('onroad'), 'On the road');
    });

    test('handles unknown values safely', () {
      expect(deliveryStatusLabel('needs_manual_review'), 'Needs Manual Review');
      expect(deliveryStatusLabel(''), 'Unknown');
    });
  });
}
