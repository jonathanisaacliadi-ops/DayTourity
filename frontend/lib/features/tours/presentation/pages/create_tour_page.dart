import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/datasources/tours_remote_datasource.dart';
import '../../domain/entities/tour.dart';
import '../../domain/entities/tour_activity.dart' show PricingType;
import '../providers/tours_provider.dart';
import '../widgets/city_search_field.dart';
import '../../../../core/utils/image_picker_platform.dart' as img_picker;

class _ActivityDraft {
  _ActivityDraft({
    required this.name,
    this.description,
    required this.pricingType,
    this.fixedPrice,
    this.minPrice,
    this.maxPrice,
  });

  String name;
  String? description;
  String pricingType;
  double? fixedPrice;
  double? minPrice;
  double? maxPrice;

  CreateActivityRequest toRequest(int order) => CreateActivityRequest(
        name: name,
        description: description,
        pricingType: pricingType,
        fixedPrice: pricingType == 'FIXED' ? fixedPrice : null,
        minPrice: pricingType == 'RANGE' ? minPrice : null,
        maxPrice: pricingType == 'RANGE' ? maxPrice : null,
        order: order,
      );

  String get priceDisplay {
    if (pricingType == 'FIXED') return 'Rp ${_fmt(fixedPrice ?? 0)}';
    return 'Rp ${_fmt(minPrice ?? 0)} – ${_fmt(maxPrice ?? 0)}';
  }

  static String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}

class CreateTourPage extends ConsumerStatefulWidget {
  const CreateTourPage({super.key, this.editingTour});
  final Tour? editingTour;

  bool get isEditing => editingTour != null;

  @override
  ConsumerState<CreateTourPage> createState() => _CreateTourPageState();
}

class _CreateTourPageState extends ConsumerState<CreateTourPage> {
  int _step = 0;

  final _infoFormKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _basePriceCtrl = TextEditingController();


  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  String? _existingCoverImageUrl;
  final List<XFile> _albumPhotos = [];
  final List<Uint8List?> _albumPhotoBytes = [];
  bool _isUploading = false;

  DateTimeRange? _dateRange;
  final List<DateTime> _availableDates = [];

