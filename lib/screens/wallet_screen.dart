import 'package:flutter/material.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/backend_http.dart';
import 'package:kora/utils/backend_transport.dart';
import 'package:kora/utils/error_handler.dart';
import 'package:kora/utils/notification_center_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final BackendAuthService _authService = BackendAuthService();

  bool _loading = true;
  bool _creatingTopUp = false;
  bool _previewMode = false;
  bool _showingCachedData = false;
  String? _error;
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _pendingOrders = const [];
  List<Map<String, dynamic>> _transactions = const [];
  bool _telebirrConfigured = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        BackendHttp.request(
          path: '/api/wallet',
          forceRefresh: forceRefresh,
        ),
        BackendHttp.request(
          path: '/api/wallet/transactions?limit=30',
          forceRefresh: forceRefresh,
        ),
      ]);

      if (!mounted) return;
      final walletFromCache =
          (responses[0]['_cache'] as Map<String, dynamic>?)?['stale'] == true;
      final txFromCache =
          (responses[1]['_cache'] as Map<String, dynamic>?)?['stale'] == true;
      setState(() {
        _wallet = responses[0]['wallet'] as Map<String, dynamic>?;
        _pendingOrders = ((responses[0]['pendingOrders'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _transactions = ((responses[1]['transactions'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _telebirrConfigured = responses[0]['telebirrConfigured'] == true;
        _showingCachedData = walletFromCache || txFromCache;
        _previewMode = false;
        _loading = false;
      });
    } on BackendRequestException catch (error) {
      final code = (error.payload?['code'] ?? '').toString();
      if (code != 'ENDPOINT_UNAVAILABLE') {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = ErrorHandler.getMessage(error);
        });
        return;
      }

      final preview = await _buildPreviewWallet(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _wallet = preview.wallet;
        _pendingOrders = const [];
        _transactions = preview.transactions;
        _telebirrConfigured = false;
        _showingCachedData = false;
        _previewMode = true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHandler.getMessage(error);
      });
    }
  }

  Future<_WalletPreviewData> _buildPreviewWallet({
    bool forceRefresh = false,
  }) async {
    final user = await _authService.getStoredUserMap() ?? const <String, dynamic>{};
    final userId = (user['id'] ?? '').toString();
    final userType = (user['userType'] ?? 'Cargo').toString();

    final transactions = <Map<String, dynamic>>[];

    if (userType == 'Driver') {
      final data = await BackendHttp.request(
        path: '/api/bids/me?limit=60&offset=0',
        cacheTtl: const Duration(minutes: 2),
        forceRefresh: forceRefresh,
      );
      final bids = ((data['bids'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

      for (final bid in bids) {
        final load = bid['load'] as Map<String, dynamic>? ?? const {};
        final amount = (bid['amount'] as num?)?.toDouble() ?? 0;
        final status = (bid['status'] ?? '').toString().toLowerCase();
        final deliveryStatus =
            (load['deliveryStatus'] ?? '').toString().toLowerCase();
        final route =
            '${(load['start'] ?? 'Departure').toString()} -> ${(load['end'] ?? 'Destination').toString()}';
        final createdAt =
            (bid['createdAt'] ?? load['createdAt'] ?? DateTime.now().toIso8601String())
                .toString();

        if (deliveryStatus == 'delivered' || status == 'completed') {
          transactions.add(
            _previewTransaction(
              id: 'preview_driver_${bid['id']}_credit',
              title: 'Estimated delivery earnings',
              description: 'Completed load payout for $route.',
              amount: amount,
              kind: 'settlement_credit',
              direction: 'credit',
              createdAt: createdAt,
            ),
          );
        } else if (status == 'accepted') {
          transactions.add(
            _previewTransaction(
              id: 'preview_driver_${bid['id']}_pending',
              title: 'Accepted load in progress',
              description: 'Payment will settle after delivery for $route.',
              amount: amount,
              kind: 'settlement_pending',
              direction: 'credit',
              createdAt: createdAt,
              status: 'pending',
            ),
          );
        }
      }
    } else if (userId.isNotEmpty) {
      final data = await BackendHttp.request(
        path: '/api/users/$userId/threads?limit=60&offset=0',
        cacheTtl: const Duration(minutes: 2),
        forceRefresh: forceRefresh,
      );
      final threads = ((data['threads'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

      for (final thread in threads) {
        final acceptedBid = ((thread['bids'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .firstWhere(
              (entry) =>
                  (entry['status'] ?? '').toString().toLowerCase() == 'accepted',
              orElse: () => const <String, dynamic>{},
            );
        if (acceptedBid.isEmpty) continue;

        final amount = (acceptedBid['amount'] as num?)?.toDouble() ?? 0;
        final deliveryStatus =
            (thread['deliveryStatus'] ?? '').toString().toLowerCase();
        final route =
            '${(thread['start'] ?? 'Departure').toString()} -> ${(thread['end'] ?? 'Destination').toString()}';
        final createdAt =
            (thread['updatedAt'] ?? thread['createdAt'] ?? DateTime.now().toIso8601String())
                .toString();

        transactions.add(
          _previewTransaction(
            id: 'preview_cargo_${thread['id']}_${acceptedBid['id']}',
            title: deliveryStatus == 'delivered'
                ? 'Estimated settlement completed'
                : 'Estimated funds reserved',
            description: deliveryStatus == 'delivered'
                ? 'Accepted shipment for $route was completed.'
                : 'Accepted shipment for $route is holding funds until delivery.',
            amount: amount,
            kind: deliveryStatus == 'delivered'
                ? 'settlement_release'
                : 'escrow_hold',
            direction: deliveryStatus == 'delivered' ? 'debit' : 'hold',
            createdAt: createdAt,
            status: deliveryStatus == 'delivered' ? 'completed' : 'pending',
          ),
        );
      }
    }

    transactions.sort((a, b) {
      final aTime = DateTime.tryParse((a['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse((b['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return _WalletPreviewData(
      wallet: <String, dynamic>{
        'balance': 0,
        'reservedBalance': 0,
        'availableBalance': 0,
      },
      transactions: transactions.take(20).toList(),
    );
  }

  Map<String, dynamic> _previewTransaction({
    required String id,
    required String title,
    required String description,
    required double amount,
    required String kind,
    required String direction,
    required String createdAt,
    String status = 'completed',
  }) {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'kind': kind,
      'direction': direction,
      'status': status,
      'createdAt': createdAt,
      'isPreview': true,
    };
  }

  Future<void> _startTopUp() async {
    if (!_telebirrConfigured) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Telebirr setup pending'),
          content: const Text(
            'The wallet and settlement UI is already available. Telebirr checkout will activate as soon as the backend merchant credentials are added.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Top up wallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the amount you want to add with Telebirr.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppPalette.darkTextSoft : Colors.black54,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount (ETB)',
                  hintText: 'Minimum 10 ETB',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(
                  controller.text.replaceAll(',', '').trim(),
                );
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (amount == null || amount <= 0) return;

    setState(() => _creatingTopUp = true);
    try {
      final data = await BackendHttp.request(
        path: '/api/wallet/topups',
        method: 'POST',
        body: {'amount': amount},
        forceRefresh: true,
      );
      final order = data['order'] as Map<String, dynamic>? ?? const {};
      final checkoutUrl = (order['checkoutUrl'] ?? '').toString();

      if (!mounted) return;
      NotificationCenterController.refreshUnreadCount(forceRefresh: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telebirr checkout opened. Complete payment and return to refresh your wallet.'),
        ),
      );
      if (checkoutUrl.isNotEmpty) {
        final uri = Uri.tryParse(checkoutUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      await _load(forceRefresh: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _creatingTopUp = false);
    }
  }

  Future<void> _resumeCheckout(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _money(num? value) => '${(value ?? 0).toStringAsFixed(2)} ETB';

  String _timeLabel(String? raw) {
    final date = raw == null ? null : DateTime.tryParse(raw);
    if (date == null) return 'Just now';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _transactionIcon(String kind, String direction) {
    if (kind.contains('topup') || direction == 'credit') {
      return Icons.south_west_rounded;
    }
    if (direction == 'hold') {
      return Icons.lock_outline_rounded;
    }
    return Icons.north_east_rounded;
  }

  Color _transactionColor(String kind, String direction) {
    if (kind.contains('topup') || direction == 'credit') {
      return const Color(0xFF0F9D58);
    }
    if (direction == 'hold') {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            onPressed: () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
              : RefreshIndicator(
                  onRefresh: () => _load(forceRefresh: true),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppPalette.heroGradient,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha((0.14 * 255).round()),
                              blurRadius: 24,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available balance',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _money((_wallet?['availableBalance'] as num?) ?? 0),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _WalletMetricCard(
                                  label: 'Total balance',
                                  value: _money((_wallet?['balance'] as num?) ?? 0),
                                ),
                                _WalletMetricCard(
                                  label: 'Reserved',
                                  value: _money((_wallet?['reservedBalance'] as num?) ?? 0),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _creatingTopUp ? null : _startTopUp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppPalette.ink,
                                    ),
                                    icon: _creatingTopUp
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.account_balance_wallet_outlined),
                                    label: Text(
                                      _telebirrConfigured
                                          ? 'Top up with Telebirr'
                                          : 'View Telebirr setup',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!_telebirrConfigured) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Telebirr merchant credentials still need to be configured on the backend before checkout can start.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_showingCachedData) ...[
                        const SizedBox(height: 12),
                        _ActionCard(
                          title: 'Offline-ready view',
                          subtitle:
                              'This screen is showing the last saved wallet snapshot from this device. Pull to refresh when the connection improves.',
                        ),
                      ],
                      if (_previewMode) ...[
                        const SizedBox(height: 12),
                        _ActionCard(
                          title: 'Wallet preview mode',
                          subtitle:
                              'The connected backend is not serving the wallet routes yet, so this screen is showing the product UI with estimated load-based activity instead of the real ledger.',
                        ),
                      ],
                      if (_pendingOrders.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _SectionTitle(
                          title: 'Pending top-ups',
                          subtitle: 'Resume checkout if you left Telebirr before payment finished.',
                        ),
                        const SizedBox(height: 10),
                        ..._pendingOrders.map((order) {
                          final checkoutUrl = (order['checkoutUrl'] ?? '').toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ActionCard(
                              title: _money((order['amount'] as num?) ?? 0),
                              subtitle: 'Started ${_timeLabel(order['createdAt']?.toString())}',
                              trailing: ElevatedButton(
                                onPressed: checkoutUrl.isEmpty
                                    ? null
                                    : () => _resumeCheckout(checkoutUrl),
                                child: const Text('Resume'),
                              ),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 18),
                      _SectionTitle(
                        title: 'How funds move',
                        subtitle: 'Cargo owners top up before accepting a bid. Accepted loads reserve wallet funds, then completed deliveries release them to the assigned driver.',
                      ),
                      const SizedBox(height: 10),
                      _ActionCard(
                        title: 'Escrow-style settlement',
                        subtitle: 'The app now checks wallet balance before a bid is accepted and tracks reserved funds separately from spendable funds.',
                      ),
                      const SizedBox(height: 18),
                      _SectionTitle(
                        title: 'Recent activity',
                        subtitle: 'Wallet credits, reservations, and delivery settlements.',
                      ),
                      const SizedBox(height: 10),
                      if (_transactions.isEmpty)
                        _ActionCard(
                          title: 'No wallet activity yet',
                          subtitle: 'Your top-ups and delivery settlements will appear here.',
                        )
                      else
                        ..._transactions.map((transaction) {
                          final kind = (transaction['kind'] ?? '').toString();
                          final direction = (transaction['direction'] ?? '').toString();
                          final status = (transaction['status'] ?? 'completed').toString();
                          final accent = _transactionColor(kind, direction);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? AppPalette.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isDark
                                      ? AppPalette.darkOutline
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: accent.withAlpha((0.12 * 255).round()),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      _transactionIcon(kind, direction),
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (transaction['title'] ?? 'Wallet activity').toString(),
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          (transaction['description'] ?? '').toString(),
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: isDark
                                                ? AppPalette.darkTextSoft
                                                : Colors.black54,
                                            height: 1.45,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${_timeLabel(transaction['createdAt']?.toString())} • $status',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: isDark
                                                ? AppPalette.darkTextSoft
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _money((transaction['amount'] as num?) ?? 0),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppPalette.darkText : AppPalette.ink,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? AppPalette.darkTextSoft : Colors.black54,
              ),
        ),
      ],
    );
  }
}

class _WalletMetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _WalletMetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha((0.16 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppPalette.darkTextSoft : Colors.black54,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _WalletPreviewData {
  final Map<String, dynamic> wallet;
  final List<Map<String, dynamic>> transactions;

  const _WalletPreviewData({
    required this.wallet,
    required this.transactions,
  });
}
