import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/admin_remote_datasource.dart';
import '../../domain/entities/pending_guide.dart';

final adminDatasourceProvider = Provider<AdminRemoteDatasource>(
  (_) => AdminRemoteDatasource(),
);

final pendingGuidesProvider =
    FutureProvider.autoDispose<List<PendingGuide>>((ref) async {
  final authState = ref.watch(authProvider).valueOrNull;
  if (authState is! AuthAuthenticated) {
    throw const AdminException('Silakan login kembali.');
  }
  final datasource = ref.watch(adminDatasourceProvider);
  return datasource.fetchPendingGuides(token: authState.token);
});
