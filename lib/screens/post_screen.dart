import 'package:flutter/material.dart';

import '../utils/backend_http.dart';
import '../utils/notification_helper.dart';

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

    final weight = double.tryParse(_weightController.text.trim()) ?? 0;
    if (weight <= 0) {
      NotificationHelper.showSnackBar(context, 'Weight must be greater than zero', color: Colors.red);
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
      NotificationHelper.showSnackBar(context, 'Load posted successfully!', color: Colors.green);
      _formKey.currentState?.reset();
      _messageController.clear();
      _weightController.clear();
      _startController.clear();
      _endController.clear();
      _packagingController.clear();
      setState(() {
        _type = 'General';
        _weightUnit = 'kg';
      });
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.showSnackBar(context, 'Failed to post load: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Load'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Load Description',
                    border: OutlineInputBorder(),
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
                        decoration: const InputDecoration(
                          labelText: 'Weight',
                          border: OutlineInputBorder(),
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
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: 'Load Type',
                    border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: 'Start Location',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _endController,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _packagingController,
                  decoration: const InputDecoration(
                    labelText: 'Packaging',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Post Load'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
