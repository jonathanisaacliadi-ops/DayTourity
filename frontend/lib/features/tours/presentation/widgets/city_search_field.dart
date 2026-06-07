import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class _CityResult {
  const _CityResult({
    required this.displayName,
    required this.cityName,
    required this.subtitle,
    required this.lat,
    required this.lon,
  });

  final String displayName;
  final String cityName;
  final String subtitle;
  final double lat;
  final double lon;

  factory _CityResult.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};
    final cityName = (address['city'] as String?) ??
        (address['town'] as String?) ??
        (address['village'] as String?) ??
        (address['county'] as String?) ??
        (address['state'] as String?) ??
        (json['name'] as String?) ??
        (json['display_name'] as String).split(',').first.trim();

    final parts = <String>[];
    if (address['state'] != null) parts.add(address['state'] as String);
    if (address['country'] != null) parts.add(address['country'] as String);

    return _CityResult(
      displayName: json['display_name'] as String,
      cityName: cityName,
      subtitle: parts.join(', '),
      lat: double.parse(json['lat'] as String),
      lon: double.parse(json['lon'] as String),
    );
  }
}
Future<List<_CityResult>> _searchCities(String query) async {
  if (query.trim().length < 2) return [];
  try {
    final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '8',
        'featuretype': 'city',
      },
    );

    final response = await http.get(
      uri,
      headers: {'User-Agent': 'LokaGuide/1.0 (tour-guide-app)'},
    ).timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) return [];

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => _CityResult.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}
class CitySearchField extends StatefulWidget {
  const CitySearchField({
    super.key,
    required this.controller,
    this.validator,
    this.onCitySelected,
  });

  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onCitySelected;

  @override
  State<CitySearchField> createState() => _CitySearchFieldState();
}

class _CitySearchFieldState extends State<CitySearchField> {
  Timer? _debounce;
  List<_CityResult> _suggestions = [];
  bool _isSearching = false;
  bool _showSuggestions = false;
  LatLng? _selectedLatLng;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () => _doSearch(value));
  }

  Future<void> _doSearch(String query) async {
    if (query == _lastQuery) {
      setState(() => _isSearching = false);
      return;
    }
    _lastQuery = query;

    final results = await _searchCities(query);

    if (!mounted) return;
    setState(() {
      _suggestions = results;
      _isSearching = false;
      _showSuggestions = results.isNotEmpty;
    });
  }

  void _select(_CityResult city) {
    _debounce?.cancel();
    _lastQuery = city.cityName;
    widget.controller.text = city.cityName;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: city.cityName.length),
    );

    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _isSearching = false;
      _selectedLatLng = LatLng(city.lat, city.lon);
    });

    widget.onCitySelected?.call(city.cityName);
  }

  void _dismissSuggestions() {
    setState(() => _showSuggestions = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          onChanged: _onChanged,
          onTap: () {
            if (widget.controller.text.trim().length >= 2 &&
                _suggestions.isNotEmpty) {
              setState(() => _showSuggestions = true);
            }
          },
          onTapOutside: (_) => _dismissSuggestions(),
          decoration: InputDecoration(
            labelText: 'City',
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _selectedLatLng != null
                    ? Icon(Icons.check_circle_outline, color: cs.primary)
                    : null,
          ),
          validator: widget.validator,
          textInputAction: TextInputAction.next,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _showSuggestions && _suggestions.isNotEmpty
              ? _SuggestionDropdown(
                  key: const ValueKey('dropdown'),
                  suggestions: _suggestions,
                  onSelect: _select,
                  onDismiss: _dismissSuggestions,
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _selectedLatLng != null
              ? _MapPreview(
                  key: ValueKey(_selectedLatLng),
                  location: _selectedLatLng!,
                  cityName: widget.controller.text,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SuggestionDropdown extends StatelessWidget {
  const _SuggestionDropdown({
    super.key,
    required this.suggestions,
    required this.onSelect,
    required this.onDismiss,
  });

  final List<_CityResult> suggestions;
  final ValueChanged<_CityResult> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        shrinkWrap: true,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
        itemBuilder: (_, i) {
          final city = suggestions[i];
          return InkWell(
            onTap: () => onSelect(city),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.location_city_outlined,
                      size: 20, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          city.cityName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (city.subtitle.isNotEmpty)
                          Text(
                            city.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    cs.onSurface.withValues(alpha: 0.5)),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({super.key, required this.location, required this.cityName});

  final LatLng location;
  final String cityName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 180,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: location,
              initialZoom: 11,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.lokaguide.app',
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: location,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.redAccent,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.black.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Icon(Icons.location_on,
                      size: 14, color: cs.primaryContainer),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cityName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '© OpenStreetMap',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
