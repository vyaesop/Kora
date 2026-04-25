import 'backend_transport.dart';

class ErrorHandler {
  static String getMessage(Object error) {
    if (error is BackendRequestException) {
      final code = (error.payload?['code'] ?? '').toString();
      if (code == 'ENDPOINT_UNAVAILABLE') {
        return 'This feature preview is visible, but the connected backend does not support the live data route yet.';
      }
      return error.message;
    }

    final message = error.toString();
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('connection refused') ||
        lowerMessage.contains('connection failed') ||
        lowerMessage.contains('network is unreachable') ||
        lowerMessage.contains('failed host lookup')) {
      return 'Could not reach the server. Please try again in a moment.';
    }

    if (message.contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    }

    if (message.contains('401') || message.contains('Unauthorized')) {
      return 'Session expired. Please login again.';
    }

    if (message.contains('403') || message.contains('Forbidden')) {
      return 'You do not have permission to perform this action.';
    }

    if (message.contains('404') || message.contains('Not Found')) {
      return 'Resource not found.';
    }

    if (message.contains('500') || message.contains('Internal Server Error')) {
      return 'Server error. Please try again later.';
    }

    return message.replaceFirst('Exception: ', '');
  }
}
