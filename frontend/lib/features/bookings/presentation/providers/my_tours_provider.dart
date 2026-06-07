import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/bookings_remote_datasource.dart';
import '../../domain/entities/booking_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final _bookingsDatasourceProvider = Provider<BookingsRemoteDatasource>(
  (_) => BookingsRemoteDatasource(),
);

class MyToursState {
  const MyToursState({
    this.bookings = const [],
    this.isLoading = false,
    this.errorMessage,
  });
 
  final List<BookingEntity> bookings;
  final bool isLoading;
  final String? errorMessage;
 
  bool get hasError => errorMessage != null;
 
  MyToursState copyWith({
    List<BookingEntity>? bookings,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MyToursState(
      bookings:     bookings ?? this.bookings,
      isLoading:    isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
 
class MyToursNotifier extends AutoDisposeAsyncNotifier<MyToursState> {
  @override
  Future<MyToursState> build() async {
    return _fetchTours();
  }
 
  Future<MyToursState> _fetchTours({String? status}) async {
    final authState = ref.read(authProvider).valueOrNull;
    if (authState is! AuthAuthenticated) {
      return const MyToursState(errorMessage: 'Please log in first.');
    }
 
    try {
      final datasource = ref.read(_bookingsDatasourceProvider);
      final bookings = await datasource.getMyTours(
        token: authState.token,
        status: status,
      );
      return MyToursState(bookings: bookings);
    } on BookingsException catch (e) {
      return MyToursState(errorMessage: e.message);
    } catch (e) {
      return MyToursState(errorMessage: 'Something went wrong. Please try again.');
    }
  }

  Future<void> refresh() async {
    final current = state.valueOrNull ?? const MyToursState();
    state = AsyncData(current.copyWith(isLoading: true));
    state = AsyncData(await _fetchTours());
  }
}
 
final myToursProvider =
    AsyncNotifierProvider.autoDispose<MyToursNotifier, MyToursState>(
  MyToursNotifier.new,
);