import 'package:flutter_riverpod/flutter_riverpod.dart';

final threadProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, threadId) {
  return const Stream.empty();
});

final bidsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, threadId) {
  return const Stream.empty();
});

