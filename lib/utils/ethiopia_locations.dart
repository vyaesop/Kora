class EthiopiaCityOption {
  final String city;
  final String zone;
  final String region;
  final List<String> aliases;

  const EthiopiaCityOption({
    required this.city,
    required this.zone,
    required this.region,
    this.aliases = const [],
  });

  String get subtitle => '$zone | $region';

  String get fullLabel => '$city, $zone, $region';
}

class ResolvedEthiopiaLocation {
  final String city;
  final String? zone;
  final String? region;

  const ResolvedEthiopiaLocation({
    required this.city,
    this.zone,
    this.region,
  });

  String get subtitle {
    final parts = [zone, region]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return parts.join(' | ');
  }

  String get fullLabel {
    final parts = [city, zone, region]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return parts.join(', ');
  }
}

const List<EthiopiaCityOption> ethiopiaCityOptions = [
  EthiopiaCityOption(
    city: 'Addis Ababa',
    zone: 'Addis Ababa Chartered City',
    region: 'Addis Ababa',
    aliases: ['Finfinne'],
  ),
  EthiopiaCityOption(
    city: 'Dire Dawa',
    zone: 'Dire Dawa City Administration',
    region: 'Dire Dawa',
  ),
  EthiopiaCityOption(
    city: 'Mekelle',
    zone: 'Mekelle Special Zone',
    region: 'Tigray',
    aliases: ['Mekele'],
  ),
  EthiopiaCityOption(
    city: 'Adama',
    zone: 'East Shewa Zone',
    region: 'Oromia',
    aliases: ['Adaama', 'Nazret', 'Nazareth'],
  ),
  EthiopiaCityOption(
    city: 'Hawassa',
    zone: 'Sidama Regional State',
    region: 'Sidama',
    aliases: ['Awassa'],
  ),
  EthiopiaCityOption(
    city: 'Bahir Dar',
    zone: 'Bahir Dar Special Zone',
    region: 'Amhara',
  ),
  EthiopiaCityOption(
    city: 'Gondar',
    zone: 'North Gondar Zone',
    region: 'Amhara',
    aliases: ['Gonder'],
  ),
  EthiopiaCityOption(
    city: 'Dessie',
    zone: 'South Wollo Zone',
    region: 'Amhara',
    aliases: ['Desse'],
  ),
  EthiopiaCityOption(
    city: 'Jimma',
    zone: 'Jimma Zone',
    region: 'Oromia',
  ),
  EthiopiaCityOption(
    city: 'Jijiga',
    zone: 'Fafan Zone',
    region: 'Somali',
    aliases: ['Jigjiga'],
  ),
  EthiopiaCityOption(
    city: 'Shashamane',
    zone: 'West Arsi Zone',
    region: 'Oromia',
    aliases: ['Shashemene'],
  ),
  EthiopiaCityOption(
    city: 'Bishoftu',
    zone: 'East Shewa Zone',
    region: 'Oromia',
    aliases: ['Debre Zeit'],
  ),
  EthiopiaCityOption(
    city: 'Wolaita Sodo',
    zone: 'Wolaita Zone',
    region: 'South Ethiopia',
    aliases: ['Wolayta Sodo', 'Sodo'],
  ),
  EthiopiaCityOption(
    city: 'Arba Minch',
    zone: 'Gamo Zone',
    region: 'South Ethiopia',
  ),
  EthiopiaCityOption(
    city: 'Hossana',
    zone: 'Hadiya Zone',
    region: 'Central Ethiopia',
    aliases: ['Hosaena', 'Hosaina', 'Hossaina'],
  ),
  EthiopiaCityOption(
    city: 'Harar',
    zone: 'Harari Region',
    region: 'Harari',
    aliases: ['Harer'],
  ),
  EthiopiaCityOption(
    city: 'Dilla',
    zone: 'Gedeo Zone',
    region: 'South Ethiopia',
  ),
  EthiopiaCityOption(
    city: 'Nekemte',
    zone: 'East Welega Zone',
    region: 'Oromia',
    aliases: ['Naqamte'],
  ),
  EthiopiaCityOption(
    city: 'Debre Birhan',
    zone: 'North Shewa Zone',
    region: 'Amhara',
  ),
  EthiopiaCityOption(
    city: 'Asella',
    zone: 'Arsi Zone',
    region: 'Oromia',
    aliases: ['Asela'],
  ),
  EthiopiaCityOption(
    city: 'Debre Markos',
    zone: 'East Gojjam Zone',
    region: 'Amhara',
    aliases: ["Debre Mark'os"],
  ),
  EthiopiaCityOption(
    city: 'Kombolcha',
    zone: 'South Wollo Zone',
    region: 'Amhara',
  ),
  EthiopiaCityOption(
    city: 'Debre Tabor',
    zone: 'South Gondar Zone',
    region: 'Amhara',
  ),
  EthiopiaCityOption(
    city: 'Adigrat',
    zone: 'Eastern Zone',
    region: 'Tigray',
  ),
  EthiopiaCityOption(
    city: 'Woldiya',
    zone: 'North Wollo Zone',
    region: 'Amhara',
    aliases: ['Weldiya'],
  ),
  EthiopiaCityOption(
    city: 'Sebeta',
    zone: 'Oromia Special Zone Surrounding Finfinne',
    region: 'Oromia',
    aliases: ['Sabata'],
  ),
  EthiopiaCityOption(
    city: 'Burayu',
    zone: 'Oromia Special Zone Surrounding Finfinne',
    region: 'Oromia',
    aliases: ['Buraayu'],
  ),
  EthiopiaCityOption(
    city: 'Ambo',
    zone: 'West Shewa Zone',
    region: 'Oromia',
  ),
  EthiopiaCityOption(
    city: 'Arsi Negele',
    zone: 'West Arsi Zone',
    region: 'Oromia',
    aliases: ['Negele Arsi'],
  ),
  EthiopiaCityOption(
    city: 'Axum',
    zone: 'Central Zone',
    region: 'Tigray',
    aliases: ['Aksum'],
  ),
  EthiopiaCityOption(
    city: 'Gambela',
    zone: 'Anuak Zone',
    region: 'Gambela',
  ),
  EthiopiaCityOption(
    city: 'Bale Robe',
    zone: 'Bale Zone',
    region: 'Oromia',
    aliases: ['Robe'],
  ),
  EthiopiaCityOption(
    city: 'Butajira',
    zone: 'Gurage Zone',
    region: 'Central Ethiopia',
  ),
  EthiopiaCityOption(
    city: 'Batu',
    zone: 'East Shewa Zone',
    region: 'Oromia',
    aliases: ['Ziway', 'Zeway'],
  ),
  EthiopiaCityOption(
    city: 'Meki',
    zone: 'East Shewa Zone',
    region: 'Oromia',
  ),
  EthiopiaCityOption(
    city: 'Mojo',
    zone: 'East Shewa Zone',
    region: 'Oromia',
  ),
  EthiopiaCityOption(
    city: 'Assosa',
    zone: 'Assosa Zone',
    region: 'Benishangul-Gumuz',
    aliases: ['Asosa'],
  ),
  EthiopiaCityOption(
    city: 'Gimbi',
    zone: 'West Welega Zone',
    region: 'Oromia',
  ),
  EthiopiaCityOption(
    city: 'Metu',
    zone: 'Illubabor Zone',
    region: 'Oromia',
  ),
  EthiopiaCityOption(
    city: 'Agaro',
    zone: 'Jimma Zone',
    region: 'Oromia',
  ),
  EthiopiaCityOption(
    city: 'Holeta',
    zone: 'West Shewa Zone',
    region: 'Oromia',
    aliases: ['Holota'],
  ),
  EthiopiaCityOption(
    city: 'Adola',
    zone: 'Guji Zone',
    region: 'Oromia',
  ),
  EthiopiaCityOption(
    city: 'Shire',
    zone: 'North Western Zone',
    region: 'Tigray',
    aliases: ['Shire Inda Selassie'],
  ),
];

