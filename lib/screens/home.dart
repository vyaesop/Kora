// home.dart
import 'package:kora/screens/track_loads_screen.dart';
import 'package:flutter/material.dart';
import 'package:kora/screens/post_screen.dart';
import 'package:kora/screens/profile_screen.dart';
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

  int get _profileTabIndex =>
      currentUser?.userType == 'Cargo'
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
      await _maybeShowTour(currentUser!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load user: $e")),
      );
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
    final allowed = await VerificationAccess.ensureVerifiedForAction(
      context,
      expectedUserType: 'Cargo',
      actionLabel: 'post loads',
      onOpenProfile: _openProfileTab,
    );
    if (!allowed || !mounted) return;
    await Navigator.push(
      context,
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
        const ProfileScreen(),
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
        const ProfileScreen(),
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
            icon: const Icon(Icons.home), label: localizations.tr('home')),
        BottomNavigationBarItem(
            icon: const Icon(Icons.rss_feed), label: localizations.tr('feed')),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
          label: localizations.tr('post'),
        ),
        BottomNavigationBarItem(
            icon: const Icon(Icons.inventory_2_outlined),
            label: localizations.tr('myLoads')),
        BottomNavigationBarItem(
            icon: const Icon(Icons.person), label: localizations.tr('profile')),
      ];
    }
    if (currentUser?.userType == 'Driver') {
      return [
        BottomNavigationBarItem(
            icon: const Icon(Icons.home), label: localizations.tr('home')),
        BottomNavigationBarItem(
            icon: const Icon(Icons.rss_feed), label: localizations.tr('feed')),
        BottomNavigationBarItem(
            icon: const Icon(Icons.local_offer),
            label: localizations.tr('myBids')),
        BottomNavigationBarItem(
            icon: const Icon(Icons.person), label: localizations.tr('profile')),
      ];
    }
    return [
      BottomNavigationBarItem(
          icon: const Icon(Icons.home), label: localizations.tr('home')),
      BottomNavigationBarItem(
          icon: const Icon(Icons.rss_feed), label: localizations.tr('feed')),
      BottomNavigationBarItem(
          icon: const Icon(Icons.search), label: localizations.tr('search')),
      BottomNavigationBarItem(
          icon: const Icon(Icons.person), label: localizations.tr('profile')),
    ];
  }

  Future<void> _maybeShowTour(UserModel user) async {
    final hasSeenTour = await SessionPreferences.hasSeenTour(user.id);
    if (hasSeenTour || !mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TourSheet(userType: user.userType),
    );

    await SessionPreferences.markTourSeen(user.id);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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

class _TourSheet extends StatelessWidget {
  final String userType;

  const _TourSheet({required this.userType});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = userType == 'Cargo'
        ? const [
            _TourStepData(
              title: 'Home base first',
              body: 'Your home tab keeps quick actions, recent loads, and suggested drivers together.',
              icon: Icons.home_outlined,
            ),
            _TourStepData(
              title: 'Verification unlocks posting',
              body: 'You can browse everything now, but posting loads stays locked until your national ID is approved from Profile.',
              icon: Icons.verified_user_outlined,
            ),
            _TourStepData(
              title: 'Profile is your control center',
              body: 'Use the profile tab for document uploads, approval status, and account settings.',
              icon: Icons.person_outline,
            ),
          ]
        : const [
            _TourStepData(
              title: 'Find work faster',
              body: 'Use home for suggested loads, then jump into feed or my bids when you want more detail.',
              icon: Icons.local_shipping_outlined,
            ),
            _TourStepData(
              title: 'Verification unlocks bidding',
              body: 'You can explore loads right away, but bidding stays locked until your national ID and driver\'s license are approved.',
              icon: Icons.verified_user_outlined,
            ),
            _TourStepData(
              title: 'Profile keeps you ready',
              body: 'Open profile any time to manage your verification documents and see admin feedback.',
              icon: Icons.person_outline,
            ),
          ];

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
              Text(
                'Quick tour',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'A fast walkthrough so the first session feels clear instead of crowded.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppPalette.darkTextSoft : Colors.black54,
                    ),
              ),
              const SizedBox(height: 18),
              ...steps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(step.icon, color: const Color(0xFF0369A1)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step.body,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? AppPalette.darkTextSoft
                                        : Colors.black54,
                                    height: 1.4,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Start exploring'),
                ),
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

  const _TourStepData({
    required this.title,
    required this.body,
    required this.icon,
  });
}

