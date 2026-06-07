import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/itinerary_proposal.dart';
import '../../../tours/domain/entities/tour_activity.dart';


class ItineraryBuilderSheet extends StatefulWidget {
  const ItineraryBuilderSheet({
    super.key,
    this.tourTitle,
    this.initialActivities,
  });

  final String? tourTitle;

  final List<TourActivity>? initialActivities;

  @override
  State<ItineraryBuilderSheet> createState() => _ItineraryBuilderSheetState();
}

class _ItineraryBuilderSheetState extends State<ItineraryBuilderSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _titleCtrl =
      TextEditingController(text: widget.tourTitle ?? '');
  final _noteCtrl = TextEditingController();

  DateTime? _selectedDate;
  final List<_ActivityDraft> _activities = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialActivities != null) {
      for (final a in widget.initialActivities!) {
        _activities.add(_ActivityDraft(
          name: a.name,
          duration: null,
          price: a.pricingType == PricingType.fixed
              ? a.fixedPrice
              : a.minPrice,
        ));
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _total =>
      _activities.fold(0, (s, a) => s + (a.price ?? 0));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _addActivity() async {
    final draft = await showDialog<_ActivityDraft>(
      context: context,
      builder: (_) => const _ActivityDialog(),
    );
    if (draft != null) setState(() => _activities.add(draft));
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final proposal = ItineraryProposal(
      title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      date: _selectedDate?.toIso8601String().split('T').first,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      activities: _activities
          .map((a) => ItineraryActivity(
                name: a.name,
                duration: a.duration,
                price: a.price,
              ))
          .toList(),
      totalPrice: _total > 0 ? _total : null,
    );

    Navigator.pop(context, proposal);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.route_outlined, color: cs.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Build Custom Itinerary',
                            style: theme.textTheme.titleLarge),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Itinerary Title',
                        prefixIcon: Icon(Icons.title_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Title is required'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Tour Date',
                          prefixIcon: Icon(
                            Icons.calendar_today_outlined,
                            color: _selectedDate != null
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.4),
                          ),
                          suffixIcon: _selectedDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () =>
                                      setState(() => _selectedDate = null),
                                )
                              : null,
                        ),
                        child: Text(
                          _selectedDate != null
                              ? DateFormat('EEEE, d MMMM yyyy')
                                  .format(_selectedDate!)
                              : 'Select a date (optional)',
                          style: TextStyle(
                            color: _selectedDate != null
                                ? cs.onSurface
                                : cs.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _noteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Special Notes for the User (optional)',
                        prefixIcon: Icon(Icons.notes_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: Text('Activities',
                              style: theme.textTheme.titleMedium),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                          onPressed: _addActivity,
                        ),
                      ],
                    ),
                    if (_activities.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No activities yet — tap Add to include items.',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.4),
                              fontSize: 13),
                        ),
                      ),

                    ..._activities.asMap().entries.map((e) {
                      final i = e.key;
                      final a = e.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            child: Text('${i + 1}',
                                style:
                                    TextStyle(color: cs.primary)),
                          ),
                          title: Text(a.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text([
                            if (a.duration != null) a.duration!,
                            if (a.price != null)
                              'Rp ${_fmt(a.price!)}',
                          ].join(' · ')),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: cs.error),
                            onPressed: () =>
                                setState(() => _activities.removeAt(i)),
                          ),
                        ),
                      );
                    }),

                    if (_activities.any((a) => a.price != null)) ...[
                      const Divider(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Total: Rp ${_fmt(_total)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    FilledButton.icon(
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Send Proposal to User'),
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) => NumberFormat('#,###', 'id_ID').format(v);
}


class _ActivityDraft {
  _ActivityDraft({required this.name, this.duration, this.price});
  final String name;
  final String? duration;
  final double? price;
}


class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog();
  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _ActivityDraft(
        name: _nameCtrl.text.trim(),
        duration: _durationCtrl.text.trim().isEmpty
            ? null
            : _durationCtrl.text.trim(),
        price: double.tryParse(_priceCtrl.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Activity'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Activity Name'),
              autofocus: true,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _durationCtrl,
              decoration: const InputDecoration(
                  labelText: 'Duration (e.g. 2 hours)',
                  prefixIcon: Icon(Icons.timer_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(
                  labelText: 'Price (Rp)',
                  prefixText: 'Rp ',
                  prefixIcon: Icon(Icons.payments_outlined)),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
