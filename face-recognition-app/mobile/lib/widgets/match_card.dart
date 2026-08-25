import 'package:flutter/material.dart';

import '../models.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, this.isTop = false});

  final Match match;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isTop ? 3 : 0,
      child: ListTile(
        leading: SizedBox(
          width: 56,
          height: 56,
          child: match.imageUrl == null
              ? const Icon(Icons.person)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(match.imageUrl!, fit: BoxFit.cover),
                ),
        ),
        title: Text(match.displayName),
        subtitle: Text('similarity ${match.score.toStringAsFixed(3)}'),
        trailing: isTop ? const Icon(Icons.star, size: 18) : null,
      ),
    );
  }
}
