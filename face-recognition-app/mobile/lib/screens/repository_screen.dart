import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';

class RepositoryScreen extends StatefulWidget {
  const RepositoryScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<RepositoryScreen> createState() => _RepositoryScreenState();
}

class _RepositoryScreenState extends State<RepositoryScreen> {
  late Future<List<Person>> _people;

  @override
  void initState() {
    super.initState();
    _people = widget.api.listPersons();
  }

  void _reload() => setState(() => _people = widget.api.listPersons());

  Future<void> _delete(Person person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${person.displayName}?'),
        content: const Text(
          'This permanently erases their photos and face embeddings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.api.deletePerson(person.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repository'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Person>>(
        future: _people,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load: ${snapshot.error}'));
          }
          final people = snapshot.data ?? const <Person>[];
          if (people.isEmpty) {
            return const Center(child: Text('No one enrolled yet.'));
          }
          return ListView.separated(
            itemCount: people.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final person = people[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: person.faceUrls.isEmpty
                      ? null
                      : NetworkImage(person.faceUrls.first),
                  child:
                      person.faceUrls.isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text(person.displayName),
                subtitle: Text('${person.faceUrls.length} photo(s)'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(person),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