  final List<_ActivityDraft> _activities = [];

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  void initState() {
    super.initState();
    final tour = widget.editingTour;
    if (tour != null) {
      _titleCtrl.text = tour.title;
      _descCtrl.text = tour.description;
      _cityCtrl.text = tour.city;
      _basePriceCtrl.text =
          tour.basePrice > 0 ? tour.basePrice.toStringAsFixed(0) : '';
      _existingCoverImageUrl = tour.coverImageUrl;

      _activities.addAll(tour.activities.map((a) => _ActivityDraft(
            name: a.name,
            description: a.description,
            pricingType: a.pricingType == PricingType.range ? 'RANGE' : 'FIXED',
            fixedPrice: a.fixedPrice,
            minPrice: a.minPrice,
            maxPrice: a.maxPrice,
          )));

      if (tour.availableDates.isNotEmpty) {
        final sorted = [...tour.availableDates]..sort();
        _dateRange = DateTimeRange(start: sorted.first, end: sorted.last);
        _availableDates.addAll(sorted);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    _basePriceCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && !(_infoFormKey.currentState?.validate() ?? false)) return;
    if (_step == 1 && _activities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one activity')),
      );
      return;
    }
    if (_step < 2) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _pickImage() async {
    final file = await img_picker.pickImage();
    if (file == null) return;
    final bytes = kIsWeb ? await file.readAsBytes() : null;
    setState(() {
      _pickedImage = file;
      _pickedImageBytes = bytes;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _availableDates
          ..clear()
          ..addAll(_daysInRange(picked));
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _dateRange = null;
      _availableDates.clear();
    });
  }

  static List<DateTime> _daysInRange(DateTimeRange range) {
    final days = <DateTime>[];
    var day = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    while (!day.isAfter(end)) {
      days.add(day);
      day = day.add(const Duration(days: 1));
    }
    return days;
  }

Future<void> _submit() async {
  final editingTour = widget.editingTour;
  setState(() => _isUploading = true);
  String? coverUrl = _existingCoverImageUrl;
  final List<String> photoUrls = [];
  bool uploadFailed = false;

  try {
    final token = await _storage.read(key: 'access_token') ?? '';
    final ds = ref.read(toursDatasourceProvider);

    if (_pickedImage != null) {
      coverUrl = await ds.uploadImage(token: token, file: _pickedImage!);
    }

    if (editingTour == null) {
      for (final photo in _albumPhotos) {
        try {
          final url = await ds.uploadImage(token: token, file: photo);
          photoUrls.add(url);
        } catch (e) {
          debugPrint('Album photo upload failed: $e');
        }
      }
    }
  } catch (e) {
    uploadFailed = true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _isUploading = false);
  }

  if (uploadFailed) return;

  if (!mounted) return;

  final activityRequests = _activities
      .asMap()
      .entries
      .map((e) => e.value.toRequest(e.key))
      .toList();
  final dateStrings =
      _availableDates.map((d) => d.toIso8601String()).toList();

  if (editingTour != null) {
    final request = UpdateTourRequest(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      basePrice: double.tryParse(_basePriceCtrl.text.trim()) ?? 0,
      coverImageUrl: coverUrl,
      activities: activityRequests,
      availableDates: dateStrings,
    );
    await ref.read(createTourProvider.notifier).editTour(editingTour.id, request);
    return;
  }

  final request = CreateTourRequest(
    title: _titleCtrl.text.trim(),
    description: _descCtrl.text.trim(),
    city: _cityCtrl.text.trim(),
    basePrice: double.tryParse(_basePriceCtrl.text.trim()) ?? 0,
    coverImageUrl: coverUrl,
    photoUrls: photoUrls.isEmpty ? null : photoUrls,
    activities: activityRequests,
    availableDates: dateStrings,
  );

  await ref.read(createTourProvider.notifier).submit(request);
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createState = ref.watch(createTourProvider).valueOrNull;
    final isLoading =
        createState is CreateTourLoading || _isUploading;

ref.listen(createTourProvider, (_, next) {
  next.whenData((state) {
    if (state is CreateTourSuccess) {
      final messenger = ScaffoldMessenger.of(context);
      final tourTitle = state.tour.title;
      final primaryColor = theme.colorScheme.primary;
      final verb = widget.isEditing ? 'updated' : 'created';

      Navigator.pop(context);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Tour "$tourTitle" $verb!'),
          backgroundColor: primaryColor,
        ),
      );
      ref.read(createTourProvider.notifier).reset();
    } else if (state is CreateTourError) {
      final raw = state.message;
      final message = raw.contains('guide')
          ? 'Only guides can ${widget.isEditing ? 'edit' : 'create'} tours. Please sign out and back in if you recently upgraded your account.'
          : raw.replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: theme.colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  });
});

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Tour' : 'Create Tour'),
        centerTitle: true,
      ),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (i) {
          if (i < _step) setState(() => _step = i);
        },
        controlsBuilder: (context, details) => _StepControls(
          step: _step,
          isLoading: isLoading,
          isEditing: widget.isEditing,
          onNext: _next,
          onBack: _back,
          onSubmit: _submit,
        ),
        steps: [
          Step(
            title: const Text('Basic Info'),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.indexed,
            content: _BasicInfoStep(
              formKey: _infoFormKey,
              titleCtrl: _titleCtrl,
              descCtrl: _descCtrl,
              cityCtrl: _cityCtrl,
              basePriceCtrl: _basePriceCtrl,
              pickedImage: _pickedImage,
              pickedImageBytes: _pickedImageBytes,
              existingCoverImageUrl: _existingCoverImageUrl,
              isEditing: widget.isEditing,
              onPickImage: _pickImage,
              albumPhotos: _albumPhotos,
              albumPhotoBytes: _albumPhotoBytes,
              onPickAlbumPhotos: () async {
                final files = await img_picker.pickMultiImage();
                if (files.isEmpty) return;
                final bytesList = await Future.wait(
                  files.map((f) => kIsWeb ? f.readAsBytes() : Future<Uint8List>.value(Uint8List(0))),
                );
                setState(() {
                  _albumPhotos.addAll(files);
                  _albumPhotoBytes.addAll(bytesList.map((b) => b.isEmpty ? null : b));
                });
              },
              onRemoveAlbumPhoto: (i) =>
                  setState(() => _albumPhotos.removeAt(i)),
              dateRange: _dateRange,
              onPickDateRange: _pickDateRange,
              onClearDateRange: _clearDateRange,
            ),
          ),
          Step(
            title: const Text('Activities & Pricing'),
            isActive: _step >= 1,
            state: _step > 1 ? StepState.complete : StepState.indexed,
            content: _ActivitiesStep(
              activities: _activities,
              onAdd: (draft) => setState(() => _activities.add(draft)),
              onRemove: (i) => setState(() => _activities.removeAt(i)),
            ),
          ),
          Step(
            title: const Text('Review & Submit'),
            isActive: _step >= 2,
            state: StepState.indexed,
            content: _ReviewStep(
              title: _titleCtrl.text,
              city: _cityCtrl.text,
              description: _descCtrl.text,
              activities: _activities,
              basePrice: double.tryParse(_basePriceCtrl.text.trim()) ?? 0,
              pickedImage: _pickedImage,
              existingCoverImageUrl: _existingCoverImageUrl,
              albumPhotoCount: _albumPhotos.length,
              dateRange: _dateRange,
            ),
          ),
        ],
      ),
    );
  }
}


