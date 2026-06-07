import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../admin/presentation/pages/admin_page.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/active_mode_provider.dart';

const _prefMeta = {
  PricePreference.budget: (
    label: 'Budget',
    icon: Icons.savings_outlined,
    desc: 'Affordable tours that give great value',
  ),
  PricePreference.standard: (
    label: 'Standard',
    icon: Icons.tune_outlined,
    desc: 'A balance of quality and price',
  ),
  PricePreference.premium: (
    label: 'Premium',
    icon: Icons.workspace_premium_outlined,
    desc: 'Top-tier experiences, no compromises',
  ),
};

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme      = Theme.of(context);
    final cs         = theme.colorScheme;
    final authState  = ref.watch(authProvider).valueOrNull;
    final user       = authState is AuthAuthenticated ? authState.user : null;
    final activeMode = ref.watch(activeModeProvider);
    final role       = user?.role.toUpperCase() ?? 'USER';
    final isGuide    = role == 'GUIDE';
    final isPending  = role == 'PENDING_GUIDE';
    final isAdmin    = role == 'ADMIN';
    final isGuideMode = activeMode == 'GUIDE';

    final initial = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()[0].toUpperCase()
        : '?';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
                  ),
                ),
              ),
              Positioned(
                top: -30, right: -30,
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                top: 20, right: 60,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -44,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16, offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: cs.primaryContainer,
                    child: Text(initial,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 8),
            child: Column(children: [
              Text(user?.name ?? '—',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(user?.email ?? '—',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                _Badge(
                  label: switch (role) {
                    'GUIDE'         => 'Verified Guide',
                    'PENDING_GUIDE' => 'Pending Guide',
                    'ADMIN'         => 'Admin',
                    _               => 'Explorer',
                  },
                  color: switch (role) {
                    'GUIDE'         => cs.primary,
                    'PENDING_GUIDE' => Colors.amber.shade700,
                    'ADMIN'         => Colors.deepOrange,
                    _               => cs.secondary,
                  },
                ),
                if (isGuide && !isGuideMode)
                  _Badge(label: 'User Mode', color: cs.secondary),
              ]),
            ]),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Divider(color: cs.outline.withValues(alpha: 0.2)),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text('Settings',
                style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    letterSpacing: 1)),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.list(children: [
            _SettingsTile(
              icon: Icons.tune_outlined,
              title: 'Price Preference',
              subtitle: user?.pricePreference.name.toUpperCase() ?? 'STANDARD',
              subtitleColor: cs.primary,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPriceSheet(context, ref, user?.pricePreference),
            ),
            const SizedBox(height: 8),
            if (isAdmin)
              _SettingsTile(
                icon: Icons.admin_panel_settings_outlined,
                iconColor: Colors.deepOrange,
                title: 'Guide Applications',
                subtitle: 'Review users applying to be guides',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPage()),
                ),
              )
            else if (isGuide)
              _GuideModeToggleTile(
                isGuideMode: isGuideMode,
                onChanged: (m) => ref.read(activeModeProvider.notifier).setMode(m),
              )
            else if (isPending)
              _SettingsTile(
                icon: Icons.hourglass_top_outlined,
                iconColor: Colors.amber.shade700,
                title: 'Guide Verification',
                subtitle: 'Your application is under review',
                trailing: _Badge(label: 'Pending', color: Colors.amber.shade700),
              )
            else
              _SettingsTile(
                icon: Icons.verified_user_outlined,
                title: 'Become a Guide',
                subtitle: 'Share your local knowledge',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showBecomeGuideSheet(context, ref),
              ),
          ]),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Divider(color: cs.outline.withValues(alpha: 0.2)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          sliver: SliverList.list(children: [
            _SettingsTile(
              icon: Icons.logout,
              iconColor: cs.error,
              title: 'Sign Out',
              titleColor: cs.error,
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text('More profile features coming soon',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.28))),
            ),
          ]),
        ),
      ],
    );
  }

  void _showPriceSheet(BuildContext ctx, WidgetRef ref, PricePreference? cur) =>
      showModalBottomSheet(
        context: ctx, isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _PricePreferenceSheet(
            current: cur ?? PricePreference.standard),
      );

  void _showBecomeGuideSheet(BuildContext ctx, WidgetRef ref) =>
      showModalBottomSheet(
        context: ctx, isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const _BecomeGuideSheet(),
      );
}


