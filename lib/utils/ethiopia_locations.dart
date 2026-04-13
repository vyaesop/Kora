import 'dart:math' as math;

class EthiopiaCityOption {
  final String city;
  final String zone;
  final String region;
  final List<String> aliases;
  final double? latitude;
  final double? longitude;

  const EthiopiaCityOption({
    required this.city,
    required this.zone,
    required this.region,
    this.aliases = const [],
    this.latitude,
    this.longitude,
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
    latitude: 9.0272,
    longitude: 38.7369,
  ),
  EthiopiaCityOption(
    city: 'Dire Dawa',
    zone: 'Dire Dawa City Administration',
    region: 'Dire Dawa',
    latitude: 9.5833,
    longitude: 41.8667,
  ),
  EthiopiaCityOption(
    city: 'Mekelle',
    zone: 'Mekelle Special Zone',
    region: 'Tigray',
    aliases: ['Mekele'],
    latitude: 13.4833,
    longitude: 39.4667,
  ),
  EthiopiaCityOption(
    city: 'Adama',
    zone: 'East Shewa Zone',
    region: 'Oromia',
    aliases: ['Adaama', 'Nazret', 'Nazareth'],
    latitude: 8.54,
    longitude: 39.27,
  ),
  EthiopiaCityOption(
    city: 'Hawassa',
    zone: 'Sidama Regional State',
    region: 'Sidama',
    aliases: ['Awassa'],
    latitude: 7.0621,
    longitude: 38.476,
  ),
  EthiopiaCityOption(
    city: 'Bahir Dar',
    zone: 'Bahir Dar Special Zone',
    region: 'Amhara',
    latitude: 11.585,
    longitude: 37.39,
  ),
  EthiopiaCityOption(
    city: 'Gondar',
    zone: 'North Gondar Zone',
    region: 'Amhara',
    aliases: ['Gonder'],
    latitude: 12.6,
    longitude: 37.4667,
  ),
  EthiopiaCityOption(
    city: 'Dessie',
    zone: 'South Wollo Zone',
    region: 'Amhara',
    aliases: ['Desse'],
    latitude: 11.1333,
    longitude: 39.6333,
  ),
  EthiopiaCityOption(
    city: 'Jimma',
    zone: 'Jimma Zone',
    region: 'Oromia',
    latitude: 7.6667,
    longitude: 36.8333,
  ),
  EthiopiaCityOption(
    city: 'Jijiga',
    zone: 'Fafan Zone',
    region: 'Somali',
    aliases: ['Jigjiga'],
    latitude: 9.35,
    longitude: 42.8,
  ),
  EthiopiaCityOption(
    city: 'Shashamane',
    zone: 'West Arsi Zone',
    region: 'Oromia',
    aliases: ['Shashemene'],
    latitude: 7.2,
    longitude: 38.6,
  ),
  EthiopiaCityOption(
    city: 'Bishoftu',
    zone: 'East Shewa Zone',
    region: 'Oromia',
    aliases: ['Debre Zeit'],
    latitude: 8.75,
    longitude: 38.9833,
  ),
  EthiopiaCityOption(
    city: 'Wolaita Sodo',
    zone: 'Wolaita Zone',
    region: 'South Ethiopia',
    aliases: ['Wolayta Sodo', 'Sodo'],
    latitude: 6.86,
    longitude: 37.76,
  ),
  EthiopiaCityOption(
    city: 'Arba Minch',
    zone: 'Gamo Zone',
    region: 'South Ethiopia',
    latitude: 6.0333,
    longitude: 37.55,
  ),
  EthiopiaCityOption(
    city: 'Hossana',
    zone: 'Hadiya Zone',
    region: 'Central Ethiopia',
    aliases: ['Hosaena', 'Hosaina', 'Hossaina'],
    latitude: 7.55,
    longitude: 37.85,
  ),
  EthiopiaCityOption(
    city: 'Harar',
    zone: 'Harari Region',
    region: 'Harari',
    aliases: ['Harer'],
    latitude: 9.32,
    longitude: 42.15,
  ),
  EthiopiaCityOption(
    city: 'Dilla',
    zone: 'Gedeo Zone',
    region: 'South Ethiopia',
    latitude: 6.41,
    longitude: 38.31,
  ),
  EthiopiaCityOption(
    city: 'Nekemte',
    zone: 'East Welega Zone',
    region: 'Oromia',
    aliases: ['Naqamte'],
    latitude: 9.0833,
    longitude: 36.55,
  ),
  EthiopiaCityOption(
    city: 'Debre Birhan',
    zone: 'North Shewa Zone',
    region: 'Amhara',
    latitude: 9.6804,
    longitude: 39.53,
  ),
  EthiopiaCityOption(
    city: 'Asella',
    zone: 'Arsi Zone',
    region: 'Oromia',
    aliases: ['Asela'],
    latitude: 7.95,
    longitude: 39.12,
  ),
  EthiopiaCityOption(
    city: 'Debre Markos',
    zone: 'East Gojjam Zone',
    region: 'Amhara',
    aliases: ["Debre Mark'os"],
    latitude: 10.34,
    longitude: 37.72,
  ),
  EthiopiaCityOption(
    city: 'Kombolcha',
    zone: 'South Wollo Zone',
    region: 'Amhara',
    latitude: 11.08,
    longitude: 39.74,
  ),
  EthiopiaCityOption(
    city: 'Debre Tabor',
    zone: 'South Gondar Zone',
    region: 'Amhara',
    latitude: 11.85,
    longitude: 38.02,
  ),
  EthiopiaCityOption(
    city: 'Adigrat',
    zone: 'Eastern Zone',
    region: 'Tigray',
    latitude: 14.28,
    longitude: 39.45,
  ),
  EthiopiaCityOption(
    city: 'Woldiya',
    zone: 'North Wollo Zone',
    region: 'Amhara',
    aliases: ['Weldiya'],
    latitude: 11.83,
    longitude: 39.6,
  ),
  EthiopiaCityOption(
    city: 'Sebeta',
    zone: 'Oromia Special Zone Surrounding Finfinne',
    region: 'Oromia',
    aliases: ['Sabata'],
    latitude: 8.92,
    longitude: 38.62,
  ),
  EthiopiaCityOption(
    city: 'Burayu',
    zone: 'Oromia Special Zone Surrounding Finfinne',
    region: 'Oromia',
    aliases: ['Buraayu'],
    latitude: 9.02,
    longitude: 38.58,
  ),
  EthiopiaCityOption(
    city: 'Ambo',
    zone: 'West Shewa Zone',
    region: 'Oromia',
    latitude: 8.98,
    longitude: 37.85,
  ),
  EthiopiaCityOption(
    city: 'Arsi Negele',
    zone: 'West Arsi Zone',
    region: 'Oromia',
    aliases: ['Negele Arsi'],
    latitude: 7.35,
    longitude: 38.7,
  ),
  EthiopiaCityOption(
    city: 'Axum',
    zone: 'Central Zone',
    region: 'Tigray',
    aliases: ['Aksum'],
    latitude: 14.12,
    longitude: 38.72,
  ),
  EthiopiaCityOption(
    city: 'Gambela',
    zone: 'Anuak Zone',
    region: 'Gambela',
    latitude: 8.25,
    longitude: 34.58,
  ),
  EthiopiaCityOption(
    city: 'Bale Robe',
    zone: 'Bale Zone',
    region: 'Oromia',
    aliases: ['Robe'],
    latitude: 7.12,
    longitude: 40.0,
  ),
  EthiopiaCityOption(
    city: 'Butajira',
    zone: 'Gurage Zone',
    region: 'Central Ethiopia',
    latitude: 8.12,
    longitude: 38.37,
  ),
  EthiopiaCityOption(
    city: 'Batu',
    zone: 'East Shewa Zone',
    region: 'Oromia',
    aliases: ['Ziway', 'Zeway'],
    latitude: 7.93,
    longitude: 38.72,
  ),
  EthiopiaCityOption(
    city: 'Meki',
    zone: 'East Shewa Zone',
    region: 'Oromia',
    latitude: 8.15,
    longitude: 38.82,
  ),
  EthiopiaCityOption(
    city: 'Mojo',
    zone: 'East Shewa Zone',
    region: 'Oromia',
    latitude: 8.59,
    longitude: 39.12,
  ),
  EthiopiaCityOption(
    city: 'Assosa',
    zone: 'Assosa Zone',
    region: 'Benishangul-Gumuz',
    aliases: ['Asosa'],
    latitude: 10.07,
    longitude: 34.53,
  ),
  EthiopiaCityOption(
    city: 'Gimbi',
    zone: 'West Welega Zone',
    region: 'Oromia',
    latitude: 9.17,
    longitude: 35.83,
  ),
  EthiopiaCityOption(
    city: 'Metu',
    zone: 'Illubabor Zone',
    region: 'Oromia',
    latitude: 8.3,
    longitude: 35.58,
  ),
  EthiopiaCityOption(
    city: 'Agaro',
    zone: 'Jimma Zone',
    region: 'Oromia',
    latitude: 7.85,
    longitude: 36.65,
  ),
  EthiopiaCityOption(
    city: 'Holeta',
    zone: 'West Shewa Zone',
    region: 'Oromia',
    aliases: ['Holota'],
    latitude: 9.06,
    longitude: 38.5,
  ),
  EthiopiaCityOption(
    city: 'Adola',
    zone: 'Guji Zone',
    region: 'Oromia',
    latitude: 5.87,
    longitude: 38.97,
  ),
  EthiopiaCityOption(
    city: 'Shire',
    zone: 'North Western Zone',
    region: 'Tigray',
    aliases: ['Shire Inda Selassie'],
    latitude: 14.1,
    longitude: 38.28,
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

class EthiopiaCityMatch {
  final EthiopiaCityOption city;
  final double distanceKm;

  const EthiopiaCityMatch({
    required this.city,
    required this.distanceKm,
  });
}

EthiopiaCityMatch? findNearestEthiopiaCity({
  required double latitude,
  required double longitude,
  double maxDistanceKm = 80,
}) {
  EthiopiaCityMatch? best;

  for (final option in ethiopiaCityOptions) {
    final lat = option.latitude;
    final lng = option.longitude;
    if (lat == null || lng == null) continue;

    final distance = _haversineKm(latitude, longitude, lat, lng);
    if (distance > maxDistanceKm) continue;

    if (best == null || distance < best.distanceKm) {
      best = EthiopiaCityMatch(city: option, distanceKm: distance);
    }
  }

  return best;
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
      (math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2));
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * (3.141592653589793 / 180.0);