class _StepControls extends StatelessWidget {
  const _StepControls({
    required this.step,
    required this.isLoading,
    required this.isEditing,
    required this.onNext,
    required this.onBack,
    required this.onSubmit,
  });

  final int step;
  final bool isLoading;
  final bool isEditing;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  static const _btnStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(120, 48)),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (step < 2)
            ElevatedButton(
              onPressed: onNext,
              style: _btnStyle,
              child: const Text('Continue'),
            ),
          if (step == 2)
            ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: _btnStyle,
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEditing ? 'Save Changes' : 'Publish Tour'),
            ),
          if (step > 0) ...[
            const SizedBox(width: 12),
            TextButton(onPressed: onBack, child: const Text('Back')),
          ],
        ],
      ),
    );
  }
}

class _BasicInfoStep extends StatelessWidget {
  const _BasicInfoStep({
    required this.formKey,
    required this.titleCtrl,
    required this.descCtrl,
    required this.cityCtrl,
    required this.basePriceCtrl,
    required this.pickedImage,
    this.pickedImageBytes,
    this.existingCoverImageUrl,
    this.isEditing = false,
    required this.onPickImage,
    required this.albumPhotos,
    required this.albumPhotoBytes,
    required this.onPickAlbumPhotos,
    required this.onRemoveAlbumPhoto,
    required this.dateRange,
    required this.onPickDateRange,
    required this.onClearDateRange,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController basePriceCtrl;
  final XFile? pickedImage;
  final Uint8List? pickedImageBytes;
  final String? existingCoverImageUrl;
  final bool isEditing;
  final VoidCallback onPickImage;
  final List<XFile> albumPhotos;
  final List<Uint8List?> albumPhotoBytes;
  final VoidCallback onPickAlbumPhotos;
  final ValueChanged<int> onRemoveAlbumPhoto;
  final DateTimeRange? dateRange;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          TextFormField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Tour Title'),
            validator: (v) =>
                (v == null || v.trim().length < 3) ? 'Min 3 characters' : null,
          ),
          const SizedBox(height: 16),
          CitySearchField(
            controller: cityCtrl,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'City is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: descCtrl,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 4,
            validator: (v) =>
                (v == null || v.trim().length < 10) ? 'Min 10 characters' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: basePriceCtrl,
            decoration: const InputDecoration(
              labelText: 'Base Tour Price',
              prefixText: 'Rp ',
              helperText: 'Charged for the tour itself. Activities add on top.',
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final parsed = double.tryParse(v.trim());
              if (parsed == null || parsed < 0) return 'Enter a valid amount';
              return null;
            },
          ),
          const SizedBox(height: 20),
          Text('Cover Photo',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onPickImage,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (pickedImage != null || existingCoverImageUrl != null)
                        ? cs.primary
                        : cs.outline.withValues(alpha: 0.4),
                    width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: pickedImage != null
                  ? _XFilePreview(
                      xfile: pickedImage!,
                      bytes: pickedImageBytes,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 160,
                    )
                  : existingCoverImageUrl != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: existingCoverImageUrl!,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  child: Text('Tap to change',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 40, color: cs.primary.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text('Tap to pick a photo',
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Available Date Range',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 10),
          if (dateRange == null)
            OutlinedButton.icon(
              onPressed: onPickDateRange,
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: const Text('Select date range'),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range_rounded, size: 20, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('dd MMM yyyy').format(dateRange!.start)}  –  ${DateFormat('dd MMM yyyy').format(dateRange!.end)}',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${dateRange!.duration.inDays + 1} day(s) available',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.6),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onPickDateRange,
                    child: const Text('Change'),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: cs.error),
                    tooltip: 'Clear',
                    onPressed: onClearDateRange,
                  ),
                ],
              ),
            ),
          if (isEditing) ...[
            const SizedBox(height: 24),
            Text('Album Photos',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 6),
            Text(
              'Manage album photos from the tour\'s detail page.',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13),
            ),
          ] else ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text('Album Photos',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7))),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Add Photos'),
                  onPressed: onPickAlbumPhotos,
                ),
              ],
            ),
            if (albumPhotos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No album photos yet (optional)',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13),
                ),
              ),
            if (albumPhotos.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: albumPhotos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _XFilePreview(
                          xfile: albumPhotos[i],
                          bytes: i < albumPhotoBytes.length ? albumPhotoBytes[i] : null,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => onRemoveAlbumPhoto(i),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActivitiesStep extends StatelessWidget {
  const _ActivitiesStep({
    required this.activities,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_ActivityDraft> activities;
  final ValueChanged<_ActivityDraft> onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activities.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No activities yet.',
                style:
                    TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5))),
          ),
        ...activities.asMap().entries.map((e) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Text('${e.key + 1}',
                    style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold)),
              ),
              title: Text(e.value.name),
              subtitle: Text(e.value.priceDisplay,
                  style: TextStyle(color: colorScheme.primary)),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                onPressed: () => onRemove(e.key),
              ),
            )),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showAddActivitySheet(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Activity'),
        ),
      ],
    );
  }

  Future<void> _showAddActivitySheet(BuildContext context) async {
    final draft = await showModalBottomSheet<_ActivityDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddActivitySheet(),
    );
    if (draft != null) onAdd(draft);
  }
}
class _AddActivitySheet extends StatefulWidget {
  const _AddActivitySheet();

