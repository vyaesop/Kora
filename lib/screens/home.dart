// home.dart
import 'package:kora/screens/track_loads_screen.dart';
import 'package:flutter/material.dart';
import 'package:kora/screens/post_screen.dart';
import 'package:kora/screens/profile_screen.dart';
import 'package:kora/screens/verification_documents_screen.dart';
import 'package:kora/screens/feed.dart';
import 'package:kora/screens/search.dart';
import 'package:kora/screens/my_bids.dart'; // Add this import
import 'package:kora/model/user.dart';
// removed unused geolocator imports
import 'package:kora/utils/driver_location_service.dart';
import 'package:kora/screens/pre_feed_cargo.dart';
import 'package:kora/screens/pre_feed_driver.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/app_localizations.dart';
import 'package:kora/utils/session_preferences.dart';
import 'package:kora/utils/verification_access.dart';

DriverLocationService? _locationService;

Future<void> _checkAndStartLocationUpdates(UserModel user) async {
  if (user.userType == 'Driver' && user.acceptedLoads!.isNotEmpty) {
    _locationService ??= DriverLocationService(user.id);
    _locationService!.start();
  } else {
    _locationService?.stop();
    _locationService = null;
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _authService = BackendAuthService();
  int selectedIndex = 0;
  // Remove PanelController since we're not using sliding panel anymore
  UserModel? currentUser;
  bool isLoading = true;
  DriverLocationService? _locationService; // Make it nullable

  int get _feedTabIndex => 1;

  int get _postTabIndex => currentUser?.userType == 'Cargo' ? 2 : -1;

  int get _profileTabIndex => currentUser?.userType == 'Cargo'
      ? 4
      : currentUser?.userType == 'Driver'
      ? 3
      : 3;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _locationService?.stop(); // Stop the service when the widget is disposed
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final sessionUser = await _authService.restoreSession();
    if (!mounted) return;
    if (sessionUser == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      setState(() {
        currentUser = sessionUser;
        selectedIndex = 0;
      });
      await _checkAndStartLocationUpdates(currentUser!);
      await _showTour(currentUser!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load user: $e")));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _openProfileTab() {
    if (!mounted) return;
    setState(() {
      selectedIndex = _profileTabIndex;
    });
  }

  Future<void> _openCargoPostingFlow() async {
    final navigator = Navigator.of(context);
    final allowed = await VerificationAccess.ensureVerifiedForAction(
      context,
      expectedUserType: 'Cargo',
      actionLabel: 'post loads',
      onOpenProfile: _openProfileTab,
    );
    if (!allowed || !context.mounted) return;
    await navigator.push(
      MaterialPageRoute(builder: (context) => const PostScreen()),
    );
  }

  void _openTab(int index) {
    if (!mounted) return;
    setState(() {
      selectedIndex = index;
    });
  }

  List<Widget> _buildPages() {
    final user = currentUser;
    if (user?.userType == 'Cargo') {
      return [
        PreFeedCargoScreen(
          user: user!,
          embedded: true,
          onContinueToFeed: () => _openTab(_feedTabIndex),
          onPostLoad: _openCargoPostingFlow,
          onOpenProfile: _openProfileTab,
          onSelectTab: _openTab,
        ),
        const FeedScreen(),
        const SizedBox(),
        const TrackLoadsScreen(showBack: false),
        ProfileScreen(onReplayTour: () => _showTour(user, force: true)),
      ];
    }
    if (user?.userType == 'Driver') {
      return [
        PreFeedDriverScreen(
          user: user!,
          embedded: true,
          onContinueToFeed: () => _openTab(_feedTabIndex),
          onOpenProfile: _openProfileTab,
          onSelectTab: _openTab,
        ),
        const FeedScreen(showSearchField: false),
        const MyBidsScreen(),
        ProfileScreen(onReplayTour: () => _showTour(user, force: true)),
      ];
    }
    return [
      const FeedScreen(),
      const FeedScreen(),
      const SearchScreen(),
      const ProfileScreen(),
    ];
  }

  List<BottomNavigationBarItem> _buildNavItems(AppLocalizations localizations) {
    if (currentUser?.userType == 'Cargo') {
      return [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home),
          label: localizations.tr('home'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.rss_feed),
          label: localizations.tr('feed'),
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppPalette.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
          label: localizations.tr('post'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.inventory_2_outlined),
          label: localizations.tr('myLoads'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person),
          label: localizations.tr('profile'),
        ),
      ];
    }
    if (currentUser?.userType == 'Driver') {
      return [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home),
          label: localizations.tr('home'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.rss_feed),
          label: localizations.tr('feed'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.local_offer),
          label: localizations.tr('myBids'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person),
          label: localizations.tr('profile'),
        ),
      ];
    }
    return [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home),
        label: localizations.tr('home'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.rss_feed),
        label: localizations.tr('feed'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.search),
        label: localizations.tr('search'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person),
        label: localizations.tr('profile'),
      ),
    ];
  }

  Future<void> _refreshCurrentUser() async {
    final refreshed = await _authService.restoreSession();
    if (!mounted || refreshed == null) {
      return;
    }

    setState(() {
      currentUser = refreshed;
    });
    await _checkAndStartLocationUpdates(refreshed);
  }

  Future<void> _openVerificationFlow() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VerificationDocumentsScreen()),
    );
    if (changed == true) {
      await _refreshCurrentUser();
    }
  }

  Future<void> _showTour(UserModel user, {bool force = false}) async {
    if (!force) {
      final hasSeenTour = await SessionPreferences.hasSeenTour(user.id);
      if (hasSeenTour || !context.mounted) {
        return;
      }
    }

    await _presentTourSheet(user);
    await SessionPreferences.markTourSeen(user.id);
  }

  Future<void> _presentTourSheet(UserModel user) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TourSheet(
        user: user,
        onOpenHome: () async => _openTab(0),
        onOpenFeed: () async => _openTab(_feedTabIndex),
        onOpenProfile: () async => _openProfileTab(),
        onOpenVerification: _openVerificationFlow,
        onOpenMyBids: user.userType == 'Driver'
            ? () async => _openTab(2)
            : null,
        onOpenCargoAction: user.userType == 'Cargo'
            ? () async {
                if (VerificationAccess.isApproved(
                  currentUser?.verificationStatus ?? user.verificationStatus,
                )) {
                  await _openCargoPostingFlow();
                  return;
                }
                await _openVerificationFlow();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = _buildPages();
    final navItems = _buildNavItems(localizations);

    return Scaffold(
      // ✅ Removed SlidingUpPanel, now just normal body
      body: pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: navItems,
        onTap: (index) async {
          // Handle Cargo user's "+" button
          if (currentUser?.userType == 'Cargo' && index == _postTabIndex) {
            await _openCargoPostingFlow();
            return;
          }

          // Otherwise switch tabs
          setState(() {
            selectedIndex = index;
          });
        },
      ),
      // ✅ No more extendBody needed since panel is gone
    );
  }
}

