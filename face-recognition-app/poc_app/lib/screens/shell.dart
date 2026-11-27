import 'package:flutter/material.dart';

import '../app_state.dart';
import '../auth/auth_controller.dart';
import '../connections/connection_repository.dart';
import '../notifications/push_notification_controller.dart';
import '../repository/case_repository.dart';
import 'match_screen.dart';
import 'my_cases_screen.dart';
import 'my_matches_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.state,
    this.auth,
    this.cases,
    this.connections,
    this.pushNotifications,
  });

  final AppState state;
  final AuthController? auth;
  final CaseRepository? cases;
  final ConnectionRepository? connections;
  final PushNotificationController? pushNotifications;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  @override
  void initState() {
    super.initState();
    widget.pushNotifications?.addListener(_handlePushNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePushNotification();
    });
  }

  @override
  void dispose() {
    widget.pushNotifications?.removeListener(_handlePushNotification);
    super.dispose();
  }

  void _handlePushNotification() {
    if (!mounted) return;
    final controller = widget.pushNotifications;
    if (controller == null) return;
    if (controller.takeForegroundAlert()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Potential match—open ReuniteNow.')),
      );
    }
    final connectionId = controller.takePendingConnectionId();
    final repository = widget.connections;
    if (connectionId == null || repository == null) return;
    setState(() => _index = 2);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConnectionDetailScreen(
          repository: repository,
          connectionId: connectionId,
        ),
      ),
    );
  }

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
              MyCasesScreen(
                repository: widget.cases,
                active: _index == 1,
              ),
              MyMatchesScreen(repository: widget.connections),
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
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder_shared_outlined),
                    selectedIcon: Icon(Icons.folder_shared_rounded),
                    label: 'Cases',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.favorite_border_rounded),
                    selectedIcon: Icon(Icons.favorite_rounded),
                    label: 'Matches',
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
