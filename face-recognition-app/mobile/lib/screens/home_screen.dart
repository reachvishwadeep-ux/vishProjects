import 'package:flutter/material.dart';

import '../api_client.dart';
import '../image_source.dart';
import 'enroll_screen.dart';
import 'repository_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.images});

  final ApiClient api;
  final ImageSourceService images;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      SearchScreen(api: widget.api, images: widget.images),
      EnrollScreen(api: widget.api, images: widget.images),
      RepositoryScreen(api: widget.api),
    ];

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Identify',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_add),
            label: 'Enrol',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_shared),
            label: 'Repository',
          ),
        ],
      ),
    );
  }
}
