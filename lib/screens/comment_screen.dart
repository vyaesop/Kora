import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kora/app_localizations.dart';
import 'package:kora/model/thread_message.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/backend_http.dart';
import 'package:kora/utils/backend_transport.dart';
import 'package:kora/utils/driver_location_service.dart';
import 'package:kora/utils/ethiopia_locations.dart';
import 'package:kora/utils/error_handler.dart';
import 'package:kora/utils/firestore_service.dart';
import 'package:kora/utils/formatters.dart';
import 'package:kora/utils/load_categories.dart';
import 'package:kora/utils/recommendation_service.dart';
import 'package:kora/widgets/active_job_controls.dart';
import 'package:kora/widgets/agreed_price_banner.dart';
import 'package:kora/widgets/driver_status_controls.dart';
import 'package:kora/widgets/place_bid_widget.dart';
import 'package:kora/widgets/profile_avatar.dart';
import 'package:kora/screens/wallet_screen.dart';

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
  List<ThreadMessage> _returnSuggestions = const [];
  Timer? _pollTimer;
  DateTime? _lastUpdated;
  String? _suggestionOrigin;
  bool _usingLiveDriverCity = false;

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
    unawaited(
      RecommendationService.rememberRoute(
        widget.message.start,
        widget.message.end,
      ),
    );
    if (!mounted) return;
    setState(() => _currentUserId = userId);
    await _refresh(showLoader: true);
  }

  Future<void> _refresh({
    required bool showLoader,
    bool forceRefresh = false,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final recentTokens = await RecommendationService.loadRecentRouteTokens();
      final responses = await Future.wait([
        BackendHttp.request(
          path: '/api/threads/${widget.threadId}',
          cacheTtl: const Duration(minutes: 5),
          forceRefresh: forceRefresh,
        ),
        BackendHttp.request(
          path: '/api/threads/${widget.threadId}/bids',
          cacheTtl: const Duration(minutes: 2),
          forceRefresh: forceRefresh,
        ),
      ]);
      final threadData = responses[0];
      final bidsData = responses[1];

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

      final currentEnd = _threadTextFromMap(thread, 'end', widget.message.end);
      final currentStart = _threadTextFromMap(
        thread,
        'start',
        widget.message.start,
      );
      final ownerId = (thread?['ownerId'] ?? '').toString();
      final isShipper = _currentUserId != null && _currentUserId == ownerId;
      final suggestionOriginData = isShipper
          ? _SuggestionOrigin(city: currentEnd, isLiveDriverCity: false)
          : await _resolveSuggestionOrigin(fallbackCity: currentEnd);
      final suggestionsRows = await _loadClientSideSuggestions(
        returnOrigin: suggestionOriginData.city,
        excludeThreadId: widget.threadId,
        forceRefresh: forceRefresh,
      );
      final suggestions = suggestionsRows.map(ThreadMessage.fromApiMap).toList()
        ..sort((a, b) {
          final scoreA = RecommendationService.scoreReturnLoad(
            thread: a,
            returnOrigin: suggestionOriginData.city,
            originalStart: currentStart,
            recentTokens: recentTokens,
          );
          final scoreB = RecommendationService.scoreReturnLoad(
            thread: b,
            returnOrigin: suggestionOriginData.city,
            originalStart: currentStart,
            recentTokens: recentTokens,
          );
          return scoreB.compareTo(scoreA);
        });

      if (!mounted) return;
      setState(() {
        _thread = thread;
        _bids = bids;
        _returnSuggestions = suggestions.take(4).toList();
        _loading = false;
        _error = null;
        _lastUpdated = DateTime.now();
        _suggestionOrigin = suggestionOriginData.city;
        _usingLiveDriverCity = suggestionOriginData.isLiveDriverCity;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHandler.getMessage(e);
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadClientSideSuggestions({
    required String returnOrigin,
    required String excludeThreadId,
    required bool forceRefresh,
  }) async {
    try {
      final feed = await BackendHttp.request(
        path: '/api/threads?limit=40&offset=0',
        auth: false,
        cacheTtl: const Duration(minutes: 5),
        forceRefresh: forceRefresh,
      );
      final rows = (feed['threads'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .where((row) {
            final id = (row['id'] ?? '').toString();
            if (id.isEmpty || id == excludeThreadId) return false;
            final status = (row['deliveryStatus'] ?? 'pending_bids').toString();
            if (status != 'pending_bids') return false;
            final start = (row['start'] ?? '').toString().trim().toLowerCase();
            return start == returnOrigin.trim().toLowerCase();
          })
          .toList();
      return rows;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<_SuggestionOrigin> _resolveSuggestionOrigin({
    required String fallbackCity,
  }) async {
    final driverCity = await DriverLocationService.getCurrentDriverCity();
    if (driverCity != null && driverCity.trim().isNotEmpty) {
      return _SuggestionOrigin(city: driverCity.trim(), isLiveDriverCity: true);
    }
    return _SuggestionOrigin(city: fallbackCity, isLiveDriverCity: false);
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
      await _refresh(showLoader: false, forceRefresh: true);
    } on BackendRequestException catch (error) {
      if (!mounted) return;
      final code = (error.payload?['code'] ?? '').toString();
      if (code == 'WALLET_TOPUP_REQUIRED') {
        final wallet = error.payload?['wallet'] as Map<String, dynamic>?;
        final available = (wallet?['availableBalance'] ?? 0).toString();
        final required = (wallet?['requiredAmount'] ?? 0).toString();
        final openWallet = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Wallet top-up required'),
            content: Text(
              'You need enough wallet balance before accepting this bid.\n\nAvailable: $available ETB\nRequired: $required ETB',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Open wallet'),
              ),
            ],
          ),
        );
        if (openWallet == true && mounted) {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const WalletScreen()));
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).tr('error')}: ${ErrorHandler.getMessage(error)}',
          ),
        ),
      );
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
      await _refresh(showLoader: false, forceRefresh: true);
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

  String _threadTextFromMap(
    Map<String, dynamic>? source,
    String key,
    String fallback,
  ) {
    final value = source?[key]?.toString().trim();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
    final deliveryStatus = (thread['deliveryStatus'] ?? 'pending_bids')
        .toString();
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
    final finalPrice =
        (acceptedNote['finalPrice'] as num?)?.toDouble() ??
        ((acceptedBid?['amount'] as num?)?.toDouble() ?? 0);
    final currency = (acceptedNote['currency'] ?? _defaultCurrency).toString();
    final bestBid = _bids.isEmpty
        ? null
        : (_bids.first['amount'] as num?)?.toDouble();
    final isAcceptedDriver =
        _currentUserId != null && _currentUserId == acceptedDriverId;

    final start = _threadText('start', widget.message.start);
    final end = _threadText('end', widget.message.end);
    final startLocation = resolveEthiopiaLocation(
      city: (thread['startCity'] ?? '').toString(),
      zone: thread['startZone']?.toString(),
      region: thread['startRegion']?.toString(),
      fallback: start,
    );
    final endLocation = resolveEthiopiaLocation(
      city: (thread['endCity'] ?? '').toString(),
      zone: thread['endZone']?.toString(),
      region: thread['endRegion']?.toString(),
      fallback: end,
    );
    final loadDescription = _threadText('message', widget.message.message);
    final loadType = displayLoadType(
      category: _threadText('category', widget.message.category),
      subtype: _threadText('type', widget.message.type),
    );
    final packaging = _threadText('packaging', widget.message.packaging);
    final shipperName = (owner['name'] ?? widget.message.senderName).toString();
    final shipperImage = owner['profileImageUrl']?.toString();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text('${startLocation.city} -> ${endLocation.city}'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(showLoader: false, forceRefresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (isBiddingClosed && acceptedBid != null) ...[
                AgreedPriceBanner(finalPrice: finalPrice, currency: currency),
                const SizedBox(height: 14),
              ],
              _LoadHeroCard(
                shipperName: shipperName,
                shipperImageUrl: shipperImage,
                loadDescription: loadDescription,
                start: startLocation,
                end: endLocation,
                statusLabel: deliveryStatus.replaceAll('_', ' '),
                statusColor: statusColor,
                lastUpdated: _lastUpdated == null
                    ? null
                    : '${localizations.tr('lastUpdated')}: ${_formatLastUpdated(_lastUpdated!, localizations)}',
              ),
              const SizedBox(height: 16),
              const _SectionTitle(
                title: 'Shipment overview',
                subtitle: 'A concise summary of the route and cargo details.',
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
                    value: formatWeight(_threadWeight(), _threadWeightUnit()),
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
              _RouteCard(
                start: startLocation,
                end: endLocation,
                message: loadDescription,
              ),
              if (!isShipper && !isBiddingClosed) ...[
                const SizedBox(height: 18),
                _SectionTitle(
                  title: 'Place your bid',
                  subtitle:
                      'Review the shipment, then send a clear offer before looking at other nearby opportunities.',
                ),
                const SizedBox(height: 10),
                PlaceBidWidget(
                  threadId: widget.threadId,
                  currency: currency,
                  onBidSaved: () =>
                      _refresh(showLoader: false, forceRefresh: true),
                ),
              ],
              if (!isShipper) ...[
                const SizedBox(height: 18),
                _SectionTitle(
                  title:
                      'Suggested loads from ${_suggestionOrigin ?? endLocation.city}',
                  subtitle: _usingLiveDriverCity
                      ? 'These loads start from the city you are currently in, based on your live location permission.'
                      : 'Enable driver location to keep these suggestions aligned to the city you are currently in. Until then, we fall back to the route destination.',
                ),
                const SizedBox(height: 10),
                if (_returnSuggestions.isEmpty)
                  _EmptyBidsCard(
                    text: _usingLiveDriverCity
                        ? 'No open loads start from your current city right now. As new matching loads appear, they will show here automatically.'
                        : 'No open loads match the current fallback city yet. Turn on location and refresh to get suggestions from where you are now.',
                  )
                else
                  ..._returnSuggestions.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ReturnLoadSuggestionCard(
                        message: item,
                        onOpen: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CommentScreen(
                                threadId: item.id,
                                message: item,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
              if (isBiddingClosed && acceptedBid != null) ...[
                const SizedBox(height: 18),
                const _SectionTitle(
                  title: 'Active delivery controls',
                  subtitle:
                      'Manage delivery progress, proof, and closeout actions from the main thread.',
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppPalette.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? AppPalette.darkOutline
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
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
              const SizedBox(height: 18),
              _SectionTitle(
                title: 'Bid activity',
                subtitle: _bids.isEmpty
                    ? 'No bids yet on this load.'
                    : '${_bids.length} bids received${bestBid == null ? '' : ' - Best offer ${formatPrice(bestBid, currency)}'}',
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
    );
  }
}

class _LoadHeroCard extends StatelessWidget {
  final String shipperName;
  final String? shipperImageUrl;
  final String loadDescription;
  final ResolvedEthiopiaLocation start;
  final ResolvedEthiopiaLocation end;
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
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1324), Color(0xFF1D3557), Color(0xFF214E6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
            loadDescription.isEmpty
                ? 'Shipment ready for bidding.'
                : loadDescription,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withAlpha((0.14 * 255).round()),
              ),
            ),
            child: Column(
              children: [
                _RoutePoint(label: 'Departure', value: start, isStart: true),
                const SizedBox(height: 10),
                Divider(
                  color: Colors.white.withAlpha((0.12 * 255).round()),
                  height: 1,
                ),
                const SizedBox(height: 10),
                _RoutePoint(label: 'Destination', value: end, isStart: false),
              ],
            ),
          ),
          if (lastUpdated != null) ...[
            const SizedBox(height: 14),
            Text(
              lastUpdated!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final String label;
  final ResolvedEthiopiaLocation value;
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
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 2),
              Text(
                value.city,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (value.subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  value.subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0369A1)),
          const Spacer(),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isDark ? AppPalette.darkTextSoft : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final ResolvedEthiopiaLocation start;
  final ResolvedEthiopiaLocation end;
  final String message;

  const _RouteCard({
    required this.start,
    required this.end,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Route',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RouteRow(
            icon: Icons.trip_origin,
            label: 'Departure',
            value: start,
            color: const Color(0xFF5B8C85),
          ),
          const SizedBox(height: 12),
          Divider(
            color: isDark ? AppPalette.darkOutline : Colors.grey.shade200,
          ),
          const SizedBox(height: 12),
          _RouteRow(
            icon: Icons.place_outlined,
            label: 'Destination',
            value: end,
            color: const Color(0xFFC28C5A),
          ),
          if (message.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(
              color: isDark ? AppPalette.darkOutline : Colors.grey.shade200,
            ),
            const SizedBox(height: 12),
            Text(
              'Shipment notes',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppPalette.darkTextSoft
                    : const Color(0xFF475569),
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
  final ResolvedEthiopiaLocation value;
  final Color color;

  const _RouteRow({
    required this.icon,
    required this.label,
    required this.value,
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
                  color: isDark ? AppPalette.darkTextSoft : Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.city,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (value.subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  value.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppPalette.darkTextSoft
                        : const Color(0xFF475569),
                  ),
                ),
              ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isDark ? AppPalette.darkTextSoft : Colors.black54,
        ),
      ),
    );
  }
}

class _ReturnLoadSuggestionCard extends StatelessWidget {
  final ThreadMessage message;
  final VoidCallback onOpen;

  const _ReturnLoadSuggestionCard({
    required this.message,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppPalette.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${message.start} -> ${message.end}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message.message.trim().isEmpty
                        ? message.type.isEmpty && message.category.isEmpty
                              ? 'Open return opportunity'
                              : displayLoadType(
                                  category: message.category,
                                  subtype: message.type,
                                )
                        : message.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppPalette.darkTextSoft
                          : const Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SuggestionTag(
                        label: formatWeight(message.weight, message.weightUnit),
                      ),
                      if (message.type.isNotEmpty ||
                          message.category.isNotEmpty)
                        _SuggestionTag(
                          label: displayLoadType(
                            category: message.category,
                            subtype: message.type,
                          ),
                        ),
                      if (message.packaging.isNotEmpty)
                        _SuggestionTag(label: message.packaging),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: onOpen, child: const Text('Open')),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTag extends StatelessWidget {
  final String label;

  const _SuggestionTag({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkSurfaceRaised : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
    final canDelete =
        !isShipper &&
        bidDriverId == currentUserId &&
        status.toLowerCase() == 'pending';
    final badgeColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
        ),
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
                          color: isDark
                              ? AppPalette.darkTextSoft
                              : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
                  'Offer',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isDark ? AppPalette.darkTextSoft : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatPrice(amount, currency),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppPalette.darkText : AppPalette.ink,
                  ),
                ),
                if (carrierNotes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    carrierNotes,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppPalette.darkTextSoft
                          : const Color(0xFF475569),
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

class _SuggestionOrigin {
  final String city;
  final bool isLiveDriverCity;

  const _SuggestionOrigin({required this.city, required this.isLiveDriverCity});
}
