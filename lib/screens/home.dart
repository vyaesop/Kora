// home.dart
import 'package:Kora/screens/TrackLoadsScreen.dart';
import 'package:flutter/material.dart';
// ← Can be removed after update
import 'package:Kora/screens/post_screen.dart';
import 'package:Kora/screens/profile_screen.dart';
import 'package:Kora/screens/feed.dart';
import 'package:Kora/screens/search.dart';
import 'package:Kora/screens/my_bids.dart'; // Add this import
import 'package:Kora/model/user.dart';
// removed unused geolocator imports
import 'package:Kora/utils/driver_location_service.dart';
import 'package:Kora/screens/pre_feed_cargo.dart';
import 'package:Kora/screens/pre_feed_driver.dart';
import 'package:Kora/utils/backend_auth_service.dart';

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
  int selectedIndex = 1;
  // Remove PanelController since we're not using sliding panel anymore
  UserModel? currentUser;
  bool isLoading = true;
  DriverLocationService? _locationService; // Make it nullable
  bool _prefeedLoaded = false;
  bool _showPrefeed = false;

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
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      setState(() {
        currentUser = sessionUser;
        selectedIndex = _feedTabIndex;
      });
      await _checkAndStartLocationUpdates(currentUser!);
      _loadPrefeedFlag();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load user: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _loadPrefeedFlag() {
    if (!mounted) return;
    setState(() {
      _showPrefeed = true;
      _prefeedLoaded = true;
    });
  }

  Future<void> _markPrefeedSeen({bool goToFeed = true}) async {
    if (!mounted) return;
    setState(() {
      _showPrefeed = false;
      if (goToFeed) {
        selectedIndex = _feedTabIndex;
      }
    });
  }

  void _openProfileTab() {
    if (!mounted) return;
    setState(() {
      selectedIndex = _profileTabIndex;
      _showPrefeed = false;
    });
  }

  void _openTab(int index) {
    if (!mounted) return;
    setState(() {
      selectedIndex = index;
      _showPrefeed = false;
    });
  }

  // Dynamically build pages based on user type
  List<Widget> get _pages {
    if (currentUser?.userType == 'Cargo') {
      return [
        const FeedScreen(),
        const FeedScreen(),
        const SizedBox(), // Placeholder for the plus button
        const TrackLoadsScreen(),
        const ProfileScreen(),
      ];
    } else if (currentUser?.userType == 'Driver') {
      return [
        const FeedScreen(),
        const FeedScreen(),
        const MyBidsScreen(),
        const SearchScreen(),
        const ProfileScreen(),
      ];
    } else {
      return [
        const FeedScreen(),
        const FeedScreen(),
        const SearchScreen(),
        const ProfileScreen(),
      ];
    }
  }

  // Dynamically build bottom nav items
  List<BottomNavigationBarItem> get _navItems {
    if (currentUser?.userType == 'Cargo') {
      return [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.rss_feed), label: 'Feed'),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF000000),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
          label: '',
        ),
        const BottomNavigationBarItem(
            icon: Icon(Icons.location_on), label: 'Track'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.person), label: 'Profile'),
      ];
    } else if (currentUser?.userType == 'Driver') {
      return [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.rss_feed), label: 'Feed'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.local_offer), label: 'My Bids'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.search), label: 'Search'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.person), label: 'Profile'),
      ];
    } else {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.rss_feed), label: 'Feed'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_prefeedLoaded && currentUser != null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showPrefeed && currentUser != null) {
      if (currentUser!.userType == 'Cargo') {
        return PreFeedCargoScreen(
          user: currentUser!,
          onContinueToFeed: _markPrefeedSeen,
          onPostLoad: () async {
            await _markPrefeedSeen(goToFeed: false);
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PostScreen()),
            );
          },
          onOpenProfile: _openProfileTab,
          onSelectTab: _openTab,
        );
      }
      if (currentUser!.userType == 'Driver') {
        return PreFeedDriverScreen(
          user: currentUser!,
          onContinueToFeed: _markPrefeedSeen,
          onOpenProfile: _openProfileTab,
          onSelectTab: _openTab,
        );
      }
    }

    final pages = _pages;
    final navItems = _navItems;

    return Scaffold(
      // ✅ Removed SlidingUpPanel, now just normal body
      body: pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: const Color(0xFF000000),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: navItems,
        onTap: (index) async {
          // Handle Pre-feed tab (always index 0)
          if (index == 0) {
            await _openPrefeedScreen();
            return;
          }

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

  Future<void> _openPrefeedScreen() async {
    if (!mounted || currentUser == null) return;
    if (currentUser!.userType == 'Cargo') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PreFeedCargoScreen(
            user: currentUser!,
            onContinueToFeed: () {
              Navigator.of(context).pop();
              _openTab(_feedTabIndex);
            },
            onPostLoad: () async {
              Navigator.of(context).pop();
              if (!mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PostScreen()),
              );
            },
            onOpenProfile: () {
              Navigator.of(context).pop();
              _openProfileTab();
            },
            onSelectTab: (int idx) {
              Navigator.of(context).pop();
              _openTab(idx);
            },
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PreFeedDriverScreen(
            user: currentUser!,
            onContinueToFeed: () {
              Navigator.of(context).pop();
              _openTab(_feedTabIndex);
            },
            onOpenProfile: () {
              Navigator.of(context).pop();
              _openProfileTab();
            },
            onSelectTab: (int idx) {
              Navigator.of(context).pop();
              _openTab(idx);
            },
          ),
        ),
      );
    }
  }
}