String _normalizeLocationKey(String value) {
  final lower = value.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final isLetterOrDigit = RegExp(r'[a-z0-9]').hasMatch(char);
    if (isLetterOrDigit) {
      buffer.write(char);
    } else if (buffer.isNotEmpty && !buffer.toString().endsWith(' ')) {
      buffer.write(' ');
    }
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

EthiopiaCityOption? findEthiopiaCity(String? rawValue) {
  final raw = rawValue?.trim() ?? '';
  if (raw.isEmpty) return null;

  final candidates = <String>{
    raw,
    raw.split(',').first.trim(),
    raw.split('-').first.trim(),
  };
  final normalizedCandidates = candidates
      .where((value) => value.isNotEmpty)
      .map(_normalizeLocationKey)
      .where((value) => value.isNotEmpty)
      .toList();

  for (final option in ethiopiaCityOptions) {
    final names = [option.city, ...option.aliases]
        .map(_normalizeLocationKey)
        .where((value) => value.isNotEmpty)
        .toList();

    for (final candidate in normalizedCandidates) {
      if (names.contains(candidate)) {
        return option;
      }
    }
  }

  final normalizedRaw = _normalizeLocationKey(raw);
  for (final option in ethiopiaCityOptions) {
    final names = [option.city, ...option.aliases]
        .map(_normalizeLocationKey)
        .where((value) => value.isNotEmpty)
        .toList();
    if (names.any((name) =>
        normalizedRaw == name ||
        normalizedRaw.startsWith('$name ') ||
        normalizedRaw.contains(' $name ') ||
        normalizedRaw.endsWith(' $name'))) {
      return option;
    }
  }

  return null;
}

ResolvedEthiopiaLocation resolveEthiopiaLocation({
  String? city,
  String? zone,
  String? region,
  String? fallback,
}) {
  final matched = findEthiopiaCity(city ?? fallback);
  final trimmedCity = city?.trim();
  final trimmedZone = zone?.trim();
  final trimmedRegion = region?.trim();
  final trimmedFallback = fallback?.trim();
  final resolvedCity = (trimmedCity != null && trimmedCity.isNotEmpty)
      ? trimmedCity
      : matched?.city ??
          ((trimmedFallback != null && trimmedFallback.isNotEmpty)
              ? trimmedFallback
              : 'Unknown');
  final resolvedZone =
      (trimmedZone != null && trimmedZone.isNotEmpty) ? trimmedZone : matched?.zone;
  final resolvedRegion = (trimmedRegion != null && trimmedRegion.isNotEmpty)
      ? trimmedRegion
      : matched?.region;

  return ResolvedEthiopiaLocation(
    city: resolvedCity,
    zone: resolvedZone,
    region: resolvedRegion,
  );
}
