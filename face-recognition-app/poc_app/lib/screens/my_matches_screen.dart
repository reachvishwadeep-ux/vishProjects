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
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final connections = await repository.list();
      if (!mounted) return;
      setState(() => _connections = connections);
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
                            ? 'Private match and consent updates'
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
            else if (_connections.isEmpty)
              const _StateCard(
                icon: Icons.manage_search_rounded,
                title: 'No connections yet',
                message:
                    'MatchSnap will keep comparing missing and found cases. '
                    'A private update will appear here when a candidate match '
                    'is found.',
              )
            else
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
                  'Phone numbers and precise locations are never shown. '
                  'Both parties must consent before meeting codes appear.',
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
  final _codeController = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

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
      _codeController.clear();
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
                            'Your consent was recorded.',
                          ),
                  icon: const Icon(Icons.handshake_outlined, size: 19),
                  label: const Text('Consent to a safe meeting'),
                ),
              )
            else if (!connection.otherConsented)
              const _InlineNotice(
                icon: Icons.hourglass_top_rounded,
                text: 'Waiting for the other party to consent.',
              )
            else
              _MeetingCodePanel(
                connection: connection,
                codeController: _codeController,
                busy: _busy,
                onVerify: () => _act(
                  () => widget.repository.verifyMeetingCode(
                    connection.id,
                    _codeController.text,
                  ),
                  'The other party’s code was verified.',
                ),
                onRenew: () => _act(
                  () => widget.repository.renewMeetingCode(connection.id),
                  'New meeting codes are ready.',
                ),
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
                            'Your consent was withdrawn and codes were revoked.',
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
              'Face similarity is only a candidate signal. Meeting codes '
              'confirm account presence—not identity, guardianship, custody, '
              'or a safe child handoff. Never transfer a child based on the '
              'app alone.',
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

class _MeetingCodePanel extends StatelessWidget {
  const _MeetingCodePanel({
    required this.connection,
    required this.codeController,
    required this.busy,
    required this.onVerify,
    required this.onRenew,
  });

  final MatchConnection connection;
  final TextEditingController codeController;
  final bool busy;
  final VoidCallback onVerify;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    if (connection.status == 'verified') {
      return const _InlineNotice(
        icon: Icons.verified_user_rounded,
        text: 'Both parties verified each other’s one-time meeting code.',
        success: true,
      );
    }
    final code = connection.meetingCode;
    final expiresAt = connection.meetingCodeExpiresAt;
    final activeCodeWasConsumed = code == null &&
        connection.otherVerifiedPeer &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now());
    if (code == null && !activeCodeWasConsumed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InlineNotice(
            icon: Icons.timer_off_outlined,
            text: 'The meeting codes expired or were already used.',
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: busy ? null : onRenew,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Create new meeting codes'),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brandLavender,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (code != null) ...[
            const Text(
              'YOUR ONE-TIME CODE',
              style: TextStyle(
                color: brandPurple,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              code,
              style: const TextStyle(
                color: brandInk,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 7,
              ),
            ),
            Text(
              _expiryText(expiresAt),
              style: const TextStyle(color: brandMuted, fontSize: 10),
            ),
          ] else ...[
            const _InlineNotice(
              icon: Icons.verified_outlined,
              text:
                  'The other party verified your code. Enter their code to complete verification.',
              success: true,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Other party’s code',
              hintText: '000000',
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: busy || connection.myVerifiedPeer ? null : onVerify,
              icon: const Icon(Icons.key_rounded),
              label: Text(
                connection.myVerifiedPeer
                    ? 'Other code verified'
                    : 'Verify other code',
              ),
            ),
          ),
        ],
      ),
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
    'ready_to_meet' => 'CODES READY',
    'verified' => 'VERIFIED',
    _ => 'CONSENT',
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'verified' => brandGreen,
    'ready_to_meet' => brandPurple,
    _ => brandMuted,
  };
}

String _expiryText(DateTime? expiresAt) {
  if (expiresAt == null) return 'Short-lived code';
  final remaining = expiresAt.difference(DateTime.now());
  if (remaining.isNegative) return 'Expired';
  final minutes = remaining.inMinutes + 1;
  return 'Expires in about $minutes minute${minutes == 1 ? '' : 's'}';
}