  @override
  State<_AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends State<_AddActivitySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _fixedCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  String _pricingType = 'FIXED';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _fixedCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = _ActivityDraft(
      name: _nameCtrl.text.trim(),
      description:
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      pricingType: _pricingType,
      fixedPrice: _pricingType == 'FIXED'
          ? double.tryParse(_fixedCtrl.text)
          : null,
      minPrice:
          _pricingType == 'RANGE' ? double.tryParse(_minCtrl.text) : null,
      maxPrice:
          _pricingType == 'RANGE' ? double.tryParse(_maxCtrl.text) : null,
    );
    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Activity', style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Activity Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'FIXED', label: Text('Fixed Price')),
                ButtonSegment(value: 'RANGE', label: Text('Price Range')),
              ],
              selected: {_pricingType},
              onSelectionChanged: (s) =>
                  setState(() => _pricingType = s.first),
            ),
            const SizedBox(height: 16),
            if (_pricingType == 'FIXED')
              TextFormField(
                controller: _fixedCtrl,
                decoration: const InputDecoration(
                    labelText: 'Price (Rp)', prefixText: 'Rp '),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || double.tryParse(v) == null || double.parse(v) <= 0)
                        ? 'Enter a valid price'
                        : null,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Min (Rp)', prefixText: 'Rp '),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Max (Rp)', prefixText: 'Rp '),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final max = double.tryParse(v ?? '');
                        final min = double.tryParse(_minCtrl.text);
                        if (max == null) return 'Invalid';
                        if (min != null && max <= min) return 'Must > min';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Add Activity'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.title,
    required this.city,
    required this.description,
    required this.activities,
    required this.basePrice,
    required this.pickedImage,
    this.existingCoverImageUrl,
    required this.albumPhotoCount,
    required this.dateRange,
  });

  final String title;
  final String city;
  final String description;
  final List<_ActivityDraft> activities;
  final double basePrice;
  final XFile? pickedImage;
  final String? existingCoverImageUrl;
  final int albumPhotoCount;
  final DateTimeRange? dateRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReviewRow(label: 'Title', value: title),
        _ReviewRow(label: 'City', value: city),
        _ReviewRow(
          label: 'Base Price',
          value: 'Rp ${_ActivityDraft._fmt(basePrice)}',
        ),
        _ReviewRow(label: 'Description', value: description),
        _ReviewRow(
          label: 'Cover',
          value: pickedImage != null
              ? '📷 New image selected'
              : (existingCoverImageUrl != null
                  ? 'Existing cover photo kept'
                  : 'No cover photo'),
        ),
        _ReviewRow(
          label: 'Album',
          value: albumPhotoCount > 0
              ? '$albumPhotoCount photo${albumPhotoCount > 1 ? 's' : ''}'
              : 'No album photos',
        ),
        if (dateRange != null)
          _ReviewRow(
            label: 'Dates',
            value:
                '${DateFormat('dd MMM yyyy').format(dateRange!.start)} – ${DateFormat('dd MMM yyyy').format(dateRange!.end)}'
                ' (${dateRange!.duration.inDays + 1} days)',
          ),
        const SizedBox(height: 12),
        Text('Activities (${activities.length})',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...activities.map((a) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(a.name, style: theme.textTheme.bodyMedium),
                  Text(a.priceDisplay,
                      style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            )),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _XFilePreview extends StatelessWidget {
  const _XFilePreview({
    required this.xfile,
    required this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final XFile xfile;
  final Uint8List? bytes;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (kIsWeb) {
      if (bytes != null && bytes!.isNotEmpty) {
        return Image.memory(
          bytes!,
          width: width,
          height: height,
          fit: fit,
        );
      }
      return Container(
        width: width,
        height: height,
        color: cs.primaryContainer,
        child: Icon(Icons.image_outlined, color: cs.primary),
      );
    }

    return Image.file(
      File(xfile.path),
      width: width,
      height: height,
      fit: fit,
    );
  }
}
