import 'dart:convert';

class ThreadMessage {
  final String id;
  final String senderName;
  final String senderProfileImageUrl;
  final String ownerId;
  final String message;
  final DateTime timestamp;
  final double weight;
  final String type;
  final String category;
  final String start;
  final String end;
  final String packaging;
  final String weightUnit;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final String? deliveryStatus;

  const ThreadMessage({
    required this.id,
    required this.senderName,
    required this.senderProfileImageUrl,
    required this.ownerId,
    required this.message,
    required this.timestamp,
    required this.weight,
    required this.type,
    required this.category,
    required this.start,
    required this.end,
    required this.packaging,
    required this.weightUnit,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    this.deliveryStatus,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'senderName': senderName,
      'senderProfileImageUrl': senderProfileImageUrl,
      'ownerId': ownerId,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'weight': weight,
      'type': type,
      'category': category,
      'start': start,
      'end': end,
      'packaging': packaging,
      'weightUnit': weightUnit,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'deliveryStatus': deliveryStatus,
    };
  }

  factory ThreadMessage.fromApiMap(Map<String, dynamic> row) {
    final owner = row['owner'] is Map<String, dynamic>
        ? row['owner'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return ThreadMessage(
      id: (row['id'] ?? '').toString(),
      senderName: (owner['name'] ?? row['senderName'] ?? 'Unknown').toString(),
      senderProfileImageUrl:
          (owner['profileImageUrl'] ?? row['senderProfileImageUrl'] ?? '')
              .toString(),
      ownerId: (row['ownerId'] ?? owner['id'] ?? '').toString(),
      message: (row['message'] ?? '').toString(),
      timestamp:
          DateTime.tryParse(
            (row['createdAt'] ?? row['timestamp'] ?? '').toString(),
          ) ??
          DateTime.now(),
      weight: (row['weight'] as num?)?.toDouble() ?? 0,
      type: (row['type'] ?? '').toString(),
      category: (row['category'] ?? '').toString(),
      start: (row['start'] ?? '').toString(),
      end: (row['end'] ?? '').toString(),
      packaging: (row['packaging'] ?? '').toString(),
      weightUnit: (row['weightUnit'] ?? 'kg').toString(),
      startLat: (row['startLat'] as num?)?.toDouble() ?? 0,
      startLng: (row['startLng'] as num?)?.toDouble() ?? 0,
      endLat: (row['endLat'] as num?)?.toDouble() ?? 0,
      endLng: (row['endLng'] as num?)?.toDouble() ?? 0,
      deliveryStatus: row['deliveryStatus']?.toString(),
    );
  }

  factory ThreadMessage.fromMap(Map<String, dynamic> map) {
    return ThreadMessage(
      id: (map['id'] ?? map['docId'] ?? '').toString(),
      senderName: (map['senderName'] ?? map['sender'] ?? '').toString(),
      senderProfileImageUrl: (map['senderProfileImageUrl'] ?? '').toString(),
      ownerId: (map['ownerId'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      timestamp:
          DateTime.tryParse((map['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      type: (map['type'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      start: (map['start'] ?? '').toString(),
      end: (map['end'] ?? '').toString(),
      packaging: (map['packaging'] ?? '').toString(),
      weightUnit: (map['weightUnit'] ?? '').toString(),
      startLat: (map['startLat'] as num?)?.toDouble() ?? 0.0,
      startLng: (map['startLng'] as num?)?.toDouble() ?? 0.0,
      endLat: (map['endLat'] as num?)?.toDouble() ?? 0.0,
      endLng: (map['endLng'] as num?)?.toDouble() ?? 0.0,
      deliveryStatus: map['deliveryStatus']?.toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ThreadMessage.fromJson(String source) =>
      ThreadMessage.fromMap(json.decode(source) as Map<String, dynamic>);
}
