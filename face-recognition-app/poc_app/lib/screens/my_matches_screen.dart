import 'package:flutter/material.dart';

import '../connections/connection_repository.dart';
import '../theme.dart';

class MyMatchesScreen extends StatefulWidget {
  const MyMatchesScreen({super.key, this.repository});

  final ConnectionRepository? repository;

  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen> {
  List<MatchConnection> _connections = const [];
  List<MatchHistoryEntry> _matches = const [];
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = widget.repository;
    if (repository == null) {
      setState(() {
        _loading = false;
        _connections = const [];
        _matches = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final connections = await repository.list();
      final matches = await repository.listMatches();
      if (!mounted) return;
      setState(() {
        _connections = connections;
        _matches = matches;
      });
    } on ConnectionException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _replace(MatchConnection connection) {
    setState(() {
      _connections = [
        for (final current in _connections)
          if (current.id == connection.id) connection else current,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        _connections.where((connection) => connection.unread).length;
    final historyOnly = _matches
        .where((match) => match.connectionId == null)
        .toList(growable: false);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 112),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Matches',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.6,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unreadCount == 0
                            ? 'Potential matches and private connections'
                            : '$unreadCount new connection update'
                                '${unreadCount == 1 ? '' : 's'}',
                        style: const TextStyle(color: brandMuted),
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Refresh matches',
                  onPressed: _loading ? null : _load,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: brandPurple,
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _PrivacyBanner(),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _StateCard(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load matches',
                message: _error!,
                actionLabel: 'Try again',
                onAction: _load,
              )
            else if (_connections.isEmpty && historyOnly.isEmpty)
              const _StateCard(
                icon: Icons.manage_search_rounded,
                title: 'No matches yet',
                message:
                    'ReuniteNow will keep comparing missing and found cases. '
                    'Potential match results and secure cross-account '
                    'connections will appear here.',
              )
            else ...[
              if (_connections.isNotEmpty) ...[
                const _SectionHeading(
                  title: 'Secure connections',
                  message:
                      'Cross-account matches with mutual consent and private '
                      'contact details.',
                ),
                const SizedBox(height: 12),
                ..._connections.map(
                  (connection) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ConnectionCard(
                      connection: connection,
                      repository: widget.repository!,
                      onChanged: _replace,
                    ),
                  ),
                ),
              ],
              if (historyOnly.isNotEmpty) ...[
                const _SectionHeading(
                  title: 'Potential match history',
                  message: 'Current and previous visual comparisons, including '
                      'matches between your own cases.',
                ),
                const SizedBox(height: 12),
                ...historyOnly.map(
                  (match) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _MatchHistoryCard(match: match),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class ConnectionDetailScreen extends StatefulWidget {
  const ConnectionDetailScreen({
    super.key,
    required this.repository,
    required this.connectionId,
  });

  final ConnectionRepository repository;
  final String connectionId;

  @override
  State<ConnectionDetailScreen> createState() => _ConnectionDetailScreenState();
}

class _ConnectionDetailScreenState extends State<ConnectionDetailScreen> {
  MatchConnection? _connection;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final connections = await widget.repository.list();
      if (!mounted) return;
      final matches =
          connections.where((item) => item.id == widget.connectionId);
      setState(() => _connection = matches.isEmpty ? null : matches.first);
    } on ConnectionException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = _connection;
    return Scaffold(
      appBar: AppBar(title: const Text('Secure connection')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              const _PrivacyBanner(),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _StateCard(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load this connection',
                  message: _error!,
                  actionLabel: 'Try again',
                  onAction: _load,
                )
              else if (connection == null)
                const _StateCard(
                  icon: Icons.manage_search_rounded,
                  title: 'Connection not available',
                  message:
                      'This connection is no longer available. Check My Matches '
                      'for current updates.',
                )
              else
                _ConnectionCard(
                  connection: connection,
                  repository: widget.repository,
                  onChanged: (updated) => setState(() => _connection = updated),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(23),
        boxShadow: const [
          BoxShadow(
            color: Color(0x297057F5),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Colors.white, size: 27),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private by design',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Phone numbers and precise locations stay private. '
                  'Both parties must consent before a connection is active.',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: brandInk,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          message,
          style: const TextStyle(
            color: brandMuted,
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _MatchHistoryCard extends StatelessWidget {
  const _MatchHistoryCard({required this.match});

  final MatchHistoryEntry match;

  String get _ownershipLabel {
    if (match.sameAccount) {
      return 'Both cases are yours · no private connection is created';
    }
    if (match.role == 'missing') {
      return 'Your missing-person case';
    }
    if (match.role == 'found') {
      return 'Your found-person case';
    }
    return 'Your cases';
  }

  String get _dateLabel {
    final value = match.createdAt;
    return '${value.month}/${value.day}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (match.score * 100).round();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: brandLavender,
                  backgroundImage: match.imageUrl == null
                      ? null
                      : NetworkImage(match.imageUrl!),
                  child: match.imageUrl == null
                      ? const Icon(Icons.person_search_rounded)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${match.missingSubjectLabel} ↔ '
                        '${match.foundSubjectLabel}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$percentage% visual similarity · matched $_dateLabel',
                        style: const TextStyle(
                          color: brandMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const _StatusPill(
                  label: 'HISTORY',
                  color: brandPurple,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InlineNotice(
              icon: match.sameAccount
                  ? Icons.inventory_2_outlined
                  : Icons.manage_search_rounded,
              text: _ownershipLabel,
            ),
            const SizedBox(height: 12),
            const Text(
              'Similarity is review evidence only—not proof of identity, '
              'guardianship, custody, or a safe handoff.',
              style: TextStyle(
                color: brandMuted,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatefulWidget {
  const _ConnectionCard({
    required this.connection,
    required this.repository,
    required this.onChanged,
  });

  final MatchConnection connection;
  final ConnectionRepository repository;
  final ValueChanged<MatchConnection> onChanged;

  @override
  State<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<_ConnectionCard> {
  String? _error;
  var _busy = false;

  Future<void> _act(
    Future<MatchConnection> Function() action,
    String successMessage,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final connection = await action();
      widget.onChanged(connection);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on ConnectionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = widget.connection;
    final percentage = (connection.score * 100).round();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: brandLavender,
                  backgroundImage: connection.imageUrl == null
                      ? null
                      : NetworkImage(connection.imageUrl!),
                  child: connection.imageUrl == null
                      ? const Icon(Icons.person_search_rounded)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.otherSubjectLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$percentage% similarity candidate · '
                        '${connection.role == 'missing' ? 'found' : 'missing'} '
                        'case',
                        style: const TextStyle(
                          color: brandMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (connection.unread)
                  _StatusPill(
                    label: 'NEW',
                    color: brandPurple,
                  )
                else
                  _StatusPill(
                    label: _statusLabel(connection.status),
                    color: _statusColor(connection.status),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _ConsentProgress(connection: connection),
            const SizedBox(height: 14),
            if (!connection.myConsented)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _act(
                            () => widget.repository.consent(connection.id),
                            'Your consent to connect was recorded.',
                          ),
                  icon: const Icon(Icons.handshake_outlined, size: 19),
                  label: const Text('Consent to connect'),
                ),
              )
            else if (!connection.otherConsented)
              const _InlineNotice(
                icon: Icons.hourglass_top_rounded,
                text: 'Waiting for the other party to consent.',
              )
            else
              const _InlineNotice(
                icon: Icons.handshake_rounded,
                text: 'Both parties consented. Phone numbers remain private; '
                    'messaging and contact sharing are not enabled yet.',
                success: true,
              ),
            if (connection.myConsented) ...[
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _act(
                            () => widget.repository.withdrawConsent(
                              connection.id,
                            ),
                            'Your consent was withdrawn.',
                          ),
                  icon: const Icon(Icons.block_rounded, size: 16),
                  label: const Text('Withdraw consent'),
                ),
              ),
            ],
            if (connection.unread) ...[
              const SizedBox(height: 9),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _act(
                            () => widget.repository.markRead(connection.id),
                            'Marked as read.',
                          ),
                  child: const Text('Mark as read'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Face similarity and mutual consent do not prove identity, '
              'guardianship, custody, or a safe child handoff. Never transfer '
              'a child based on the app alone.',
              style: TextStyle(
                color: brandMuted,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentProgress extends StatelessWidget {
  const _ConsentProgress({required this.connection});

  final MatchConnection connection;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProgressItem(
            label: 'YOU',
            complete: connection.myConsented,
            text: connection.myConsented ? 'Consented' : 'Consent needed',
          ),
        ),
        Container(width: 18, height: 2, color: brandBorder),
        Expanded(
          child: _ProgressItem(
            label: 'OTHER PARTY',
            complete: connection.otherConsented,
            text: connection.otherConsented ? 'Consented' : 'Waiting',
          ),
        ),
      ],
    );
  }
}

class _ProgressItem extends StatelessWidget {
  const _ProgressItem({
    required this.label,
    required this.complete,
    required this.text,
  });

  final String label;
  final bool complete;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: complete ? brandGreen : brandSurfaceStrong,
          child: Icon(
            complete ? Icons.check_rounded : Icons.more_horiz_rounded,
            size: 17,
            color: complete ? Colors.white : brandMuted,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: brandMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.text,
    this.success = false,
  });

  final IconData icon;
  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? brandGreen : brandPurple;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, color: brandPurple, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: brandMuted, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 15),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'connected' || 'ready_to_meet' || 'verified' => 'CONNECTED',
    _ => 'CONSENT',
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'connected' || 'ready_to_meet' || 'verified' => brandGreen,
    _ => brandMuted,
  };
}