class _TourSheet extends StatefulWidget {
  final UserModel user;
  final Future<void> Function() onOpenHome;
  final Future<void> Function() onOpenFeed;
  final Future<void> Function() onOpenProfile;
  final Future<void> Function() onOpenVerification;
  final Future<void> Function()? onOpenMyBids;
  final Future<void> Function()? onOpenCargoAction;

  const _TourSheet({
    required this.user,
    required this.onOpenHome,
    required this.onOpenFeed,
    required this.onOpenProfile,
    required this.onOpenVerification,
    this.onOpenMyBids,
    this.onOpenCargoAction,
  });

  @override
  State<_TourSheet> createState() => _TourSheetState();
}

class _TourSheetState extends State<_TourSheet> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_TourStepData> _steps(AppLocalizations localizations) {
    if (widget.user.userType == 'Cargo') {
      final postingUnlocked = VerificationAccess.isApproved(
        widget.user.verificationStatus,
      );
      return [
        _TourStepData(
          title: localizations.tr('tourCargoHomeTitle'),
          body: localizations.tr('tourCargoHomeBody'),
          icon: Icons.home_outlined,
          accent: const Color(0xFF5B8C85),
          actionLabel: localizations.tr('tourOpenHome'),
          onAction: widget.onOpenHome,
        ),
        _TourStepData(
          title: localizations.tr('tourCargoFeedTitle'),
          body: localizations.tr('tourCargoFeedBody'),
          icon: Icons.rss_feed_outlined,
          accent: const Color(0xFF6B8791),
          actionLabel: localizations.tr('tourOpenFeed'),
          onAction: widget.onOpenFeed,
        ),
        _TourStepData(
          title: localizations.tr('tourCargoVerificationTitle'),
          body: localizations.tr('tourCargoVerificationBody'),
          icon: Icons.verified_user_outlined,
          accent: const Color(0xFFC28C5A),
          actionLabel: localizations.tr('tourOpenVerification'),
          onAction: widget.onOpenVerification,
        ),
        _TourStepData(
          title: localizations.tr('tourCargoPostTitle'),
          body: postingUnlocked
              ? localizations.tr('tourCargoPostReadyBody')
              : localizations.tr('tourCargoPostLockedBody'),
          icon: Icons.add_circle_outline,
          accent: const Color(0xFF6F9A7E),
          actionLabel: postingUnlocked
              ? localizations.tr('tourOpenPost')
              : localizations.tr('tourOpenVerification'),
          onAction: widget.onOpenCargoAction,
        ),
      ];
    }

