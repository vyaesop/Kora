import 'package:flutter/material.dart';

import '../utils/backend_http.dart';
import '../utils/notification_helper.dart';
import '../app_localizations.dart';
import '../utils/error_handler.dart';

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

  String _type = 'General';
  String _weightUnit = 'kg';
  bool _submitting = false;

  final _types = const ['General', 'Fragile', 'Heavy', 'Food', 'Electronics', 'Other'];
  final _units = const ['kg', 'ton'];

  @override
  void dispose() {
    _messageController.dispose();
    _weightController.dispose();
    _startController.dispose();
    _endController.dispose();
    _packagingController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
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

    setState(() => _submitting = true);

    try {
      await BackendHttp.request(
        path: '/api/threads',
        method: 'POST',
        body: {
          'message': _messageController.text.trim(),
          'weight': weight,
          'type': _type,
          'start': _startController.text.trim(),
          'end': _endController.text.trim(),
          'packaging': _packagingController.text.trim(),
          'weightUnit': _weightUnit,
          'deliveryStatus': 'pending_bids',
          'startLat': 0,
          'startLng': 0,
          'endLat': 0,
          'endLng': 0,
        },
      );

      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      
      // Navigate to home/feed instead of just popping
      // This gives better feedback as the user sees their new post
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
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.tr('postLoad')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.tr('shareLoadDetails'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localizations.tr('shareLoadDetailsHint'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: localizations.tr('weight'),
                          prefixIcon: const Icon(Icons.scale_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Required';
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
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _weightUnit = value);
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _startController,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.addressCity],
                  decoration: InputDecoration(
                    labelText: localizations.tr('startLocation'),
                    helperText: localizations.tr('startLocationHint'),
                    prefixIcon: const Icon(Icons.trip_origin),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return localizations.tr('required');
                    }
                    if (value.trim().length < 3) {
                      return localizations.tr('required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _endController,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.addressCity],
                  decoration: InputDecoration(
                    labelText: localizations.tr('destination'),
                    helperText: localizations.tr('destinationHint'),
                    prefixIcon: const Icon(Icons.flag_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return localizations.tr('required');
                    }
                    if (value.trim().length < 3) {
                      return localizations.tr('required');
                    }
                    return null;
                  },
                ),
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

