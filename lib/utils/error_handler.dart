import 'dart:io';

class ErrorHandler {
  static String getMessage(Object error) {
    String message = error.toString();
    
    if (error is SocketException) {
      return 'No internet connection. Please check your network.';
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

    if (message.contains('Connection refused')) {
      return 'Could not connect to server.';
    }

    // Clean up common prefix
    return message.replaceFirst('Exception: ', '');
  }
}
