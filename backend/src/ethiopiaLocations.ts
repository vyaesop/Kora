export type EthiopiaCityOption = {
  city: string;
  zone: string;
  region: string;
  aliases?: string[];
};

export const ethiopiaCityOptions: EthiopiaCityOption[] = [
  { city: 'Addis Ababa', zone: 'Addis Ababa Chartered City', region: 'Addis Ababa', aliases: ['Finfinne'] },
  { city: 'Dire Dawa', zone: 'Dire Dawa City Administration', region: 'Dire Dawa' },
  { city: 'Mekelle', zone: 'Mekelle Special Zone', region: 'Tigray', aliases: ['Mekele'] },
  { city: 'Adama', zone: 'East Shewa Zone', region: 'Oromia', aliases: ['Adaama', 'Nazret', 'Nazareth'] },
  { city: 'Hawassa', zone: 'Sidama Regional State', region: 'Sidama', aliases: ['Awassa'] },
  { city: 'Bahir Dar', zone: 'Bahir Dar Special Zone', region: 'Amhara' },
  { city: 'Gondar', zone: 'North Gondar Zone', region: 'Amhara', aliases: ['Gonder'] },
  { city: 'Dessie', zone: 'South Wollo Zone', region: 'Amhara', aliases: ['Desse'] },
  { city: 'Jimma', zone: 'Jimma Zone', region: 'Oromia' },
  { city: 'Jijiga', zone: 'Fafan Zone', region: 'Somali', aliases: ['Jigjiga'] },
  { city: 'Shashamane', zone: 'West Arsi Zone', region: 'Oromia', aliases: ['Shashemene'] },
  { city: 'Bishoftu', zone: 'East Shewa Zone', region: 'Oromia', aliases: ['Debre Zeit'] },
  { city: 'Wolaita Sodo', zone: 'Wolaita Zone', region: 'South Ethiopia', aliases: ['Wolayta Sodo', 'Sodo'] },
  { city: 'Arba Minch', zone: 'Gamo Zone', region: 'South Ethiopia' },
  { city: 'Hossana', zone: 'Hadiya Zone', region: 'Central Ethiopia', aliases: ['Hosaena', 'Hosaina', 'Hossaina'] },
  { city: 'Harar', zone: 'Harari Region', region: 'Harari', aliases: ['Harer'] },
  { city: 'Dilla', zone: 'Gedeo Zone', region: 'South Ethiopia' },
  { city: 'Nekemte', zone: 'East Welega Zone', region: 'Oromia', aliases: ['Naqamte'] },
  { city: 'Debre Birhan', zone: 'North Shewa Zone', region: 'Amhara' },
  { city: 'Asella', zone: 'Arsi Zone', region: 'Oromia', aliases: ['Asela'] },
  { city: 'Debre Markos', zone: 'East Gojjam Zone', region: 'Amhara', aliases: ["Debre Mark'os"] },
  { city: 'Kombolcha', zone: 'South Wollo Zone', region: 'Amhara' },
  { city: 'Debre Tabor', zone: 'South Gondar Zone', region: 'Amhara' },
  { city: 'Adigrat', zone: 'Eastern Zone', region: 'Tigray' },
  { city: 'Woldiya', zone: 'North Wollo Zone', region: 'Amhara', aliases: ['Weldiya'] },
  { city: 'Sebeta', zone: 'Oromia Special Zone Surrounding Finfinne', region: 'Oromia', aliases: ['Sabata'] },
  { city: 'Burayu', zone: 'Oromia Special Zone Surrounding Finfinne', region: 'Oromia', aliases: ['Buraayu'] },
  { city: 'Ambo', zone: 'West Shewa Zone', region: 'Oromia' },
  { city: 'Arsi Negele', zone: 'West Arsi Zone', region: 'Oromia', aliases: ['Negele Arsi'] },
  { city: 'Axum', zone: 'Central Zone', region: 'Tigray', aliases: ['Aksum'] },
  { city: 'Gambela', zone: 'Anuak Zone', region: 'Gambela' },
  { city: 'Bale Robe', zone: 'Bale Zone', region: 'Oromia', aliases: ['Robe'] },
  { city: 'Butajira', zone: 'Gurage Zone', region: 'Central Ethiopia' },
  { city: 'Batu', zone: 'East Shewa Zone', region: 'Oromia', aliases: ['Ziway', 'Zeway'] },
  { city: 'Meki', zone: 'East Shewa Zone', region: 'Oromia' },
  { city: 'Mojo', zone: 'East Shewa Zone', region: 'Oromia' },
  { city: 'Assosa', zone: 'Assosa Zone', region: 'Benishangul-Gumuz', aliases: ['Asosa'] },
  { city: 'Gimbi', zone: 'West Welega Zone', region: 'Oromia' },
  { city: 'Metu', zone: 'Illubabor Zone', region: 'Oromia' },
  { city: 'Agaro', zone: 'Jimma Zone', region: 'Oromia' },
  { city: 'Holeta', zone: 'West Shewa Zone', region: 'Oromia', aliases: ['Holota'] },
  { city: 'Adola', zone: 'Guji Zone', region: 'Oromia' },
  { city: 'Shire', zone: 'North Western Zone', region: 'Tigray', aliases: ['Shire Inda Selassie'] },
];

const normalizeLocationKey = (value: string) =>
  value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');

export const findEthiopiaCity = (rawValue: unknown): EthiopiaCityOption | null => {
  if (typeof rawValue !== 'string' || !rawValue.trim()) {
    return null;
  }

  const raw = rawValue.trim();
  const candidates = [raw, raw.split(',')[0]?.trim() ?? '', raw.split('-')[0]?.trim() ?? '']
    .filter(Boolean)
    .map(normalizeLocationKey);

  for (const option of ethiopiaCityOptions) {
    const names = [option.city, ...(option.aliases ?? [])].map(normalizeLocationKey);
    if (candidates.some((candidate) => names.includes(candidate))) {
      return option;
    }
  }

  const normalizedRaw = normalizeLocationKey(raw);
  for (const option of ethiopiaCityOptions) {
    const names = [option.city, ...(option.aliases ?? [])].map(normalizeLocationKey);
    if (
      names.some((name) =>
        normalizedRaw === name ||
        normalizedRaw.startsWith(`${name} `) ||
        normalizedRaw.includes(` ${name} `) ||
        normalizedRaw.endsWith(` ${name}`),
      )
    ) {
      return option;
    }
  }

  return null;
};

export const resolveEthiopiaLocation = ({
  city,
  zone,
  region,
  fallback,
}: {
  city?: unknown;
  zone?: unknown;
  region?: unknown;
  fallback?: unknown;
}) => {
  const matched = findEthiopiaCity(city ?? fallback);
  const cityValue =
    (typeof city === 'string' && city.trim()) ||
    matched?.city ||
    (typeof fallback === 'string' && fallback.trim()) ||
    null;
  const zoneValue =
    (typeof zone === 'string' && zone.trim()) ||
    matched?.zone ||
    null;
  const regionValue =
    (typeof region === 'string' && region.trim()) ||
    matched?.region ||
    null;

  return {
    city: cityValue,
    zone: zoneValue,
    region: regionValue,
    subtitle: [zoneValue, regionValue].filter(Boolean).join(' | '),
    label: [cityValue, zoneValue, regionValue].filter(Boolean).join(', '),
  };
};
