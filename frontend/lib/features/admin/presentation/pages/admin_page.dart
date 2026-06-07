import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/admin_remote_datasource.dart';
import '../../domain/entities/pending_guide.dart';
import '../providers/pending_guides_provider.dart';

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final guidesAsync = ref.watch(pendingGuidesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guide Applications'),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(pendingGuidesProvider.future),
        child: guidesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorState(
            message: err.toString(),
            onRetry: () => ref.invalidate(pendingGuidesProvider),
          ),
          data: (guides) => guides.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: guides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _GuideApplicationCard(guide: guides[i]),
                ),
        ),
      ),
    );
  }
}

class _GuideApplicationCard extends ConsumerStatefulWidget {
  const _GuideApplicationCard({required this.guide});
  final PendingGuide guide;

  @override
  ConsumerState<_GuideApplicationCard> createState() =>
      _GuideApplicationCardState();
}

class _GuideApplicationCardState extends ConsumerState<_GuideApplicationCard> {
  bool _processing = false;

  Future<void> _handle({required bool approve}) async {
    final auth = ref.read(authProvider).valueOrNull;
    if (auth is! AuthAuthenticated) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _processing = true);
    try {
      final datasource = ref.read(adminDatasourceProvider);
      if (approve) {
        await datasource.approveGuide(token: auth.token, id: widget.guide.id);
      } else {
        await datasource.rejectGuide(token: auth.token, id: widget.guide.id);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Application accepted' : 'Application rejected',
          ),
        ),
      );
      ref.invalidate(pendingGuidesProvider);
    } on AdminException catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Action failed. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final guide = widget.guide;
    final initial =
        guide.name.trim().isNotEmpty ? guide.name.trim()[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  initial,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  guide.name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.amber.shade700.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'Pending',
                  style: TextStyle(
                    color: Colors.amber.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ContactRow(
            icon: Icons.email_outlined,
            value: guide.email,
          ),
          const SizedBox(height: 8),
          _ContactRow(
            icon: Icons.phone_outlined,
            value: guide.phone?.isNotEmpty == true ? guide.phone! : 'Not provided',
            muted: guide.phone?.isNotEmpty != true,
          ),
          const SizedBox(height: 16),
          if (_processing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handle(approve: false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _handle(approve: true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.value,
    this.muted = false,
  });
  final IconData icon;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: muted
                  ? cs.onSurface.withValues(alpha: 0.45)
                  : cs.onSurface,
              fontStyle: muted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
        if (!muted)
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18),
            color: cs.onSurface.withValues(alpha: 0.5),
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
        Icon(Icons.inbox_outlined,
            size: 56, color: cs.onSurface.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'No pending guide applications',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
        Icon(Icons.error_outline, size: 56, color: cs.error),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
