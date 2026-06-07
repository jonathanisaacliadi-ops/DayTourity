import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/datasources/tours_remote_datasource.dart';
import '../../domain/entities/tour.dart';


final toursDatasourceProvider = Provider<ToursRemoteDatasource>(
  (_) => ToursRemoteDatasource(),
);

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class ToursFilter {
  const ToursFilter({this.city, this.priceCategory});
  final String? city;
  final String? priceCategory;

  @override
  bool operator ==(Object other) =>
      other is ToursFilter &&
      other.city == city &&
      other.priceCategory == priceCategory;

  @override
  int get hashCode => Object.hash(city, priceCategory);
}

final toursProvider = FutureProvider.family<List<Tour>, ToursFilter>(
  (ref, filter) async {
    final token = await _storage.read(key: 'access_token') ?? '';
    return ref.watch(toursDatasourceProvider).getRecommended(
          token: token,
          city: filter.city,
          priceCategory: filter.priceCategory,
        );
  },
);

final tourDetailProvider = FutureProvider.family<Tour, String>(
  (ref, id) async {
    final token = await _storage.read(key: 'access_token') ?? '';
    return ref.watch(toursDatasourceProvider).getTourById(
          token: token,
          id: id,
        );
  },
);

sealed class CreateTourState {
  const CreateTourState();
}

final class CreateTourIdle extends CreateTourState {
  const CreateTourIdle();
}

final class CreateTourLoading extends CreateTourState {
  const CreateTourLoading();
}

final class CreateTourSuccess extends CreateTourState {
  const CreateTourSuccess(this.tour);
  final Tour tour;
}

final class CreateTourError extends CreateTourState {
  const CreateTourError(this.message);
  final String message;
}

class CreateTourNotifier extends AsyncNotifier<CreateTourState> {
  @override
  Future<CreateTourState> build() async => const CreateTourIdle();

  Future<void> submit(CreateTourRequest request) async {
    state = const AsyncData(CreateTourLoading());
    try {
      final token = await _storage.read(key: 'access_token') ?? '';
      final tour = await ref.read(toursDatasourceProvider).createTour(
            token: token,
            request: request,
          );
      ref.invalidate(toursProvider);
      state = AsyncData(CreateTourSuccess(tour));
    } catch (e) {
      state = AsyncData(CreateTourError(e.toString()));
    }
  }

  Future<void> editTour(String tourId, UpdateTourRequest request) async {
    state = const AsyncData(CreateTourLoading());
    try {
      final token = await _storage.read(key: 'access_token') ?? '';
      final tour = await ref.read(toursDatasourceProvider).updateTour(
            token: token,
            id: tourId,
            request: request,
          );
      ref.invalidate(toursProvider);
      ref.invalidate(tourDetailProvider(tourId));
      state = AsyncData(CreateTourSuccess(tour));
    } catch (e) {
      state = AsyncData(CreateTourError(e.toString()));
    }
  }

  void reset() => state = const AsyncData(CreateTourIdle());
}

final createTourProvider =
    AsyncNotifierProvider<CreateTourNotifier, CreateTourState>(
  CreateTourNotifier.new,
);

final deleteTourProvider = FutureProvider.family.autoDispose<void, String>(
  (ref, tourId) async {
    final token = await _storage.read(key: 'access_token') ?? '';
    await ref.read(toursDatasourceProvider).deleteTour(
          token: token,
          id: tourId,
        );
    ref.invalidate(toursProvider);
  },
);

typedef _TourPhotoParam = ({String tourId, String url});
typedef _DeletePhotoParam = ({String tourId, String photoId});

final addPhotoProvider =
    FutureProvider.family.autoDispose<void, _TourPhotoParam>(
  (ref, p) async {
    final token = await _storage.read(key: 'access_token') ?? '';
    await ref.read(toursDatasourceProvider).addPhoto(
          token: token,
          tourId: p.tourId,
          url: p.url,
        );
  },
);

final deletePhotoProvider =
    FutureProvider.family.autoDispose<void, _DeletePhotoParam>(
  (ref, p) async {
    final token = await _storage.read(key: 'access_token') ?? '';
    await ref.read(toursDatasourceProvider).deletePhoto(
          token: token,
          tourId: p.tourId,
          photoId: p.photoId,
        );
  },
);
