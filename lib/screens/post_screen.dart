import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../utils/app_theme.dart';
import '../utils/backend_http.dart';
import '../utils/ethiopia_locations.dart';
import '../utils/error_handler.dart';
import '../utils/notification_helper.dart';
import '../utils/verification_access.dart';
import 'profile_screen.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _formKey = GlobalKey<FormState>();

  final _messageController = TextEditingController();
  final _weightController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _packagingController = TextEditingController();

  EthiopiaCityOption? _startLocation;
  EthiopiaCityOption? _endLocation;

  String _type = 'General';
  String _weightUnit = 'kg';
  bool _submitting = false;

  final _types = const [
    'General',
    'Coffee',
    'Fuel',
    'Food',
    'Fertilizer',
    'Construction Materials',
    'Heavy Machinery',
    'Livestock',
  ];
  final _units = const [
    'kg',
    'ton',
    'quintal',
    '20ft container',
    '40ft container',
    'litre',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _weightController.dispose();
    _startController.dispose();
    _endController.dispose();
    _packagingController.dispose();
    super.dispose();
  }

  Future<void> _pickCity({required bool isStart}) async {
    final selected = await showModalBottomSheet<EthiopiaCityOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _CityPickerSheet(
        title: isStart ? 'Choose departure city' : 'Choose destination city',
        selected: isStart ? _startLocation : _endLocation,
      ),
    );

    if (selected == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startLocation = selected;
        _startController.text = selected.city;
      } else {
        _endLocation = selected;
        _endController.text = selected.city;
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final allowed = await VerificationAccess.ensureVerifiedForAction(
      context,
      expectedUserType: 'Cargo',
      actionLabel: 'post loads',
      onOpenProfile: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
      },
    );
    if (!allowed || !mounted) return;
    if (!_formKey.currentState!.validate()) return;

    final weight = double.tryParse(_weightController.text.trim());
    if (weight == null || weight <= 0) {
      NotificationHelper.showSnackBar(
        context,
        AppLocalizations.of(context).tr('weightMustBeGreater'),
        color: Colors.red,
      );
      return;
    }

    if (_startLocation == null || _endLocation == null) {
      NotificationHelper.showSnackBar(
        context,
        'Choose both departure and destination cities from the list.',
        color: Colors.red,
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await BackendHttp.request(
        path: '/api/threads',
        method: 'POST',
        body: {
          'message': _messageController.text.trim(),
          'weight': weight,
          'type': _type,
          'start': _startLocation!.city,
          'end': _endLocation!.city,
          'startCity': _startLocation!.city,
          'startZone': _startLocation!.zone,
          'startRegion': _startLocation!.region,
          'endCity': _endLocation!.city,
          'endZone': _endLocation!.zone,
          'endRegion': _endLocation!.region,
          'packaging': _packagingController.text.trim(),
          'weightUnit': _weightUnit,
          'deliveryStatus': 'pending_bids',
          'startLat': _startLocation?.latitude,
          'startLng': _startLocation?.longitude,
          'endLat': _endLocation?.latitude,
          'endLng': _endLocation?.longitude,
        },
      );

      if (!mounted) return;
      final localizations = AppLocalizations.of(context);

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.tr('loadPostedSuccess')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMsg = ErrorHandler.getMessage(e);
      NotificationHelper.showSnackBar(
        context,
        '${AppLocalizations.of(context).tr('loadPostFailed')}: $errorMsg',
        color: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.tr('postLoad'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? AppPalette.heroGradientDark
                        : const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.tr('shareLoadDetails'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use the fixed city list so route details stay consistent across feed, detail, and admin tools.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withAlpha((0.78 * 255).round()),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: localizations.tr('loadDescription'),
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                  minLines: 2,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: localizations.tr('weight'),
                          prefixIcon: const Icon(Icons.scale_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Required';
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed <= 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _weightUnit,
                        decoration: InputDecoration(
                          labelText: localizations.tr('unit'),
                          prefixIcon: const Icon(Icons.straighten_outlined),
                        ),
                        items: _units
                            .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null)
                            setState(() => _weightUnit = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: InputDecoration(
                    labelText: localizations.tr('loadType'),
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                  items: _types
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 16),
                _CityField(
                  controller: _startController,
                  label: localizations.tr('departure'),
                  icon: Icons.trip_origin,
                  helperText: _startLocation == null
                      ? 'Choose from major Ethiopian cities.'
                      : _startLocation!.subtitle,
                  onTap: () => _pickCity(isStart: true),
                ),
                const SizedBox(height: 12),
                _CityField(
                  controller: _endController,
                  label: localizations.tr('destination'),
                  icon: Icons.flag_outlined,
                  helperText: _endLocation == null
                      ? 'Choose from major Ethiopian cities.'
                      : _endLocation!.subtitle,
                  onTap: () => _pickCity(isStart: false),
                ),
                if (_startLocation != null && _endLocation != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppPalette.darkSurfaceRaised
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? AppPalette.darkOutline
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route preview',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _RoutePreviewRow(
                          label: 'Departure',
                          value: _startLocation!.city,
                          subtitle: _startLocation!.subtitle,
                          color: const Color(0xFF5B8C85),
                        ),
                        const SizedBox(height: 12),
                        Divider(
                          color: isDark
                              ? AppPalette.darkOutline
                              : const Color(0xFFE2E8F0),
                          height: 1,
                        ),
                        const SizedBox(height: 12),
                        _RoutePreviewRow(
                          label: 'Destination',
                          value: _endLocation!.city,
                          subtitle: _endLocation!.subtitle,
                          color: const Color(0xFFC28C5A),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _packagingController,
                  decoration: InputDecoration(
                    labelText: localizations.tr('packaging'),
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          localizations.tr('postLoad'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CityField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String helperText;
  final IconData icon;
  final VoidCallback onTap;

  const _CityField({
    required this.controller,
    required this.label,
    required this.helperText,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon),
        suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }
        return null;
      },
    );
  }
}

class _RoutePreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _RoutePreviewRow({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withAlpha((0.14 * 255).round()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            label == 'Departure' ? Icons.trip_origin : Icons.place_outlined,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isDark ? AppPalette.darkTextSoft : Colors.black54,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppPalette.darkTextSoft
                      : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CityPickerSheet extends StatefulWidget {
  final String title;
  final EthiopiaCityOption? selected;

  const _CityPickerSheet({required this.title, required this.selected});

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final _searchController = TextEditingController();

  List<EthiopiaCityOption> get _results {
    final query = _searchController.text.trim().toLowerCase();
    final sorted = [...ethiopiaCityOptions]
      ..sort((a, b) => a.city.compareTo(b.city));
    if (query.isEmpty) {
      return sorted;
    }
    return sorted.where((option) {
      final haystack =
          '${option.city} ${option.zone} ${option.region} ${option.aliases.join(' ')}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppPalette.darkOutline
                        : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Search the fixed city list to keep route analytics and route details consistent.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppPalette.darkTextSoft
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search city, zone, or region',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => Divider(
                    color: isDark
                        ? AppPalette.darkOutline
                        : const Color(0xFFE2E8F0),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final option = _results[index];
                    final isSelected = option.city == widget.selected?.city;
                    return ListTile(
                      onTap: () => Navigator.of(context).pop(option),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppPalette.accent.withAlpha(
                                  (0.18 * 255).round(),
                                )
                              : (isDark
                                    ? AppPalette.darkSurfaceRaised
                                    : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.location_city_rounded,
                          color: isSelected
                              ? AppPalette.accent
                              : AppPalette.accentWarm,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        option.city,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(option.subtitle),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppPalette.accent,
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
