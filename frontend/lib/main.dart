import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/shell/presentation/pages/main_shell.dart';

void main() {
  runApp(const ProviderScope(child: LokaGuideApp()));
}

class LokaGuideApp extends StatelessWidget {
  const LokaGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'daytourity',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightNatureTheme,
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends ConsumerWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

    return authAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const LoginPage(),
      data: (state) =>
          state is AuthAuthenticated ? const MainShell() : const LoginPage(),
    );
  }
}
