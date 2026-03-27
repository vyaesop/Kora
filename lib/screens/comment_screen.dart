import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kora/app_localizations.dart';
import 'package:kora/model/thread_message.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/backend_http.dart';
import 'package:kora/utils/error_handler.dart';
import 'package:kora/utils/firestore_service.dart';
import 'package:kora/widgets/active_job_controls.dart';
import 'package:kora/widgets/agreed_price_banner.dart';
import 'package:kora/widgets/driver_status_controls.dart';
import 'package:kora/widgets/place_bid_widget.dart';
import 'package:kora/widgets/profile_avatar.dart';

class CommentScreen extends StatefulWidget {
  final String threadId;
  final ThreadMessage message;

  const CommentScreen({
    super.key,
    required this.threadId,
    required this.message,
  });

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final _authService = BackendAuthService();
  static const String _defaultCurrency = 'Birr';

  bool _loading = true;
  String? _error;
  String? _currentUserId;
  Map<String, dynamic>? _thread;
  List<Map<String, dynamic>> _bids = const [];
  Timer? _pollTimer;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final userId = await _authService.getCurrentUserId();
    if (!mounted) return;
    setState(() => _currentUserId = userId);
    await _refresh(showLoader: true);
  }

  Future<void> _refresh({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final threadData =
          await BackendHttp.request(path: '/api/threads/${widget.threadId}');
      final bidsData =
          await BackendHttp.request(path: '/api/threads/${widget.threadId}/bids');

      final thread = threadData['thread'] as Map<String, dynamic>?;
      final bidsRaw = bidsData['bids'];
      final bids = (bidsRaw is List)
          ? bidsRaw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];

      bids.sort((a, b) {
        final aAmount = (a['amount'] as num?)?.toDouble() ?? 0;
        final bAmount = (b['amount'] as num?)?.toDouble() ?? 0;
        return aAmount.compareTo(bAmount);
      });

      if (!mounted) return;
      setState(() {
        _thread = thread;
        _bids = bids;
        _loading = false;
        _error = null;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHandler.getMessage(e);
      });
    }
  }

  Map<String, dynamic> _parseBidNote(dynamic note) {
    if (note == null) return const {};
    final text = note.toString();
    if (text.isEmpty) return const {};
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return {'carrierNotes': text};
    }
  }

  String _formatLastUpdated(DateTime time, AppLocalizations localizations) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 30) return localizations.tr('justNow');
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ${localizations.tr('ago')}';
    }
    return '${diff.inHours}h ${localizations.tr('ago')}';
  }

  Future<void> _acceptBid(Map<String, dynamic> bid) async {
    try {
      await FirestoreService().acceptBid(
        threadId: widget.threadId,
        bidId: (bid['id'] ?? '').toString(),
        acceptedCarrierId: (bid['driverId'] ?? '').toString(),
        finalPrice: (bid['amount'] as num?)?.toDouble() ?? 0,
        closeBidding: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tr('bidAcceptedSuccess')),
        ),
      );
      await _refresh(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).tr('error')}: ${ErrorHandler.getMessage(e)}',
          ),
        ),
      );
    }
  }

  Future<void> _deleteBid(Map<String, dynamic> bid) async {
    try {
      await FirestoreService().deleteBid(
        threadId: widget.threadId,
        bidId: (bid['id'] ?? '').toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('bidDeleted'))),
      );
      await _refresh(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).tr('error')}: ${ErrorHandler.getMessage(e)}',
          ),
        ),
      );
    }
  }

  String _threadText(String key, String fallback) {
    final value = _thread?[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  double _threadWeight() {
    return (_thread?['weight'] as num?)?.toDouble() ?? widget.message.weight;
  }

  String _threadWeightUnit() {
    final value = _thread?['weightUnit']?.toString().trim();
    return (value == null || value.isEmpty) ? widget.message.weightUnit : value;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending_bids':
        return const Color(0xFF2563EB);
      case 'accepted':
        return const Color(0xFF16A34A);
      case 'driving_to_location':
      case 'picked_up':
      case 'on_the_road':
        return const Color(0xFF0EA5E9);
      case 'delivered':
        return const Color(0xFF22C55E);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.tr('feed'))),
        body: Center(child: Text(_error!)),
      );
    }

    final thread = _thread;
    if (thread == null) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.tr('feed'))),
        body: Center(child: Text(localizations.tr('threadNotFound'))),
      );
    }

    final owner = thread['owner'] as Map<String, dynamic>? ?? const {};
    final ownerId = (thread['ownerId'] ?? '').toString();
    final isShipper = _currentUserId != null && _currentUserId == ownerId;
    final deliveryStatus =
        (thread['deliveryStatus'] ?? 'pending_bids').toString();
    final isBiddingClosed = deliveryStatus != 'pending_bids';
    final statusColor = _statusColor(deliveryStatus);

    Map<String, dynamic>? acceptedBid;
    for (final bid in _bids) {
      final status = (bid['status'] ?? '').toString().toLowerCase();
      if (status == 'accepted' || status == 'completed') {
        acceptedBid = bid;
        break;
      }
    }

    final acceptedDriverId = (acceptedBid?['driverId'] ?? '').toString();
    final acceptedBidId = (acceptedBid?['id'] ?? '').toString();
    final acceptedNote = _parseBidNote(acceptedBid?['note']);
    final finalPrice = (acceptedNote['finalPrice'] as num?)?.toDouble() ??
        ((acceptedBid?['amount'] as num?)?.toDouble() ?? 0);
    final currency = (acceptedNote['currency'] ?? _defaultCurrency).toString();
    final bestBid =
        _bids.isEmpty ? null : (_bids.first['amount'] as num?)?.toDouble();
    final isAcceptedDriver =
        _currentUserId != null && _currentUserId == acceptedDriverId;

    final start = _threadText('start', widget.message.start);
    final end = _threadText('end', widget.message.end);
    final loadDescription = _threadText('message', widget.message.message);
    final loadType = _threadText('type', widget.message.type);
    final packaging = _threadText('packaging', widget.message.packaging);
    final shipperName = (owner['name'] ?? widget.message.senderName).toString();
    final shipperImage = owner['profileImageUrl']?.toString();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text('$start -> $end'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isBiddingClosed && acceptedBid != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: AgreedPriceBanner(
                  finalPrice: finalPrice,
                  currency: currency,
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refresh(showLoader: false),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _LoadHeroCard(
                      shipperName: shipperName,
                      shipperImageUrl: shipperImage,
                      loadDescription: loadDescription,
                      start: start,
                      end: end,
                      statusLabel: deliveryStatus.replaceAll('_', ' '),
                      statusColor: statusColor,
                      lastUpdated: _lastUpdated == null
                          ? null
                          : '${localizations.tr('lastUpdated')}: ${_formatLastUpdated(_lastUpdated!, localizations)}',
                    ),
                    const SizedBox(height: 16),
                    _SectionTitle(
                      title: 'Shipment overview',
                      subtitle:
                          'A concise summary of the route and cargo details.',
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.35,
                      children: [
                        _DetailMetricCard(
                          label: localizations.tr('weight'),
                          value: '${_threadWeight()} ${_threadWeightUnit()}',
                          icon: Icons.scale_outlined,
                        ),
                        _DetailMetricCard(
                          label: localizations.tr('loadType'),
                          value: loadType.isEmpty
                              ? localizations.tr('searchGeneral')
                              : loadType,
                          icon: Icons.category_outlined,
                        ),
                        _DetailMetricCard(
                          label: localizations.tr('packaging'),
                          value: packaging.isEmpty ? 'Not specified' : packaging,
                          icon: Icons.inventory_2_outlined,
                        ),
                        _DetailMetricCard(
                          label: localizations.tr('bids'),
                          value: '${_bids.length}',
                          icon: Icons.local_offer_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _RouteCard(start: start, end: end, message: loadDescription),
                    const SizedBox(height: 16),
                    _SectionTitle(
                      title: 'Bid activity',
                      subtitle: _bids.isEmpty
                          ? 'No bids yet on this load.'
                          : '${_bids.length} bids received${bestBid == null ? '' : ' - Best offer ${bestBid.toStringAsFixed(2)} $currency'}',
                    ),
                    const SizedBox(height: 10),
                    if (_bids.isEmpty)
                      _EmptyBidsCard(text: localizations.tr('noBidsYet'))
                    else
                      ..._bids.map(
                        (bid) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _BidCard(
                            bid: bid,
                            localizations: localizations,
                            currentUserId: _currentUserId ?? '',
                            defaultCurrency: _defaultCurrency,
                            isShipper: isShipper,
                            isBiddingClosed: isBiddingClosed,
                            onAccept: () => _acceptBid(bid),
                            onDelete: () => _deleteBid(bid),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!isShipper && !isBiddingClosed)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: PlaceBidWidget(
                  threadId: widget.threadId,
                  currency: currency,
                ),
              ),
            if (isBiddingClosed && acceptedBid != null)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  children: [
                    ActiveJobControls(
                      isShipper: isShipper,
                      threadId: widget.threadId,
                      carrierId: acceptedDriverId,
                      deliveryStatus: deliveryStatus,
                      bidId: acceptedBidId,
                      driverId: acceptedDriverId,
                      ownerId: ownerId,
                    ),
                    if (isAcceptedDriver)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: DriverStatusControls(
                          threadId: widget.threadId,
                          currentStatus: deliveryStatus,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadHeroCard extends StatelessWidget {
  final String shipperName;
  final String? shipperImageUrl;
  final String loadDescription;
  final String start;
  final String end;
  final String statusLabel;
  final Color statusColor;
  final String? lastUpdated;

  const _LoadHeroCard({
    required this.shipperName,
    required this.shipperImageUrl,
    required this.loadDescription,
    required this.start,
    required this.end,
    required this.statusLabel,
    required this.statusColor,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
          Row(
            children: [
              ProfileAvatar(imageUrl: shipperImageUrl, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shipperName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Load owner',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha((0.18 * 255).round()),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: statusColor.withAlpha((0.4 * 255).round()),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            loadDescription.isEmpty ? 'Shipment ready for bidding.' : loadDescription,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          _RoutePoint(label: 'Pickup', value: start, isStart: true),
          const SizedBox(height: 10),
          _RoutePoint(label: 'Delivery', value: end, isStart: false),
          if (lastUpdated != null) ...[
            const SizedBox(height: 14),
            Text(
              lastUpdated!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final String label;
  final String value;
  final bool isStart;

  const _RoutePoint({
    required this.label,
    required this.value,
    required this.isStart,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            shape: isStart ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isStart ? null : BorderRadius.circular(4),
            color: isStart ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B),
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
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppPalette.ink,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
        ),
      ],
    );
  }
}

class _DetailMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailMetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0369A1)),
          const Spacer(),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.black54,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final String start;
  final String end;
  final String message;

  const _RouteCard({
    required this.start,
    required this.end,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Route details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RouteRow(
            icon: Icons.trip_origin,
            label: 'Pickup',
            value: start,
            color: const Color(0xFF0EA5E9),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 12),
          _RouteRow(
            icon: Icons.place_outlined,
            label: 'Delivery',
            value: end,
            color: const Color(0xFFF59E0B),
          ),
          if (message.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Text(
              'Shipment notes',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                    height: 1.45,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _RouteRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withAlpha((0.12 * 255).round()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyBidsCard extends StatelessWidget {
  final String text;

  const _EmptyBidsCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
            ),
      ),
    );
  }
}

class _BidCard extends StatelessWidget {
  final Map<String, dynamic> bid;
  final AppLocalizations localizations;
  final String currentUserId;
  final String defaultCurrency;
  final bool isShipper;
  final bool isBiddingClosed;
  final VoidCallback onAccept;
  final VoidCallback onDelete;

  const _BidCard({
    required this.bid,
    required this.localizations,
    required this.currentUserId,
    required this.defaultCurrency,
    required this.isShipper,
    required this.isBiddingClosed,
    required this.onAccept,
    required this.onDelete,
  });

  Map<String, dynamic> _parseBidNote(dynamic note) {
    if (note == null) return const {};
    final text = note.toString();
    if (text.isEmpty) return const {};
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return {'carrierNotes': text};
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF2563EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bidDriverId = (bid['driverId'] ?? '').toString();
    final driver = bid['driver'] as Map<String, dynamic>?;
    final driverName = (driver?['name'] ?? bidDriverId).toString();
    final driverRating = (driver?['ratingAverage'] as num?)?.toDouble();
    final amount = (bid['amount'] as num?)?.toDouble() ?? 0;
    final status = (bid['status'] ?? 'pending').toString();
    final note = _parseBidNote(bid['note']);
    final carrierNotes = (note['carrierNotes'] ?? '').toString();
    final currency = (note['currency'] ?? defaultCurrency).toString();
    final canAccept =
        isShipper && !isBiddingClosed && status.toLowerCase() == 'pending';
    final canDelete = !isShipper &&
        bidDriverId == currentUserId &&
        status.toLowerCase() == 'pending';
    final badgeColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                imageUrl: driver?['profileImageUrl']?.toString(),
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (driverRating != null)
                      Text(
                        '${localizations.tr('ratingLabel')}: ${driverRating.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha((0.12 * 255).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offer',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${amount.toStringAsFixed(2)} $currency',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink,
                      ),
                ),
                if (carrierNotes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    carrierNotes,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF475569),
                          height: 1.45,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (canAccept || canDelete) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (canAccept)
                  ElevatedButton(
                    onPressed: onAccept,
                    child: Text(localizations.tr('acceptBid')),
                  ),
                if (canDelete) ...[
                  if (canAccept) const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: onDelete,
                    child: Text(localizations.tr('delete')),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