    return [
      _TourStepData(
        title: localizations.tr('tourDriverHomeTitle'),
        body: localizations.tr('tourDriverHomeBody'),
        icon: Icons.home_outlined,
        accent: const Color(0xFF5B8C85),
        actionLabel: localizations.tr('tourOpenHome'),
        onAction: widget.onOpenHome,
      ),
      _TourStepData(
        title: localizations.tr('tourDriverFeedTitle'),
        body: localizations.tr('tourDriverFeedBody'),
        icon: Icons.rss_feed_outlined,
        accent: const Color(0xFF6B8791),
        actionLabel: localizations.tr('tourOpenFeed'),
        onAction: widget.onOpenFeed,
      ),
      _TourStepData(
        title: localizations.tr('tourDriverBidsTitle'),
        body: localizations.tr('tourDriverBidsBody'),
        icon: Icons.local_offer_outlined,
        accent: const Color(0xFF8E7B67),
        actionLabel: localizations.tr('tourOpenMyBids'),
        onAction: widget.onOpenMyBids,
      ),
      _TourStepData(
        title: localizations.tr('tourDriverVerificationTitle'),
        body: localizations.tr('tourDriverVerificationBody'),
        icon: Icons.verified_user_outlined,
        accent: const Color(0xFFC28C5A),
        actionLabel: localizations.tr('tourOpenVerification'),
        onAction: widget.onOpenVerification,
      ),
    ];
  }

  Future<void> _handleAction(_TourStepData step) async {
    final action = step.onAction;
    if (action == null) {
      return;
    }

    Navigator.of(context).pop();
    await Future<void>.delayed(Duration.zero);
    await action();
  }

  Future<void> _next(List<_TourStepData> steps) async {
    if (_pageIndex >= steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);
    final steps = _steps(localizations);
    final step = steps[_pageIndex];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      localizations.tr('tourQuickTitle'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: localizations.tr('close'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                localizations.tr('tourQuickSubtitle'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppPalette.darkTextSoft : Colors.black54,
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: (_pageIndex + 1) / steps.length,
                  backgroundColor: isDark
                      ? AppPalette.darkSurfaceRaised
                      : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(step.accent),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${localizations.tr('tourStepLabel')} ${_pageIndex + 1} / ${steps.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isDark ? AppPalette.darkTextSoft : Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 340,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: steps.length,
                  onPageChanged: (value) {
                    setState(() {
                      _pageIndex = value;
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = steps[index];
                    final isActive = index == _pageIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppPalette.darkSurfaceRaised
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isActive
                              ? item.accent.withAlpha((0.55 * 255).round())
                              : (isDark
                                    ? AppPalette.darkOutline
                                    : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: item.accent.withAlpha(
                                (0.14 * 255).round(),
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              item.icon,
                              color: item.accent,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.body,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: isDark
                                      ? AppPalette.darkTextSoft
                                      : const Color(0xFF475569),
                                  height: 1.5,
                                ),
                          ),
                          const Spacer(),
                          if (item.actionLabel != null && item.onAction != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => _handleAction(item),
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: Text(item.actionLabel!),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(
                  steps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(
                      right: index == steps.length - 1 ? 0 : 8,
                    ),
                    width: index == _pageIndex ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == _pageIndex
                          ? step.accent
                          : (isDark
                                ? AppPalette.darkOutline
                                : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (_pageIndex == 0)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(localizations.tr('tourSkip')),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(localizations.tr('tourBack')),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _next(steps),
                    child: Text(
                      _pageIndex == steps.length - 1
                          ? localizations.tr('tourStartExploring')
                          : localizations.tr('tourNext'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TourStepData {
  final String title;
  final String body;
  final IconData icon;
  final Color accent;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _TourStepData({
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
    this.actionLabel,
    this.onAction,
  });
}
