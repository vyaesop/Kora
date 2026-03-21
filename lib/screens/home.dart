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
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/app_localizations.dart';

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
      currentUser?.userType == 'Cargo' || currentUser?.userType == 'Driver'
          ? 4
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
          onPostLoad: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PostScreen()),
            );
          },
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
        const FeedScreen(),
        const MyBidsScreen(),
        const SearchScreen(),
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
            icon: const Icon(Icons.location_on),
            label: localizations.tr('track')),
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
            icon: const Icon(Icons.search),
            label: localizations.tr('search')),
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PostScreen()),
            );
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

