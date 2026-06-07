import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/bookings_remote_datasource.dart';
import '../../domain/entities/booking_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final bookingsDatasourceProvider = Provider<BookingsRemoteDatasource>(
  (_) => BookingsRemoteDatasource(),
);

final guideBookingsProvider =
    AutoDisposeFutureProvider<List<BookingEntity>>((ref) async {
  final auth = ref.watch(authProvider).valueOrNull;
  if (auth is! AuthAuthenticated) return const [];
  final ds = ref.watch(bookingsDatasourceProvider);
  return ds.getGuideBookings(token: auth.token);
});
