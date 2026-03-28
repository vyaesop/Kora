import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/formatters.dart';

class AgreedPriceBanner extends StatelessWidget {
  final double finalPrice;
  final String currency;

  const AgreedPriceBanner({
    super.key,
    required this.finalPrice,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F2A1A) : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF1F5B36) : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Agreed Price: ${formatPrice(finalPrice, currency)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppPalette.darkText : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

