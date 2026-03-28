String formatNumber(
  num? value, {
  int minFractionDigits = 0,
  int maxFractionDigits = 2,
  bool groupThousands = false,
}) {
  final normalized = value ?? 0;
  final isNegative = normalized < 0;
  final absolute = normalized.abs();

  var text = absolute.toStringAsFixed(maxFractionDigits);
  var parts = text.split('.');
  var integerPart = parts[0];
  var fractionPart = parts.length > 1 ? parts[1] : '';

  while (fractionPart.length > minFractionDigits && fractionPart.endsWith('0')) {
    fractionPart = fractionPart.substring(0, fractionPart.length - 1);
  }

  if (groupThousands) {
    integerPart = _groupThousands(integerPart);
  }

  final result =
      fractionPart.isEmpty ? integerPart : '$integerPart.$fractionPart';
  return isNegative ? '-$result' : result;
}

String formatWeight(num? value, String unit) {
  final normalizedUnit = unit.trim();
  final formatted = formatNumber(
    value,
    minFractionDigits: 0,
    maxFractionDigits: 1,
  );
  return normalizedUnit.isEmpty ? formatted : '$formatted $normalizedUnit';
}

String formatPrice(num? value, String currency) {
  final normalizedCurrency = currency.trim();
  final formatted = formatNumber(
    value,
    minFractionDigits: 2,
    maxFractionDigits: 2,
    groupThousands: true,
  );
  return normalizedCurrency.isEmpty ? formatted : '$formatted $normalizedCurrency';
}

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    buffer.write(digits[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