class _SettingsTile extends StatefulWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.iconColor,
    this.titleColor,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final Color? iconColor, titleColor;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered && widget.onTap != null
                ? cs.primary.withValues(alpha: 0.04)
                : cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: (widget.iconColor ?? cs.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, size: 20,
                  color: widget.iconColor ?? cs.primary),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: widget.titleColor ?? cs.onSurface,
                  )),
                if (widget.subtitle != null)
                  Text(widget.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: widget.subtitleColor
                          ?? cs.onSurface.withValues(alpha: 0.5),
                    )),
              ],
            )),
            if (widget.trailing != null) ...[
              const SizedBox(width: 8),
              widget.trailing!,
            ],
          ]),
        ),
      ),
    );
  }
}

class _GuideModeToggleTile extends StatelessWidget {
  const _GuideModeToggleTile({required this.isGuideMode, required this.onChanged});
  final bool isGuideMode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isGuideMode ? cs.primary.withValues(alpha: 0.04) : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGuideMode
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outline.withValues(alpha: 0.18),
          width: isGuideMode ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: (isGuideMode ? cs.primary : cs.onSurface).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isGuideMode ? Icons.badge_outlined : Icons.person_outline_rounded,
            size: 20,
            color: isGuideMode ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Browsing Mode',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Text(
            isGuideMode
                ? 'Guide Mode — your tours & FAB are visible'
                : 'User Mode — browsing as a regular user',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
          ),
        ])),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: isGuideMode ? 'GUIDE' : 'USER',
            isDense: true,
            borderRadius: BorderRadius.circular(12),
            items: [
              DropdownMenuItem(value: 'GUIDE',
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.badge_outlined, size: 15, color: cs.primary),
                    const SizedBox(width: 6),
                    Text('Guide Mode', style: TextStyle(
                        fontSize: 13, color: cs.primary, fontWeight: FontWeight.w600)),
                  ])),
              DropdownMenuItem(value: 'USER',
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_outline_rounded, size: 15,
                        color: cs.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Text('User Mode', style: TextStyle(
                        fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6))),
                  ])),
            ],
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label; final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}


class _BecomeGuideSheet extends ConsumerStatefulWidget {
  const _BecomeGuideSheet();
  @override
  ConsumerState<_BecomeGuideSheet> createState() => _BecomeGuideSheetState();
}

class _BecomeGuideSheetState extends ConsumerState<_BecomeGuideSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider).valueOrNull;
    if (authState is AuthAuthenticated) {
      _emailController.text = authState.user.email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    final err = await ref.read(authProvider.notifier).becomeGuide(
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
        );
    if (!mounted) return;
    if (err != null) {
      setState(() { _error = err; _loading = false; });
    } else {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Your guide submission has been sent, Wait a couple days for a message back',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.verified_user_outlined, color: cs.primary)),
            const SizedBox(width: 14),
            Text('Become a Guide',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          Text('Share your contact details so an admin can review your '
               'application. Your current role stays the same until approval.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.7), height: 1.5)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_loading,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Email is required';
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            enabled: !_loading,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Phone number is required';
              if (value.length < 6) return 'Enter a valid phone number';
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.error_outline, color: cs.error, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: TextStyle(color: cs.error, fontSize: 13))),
              ])),
          ],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Application'),
            )),
          ]),
        ]),
      ),
    );
  }
}

class _PricePreferenceSheet extends ConsumerStatefulWidget {
  const _PricePreferenceSheet({required this.current});
  final PricePreference current;
  @override
  ConsumerState<_PricePreferenceSheet> createState() => _PricePreferenceSheetState();
}

class _PricePreferenceSheetState extends ConsumerState<_PricePreferenceSheet> {
  late PricePreference _selected;
  bool _loading = false;
  String? _error;

  @override
  void initState() { super.initState(); _selected = widget.current; }

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; });
    final err = await ref.read(authProvider.notifier).updatePreferences(_selected);
    if (!mounted) return;
    if (err != null) { setState(() { _error = err; _loading = false; }); }
    else Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2)))),
        Text('Price Preference',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text("We'll filter tours to match your budget.",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 20),
        ...PricePreference.values.map((pref) {
          final meta     = _prefMeta[pref]!;
          final selected = _selected == pref;
          return GestureDetector(
            onTap: () => setState(() => _selected = pref),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: selected ? cs.primary.withValues(alpha: 0.08)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Icon(meta.icon,
                    color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(meta.label, style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? cs.primary : cs.onSurface)),
                  Text(meta.desc, style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.55))),
                ])),
                if (selected) Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
              ]),
            ),
          );
        }),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.error_outline, color: cs.error, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!,
                  style: TextStyle(color: cs.error, fontSize: 13))),
            ])),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(
              onPressed: _loading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(
            onPressed: (_loading || _selected == widget.current) ? null : _save,
            child: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save'),
          )),
        ]),
      ]),
    );
  }
}