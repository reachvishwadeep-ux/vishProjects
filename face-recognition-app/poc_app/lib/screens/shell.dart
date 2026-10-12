import 'package:flutter/material.dart';

import '../app_state.dart';
import '../auth/auth_controller.dart';
import '../connections/connection_repository.dart';
import 'gallery_screen.dart';
import 'match_screen.dart';
import 'my_matches_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.state,
    this.auth,
    this.connections,
  });

  final AppState state;
  final AuthController? auth;
  final ConnectionRepository? connections;

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
          extendBody: true,
          body: IndexedStack(
            index: _index,
            children: [
              MatchScreen(state: widget.state),
              MyMatchesScreen(repository: widget.connections),
              GalleryScreen(state: widget.state),
              ProfileScreen(auth: widget.auth),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF0EDF5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22382E64),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) {
                  setState(() => _index = value);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.add_photo_alternate_outlined),
                    selectedIcon: Icon(Icons.add_photo_alternate_rounded),
                    label: 'Upload',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.favorite_border_rounded),
                    selectedIcon: Icon(Icons.favorite_rounded),
                    label: 'My Matches',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder_copy_outlined),
                    selectedIcon: Icon(Icons.folder_copy_rounded),
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
          ),
        );
      },
    );
  }
}
