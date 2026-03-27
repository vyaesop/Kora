import 'package:kora/utils/error_telemetry.dart';

import 'backend_http.dart';

class FirestoreService {
  static const List<String> _deliveryFlow = [
    'accepted',
    'driving_to_location',
    'picked_up',
    'on_the_road',
    'delivered',
  ];

  Future<Map<String, dynamic>> _authedRequest({
    required String path,
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    return BackendHttp.request(
      path: path,
      method: method,
      body: body,
      forceRefresh: true,
    );
  }

  Future<String> placeBid({
    required String threadId,
    required double bidAmount,
    required String currency,
    required String carrierNotes,
  }) {
    return upsertMyBid(
      threadId: threadId,
      bidAmount: bidAmount,
      currency: currency,
      carrierNotes: carrierNotes,
    );
  }

  Future<String> upsertMyBid({
    required String threadId,
    required double bidAmount,
    required String currency,
    required String carrierNotes,
  }) async {
    if (bidAmount <= 0) {
      throw Exception('Bid amount must be greater than zero.');
    }

    try {
      final result = await _authedRequest(
        path: '/api/threads/$threadId/my-bid',
        method: 'PUT',
        body: {
          'amount': bidAmount,
          'currency': currency,
          'carrierNotes': carrierNotes,
        },
      );

      final bid = result['bid'] as Map<String, dynamic>? ?? const {};
      final bidId = (bid['id'] ?? '').toString();
      if (bidId.isEmpty) {
        throw Exception('Bid was not saved correctly.');
      }

      await ErrorTelemetry.logEvent(
        feature: 'marketplace',
        name: 'bid_upserted',
        metadata: {'threadId': threadId},
      );

      return bidId;
    } catch (e, st) {
      await ErrorTelemetry.log(
        feature: 'marketplace',
        operation: 'upsert_bid',
        error: e,
        stackTrace: st,
        metadata: {'threadId': threadId},
      );
      rethrow;
    }
  }

  Future<void> updateDriverDeliveryStatus({
    required String threadId,
    required String nextStatus,
  }) async {
    if (!_deliveryFlow.contains(nextStatus)) {
      throw Exception('Unknown delivery status: $nextStatus');
    }

    try {
      await _authedRequest(
        path: '/api/threads/$threadId/delivery/status',
        method: 'PATCH',
        body: {'nextStatus': nextStatus},
      );
    } catch (e, st) {
      await ErrorTelemetry.log(
        feature: 'shipment',
        operation: 'update_driver_delivery_status',
        error: e,
        stackTrace: st,
        metadata: {'threadId': threadId, 'nextStatus': nextStatus},
      );
      rethrow;
    }

    await ErrorTelemetry.logEvent(
      feature: 'shipment',
      name: 'driver_status_updated',
      metadata: {'threadId': threadId, 'status': nextStatus},
    );
  }

  Future<void> deleteBid({
    required String threadId,
    required String bidId,
  }) async {
    await _authedRequest(
      path: '/api/threads/$threadId/bids/$bidId',
      method: 'DELETE',
    );
  }

  Future<void> acceptBid({
    required String threadId,
    required String bidId,
    required String acceptedCarrierId,
    required double finalPrice,
    bool closeBidding = false,
  }) async {
    if (finalPrice <= 0) {
      throw Exception('Final price must be greater than zero.');
    }

    try {
      await _authedRequest(
        path: '/api/threads/$threadId/bids/$bidId/accept',
        method: 'PATCH',
        body: {
          'acceptedCarrierId': acceptedCarrierId,
          'finalPrice': finalPrice,
          'closeBidding': closeBidding,
        },
      );
    } catch (e, st) {
      await ErrorTelemetry.log(
        feature: 'marketplace',
        operation: 'accept_bid',
        error: e,
        stackTrace: st,
        metadata: {'threadId': threadId, 'bidId': bidId},
      );
      rethrow;
    }

    await ErrorTelemetry.logEvent(
      feature: 'marketplace',
      name: 'bid_accepted',
      metadata: {'threadId': threadId, 'bidId': bidId, 'closeBidding': closeBidding},
    );
  }
}

