import 'dart:convert';

class ThreadMessage {
  final String id;
  final String docId;
  final String senderName;
  final String senderProfileImageUrl;
  final String message;
  final DateTime timestamp;
  final List<dynamic> likes;
  final List<dynamic> comments;
  final double weight;
  final String type;
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
    required this.docId,
    required this.senderName,
    required this.senderProfileImageUrl,
    required this.message,
    required this.timestamp,
    required this.likes,
    required this.comments,
    required this.weight,
    required this.type,
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
      'docId': docId,
      'senderName': senderName,
      'senderProfileImageUrl': senderProfileImageUrl,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'likes': likes,
      'comments': comments,
      'weight': weight,
      'type': type,
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

  factory ThreadMessage.fromMap(Map<String, dynamic> map) {
    return ThreadMessage(
      id: (map['id'] ?? '').toString(),
      docId: (map['docId'] ?? map['id'] ?? '').toString(),
      senderName: (map['senderName'] ?? map['sender'] ?? '').toString(),
      senderProfileImageUrl: (map['senderProfileImageUrl'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      timestamp: DateTime.tryParse((map['timestamp'] ?? '').toString()) ?? DateTime.now(),
      likes: List<dynamic>.from(map['likes'] ?? const []),
      comments: List<dynamic>.from(map['comments'] ?? const []),
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      type: (map['type'] ?? '').toString(),
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

