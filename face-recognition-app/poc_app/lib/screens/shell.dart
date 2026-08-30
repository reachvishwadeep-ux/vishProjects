import 'package:flutter/material.dart';

import '../app_state.dart';
import 'gallery_screen.dart';
import 'match_screen.dart';
import 'my_matches_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state});

  final AppState state;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              MatchScreen(state: widget.state),
              const MyMatchesScreen(),
              GalleryScreen(state: widget.state),
              const ProfileScreen(),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8E9EF))),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.photo_camera_outlined),
                  selectedIcon: Icon(Icons.photo_camera_rounded),
                  label: 'Upload',
                ),
                NavigationDestination(
                  icon: Icon(Icons.cancel_outlined),
                  selectedIcon: Icon(Icons.cancel_rounded),
                  label: 'My Matches',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_border_rounded),
                  selectedIcon: Icon(Icons.bookmark_rounded),
                  label: 'Saved Info',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
