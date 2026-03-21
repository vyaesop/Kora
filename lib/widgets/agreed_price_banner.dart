import 'package:flutter/material.dart';

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Agreed Price: ${finalPrice.toStringAsFixed(2)} $currency',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

