String normalizeDeliveryStatus(String input) {
  final key = input.toLowerCase().trim();
  if (key == 'accepted') return 'accepted';
  if (key == 'driving' || key == 'driving_to_location') return 'driving_to_location';
  if (key == 'picked' || key == 'picked_up') return 'picked_up';
  if (key == 'on_the_road' || key == 'ontheroad' || key == 'onroad') return 'on_the_road';
  if (key == 'delivered' || key == 'completed') return 'delivered';
  return key;
}

String deliveryStatusLabel(String status) {
  final normalized = normalizeDeliveryStatus(status);
  switch (normalized) {
    case 'pending_bids':
      return 'Pending bids';
    case 'accepted':
      return 'Accepted';
    case 'driving_to_location':
      return 'Driving to location';
    case 'picked_up':
      return 'Picked up';
    case 'on_the_road':
      return 'On the road';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
      return 'Cancelled';
    case 'disputed':
      return 'Disputed';
    default:
      if (normalized.isEmpty) return 'Unknown';
      final words = normalized.split('_').where((word) => word.isNotEmpty);
      return words
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
  }
}