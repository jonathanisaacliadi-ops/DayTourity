import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';


class ActiveModeNotifier extends StateNotifier<String> {
  ActiveModeNotifier(super.initialMode);

  void setMode(String mode) => state = mode;

  void toggle() => state = (state == 'GUIDE') ? 'USER' : 'GUIDE';
}

final activeModeProvider =
    StateNotifierProvider<ActiveModeNotifier, String>((ref) {
  final auth = ref.watch(authProvider).valueOrNull;
  final initialRole =
      (auth is AuthAuthenticated) ? auth.user.role.toUpperCase() : 'USER';
  return ActiveModeNotifier(initialRole);
});
