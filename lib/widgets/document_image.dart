import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class DocumentImage extends StatelessWidget {
  final String? source;
  final double borderRadius;
  final BoxFit fit;

  const DocumentImage({
    super.key,
    required this.source,
    this.borderRadius = 18,
    this.fit = BoxFit.cover,
  });

  static Uint8List? tryDecodeDataUrl(String? source) {
    final value = source?.trim() ?? '';
    if (!value.startsWith('data:image')) {
      return null;
    }

    final separatorIndex = value.indexOf(',');
    if (separatorIndex == -1) {
      return null;
    }

    try {
      return base64Decode(value.substring(separatorIndex + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = source?.trim() ?? '';
    final bytes = tryDecodeDataUrl(value);
    final isRemote = value.startsWith('http://') || value.startsWith('https://');

    final child = bytes != null
        ? Image.memory(bytes, fit: fit)
        : isRemote
            ? Image.network(
                value,
                fit: fit,
                errorBuilder: (_, __, ___) => const _DocumentPlaceholder(),
              )
            : const _DocumentPlaceholder();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }
}

class _DocumentPlaceholder extends StatelessWidget {
  const _DocumentPlaceholder();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF101B2D) : const Color(0xFFF8FAFC),
      alignment: Alignment.center,
      child: Icon(
        Icons.description_outlined,
        size: 28,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
    );
  }
}
