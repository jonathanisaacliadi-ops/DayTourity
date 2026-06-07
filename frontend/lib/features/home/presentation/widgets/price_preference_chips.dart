import 'package:flutter/material.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../../core/theme/app_theme.dart';

class PricePreferenceChips extends StatelessWidget {
  const PricePreferenceChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final PricePreference selected;
  final ValueChanged<PricePreference> onSelected;

  static const _options = [
    (PricePreference.budget,   'Budget',   Icons.savings_rounded,               AppColors.budgetColor),
    (PricePreference.standard, 'Standard', Icons.account_balance_wallet_rounded, AppColors.standardColor),
    (PricePreference.premium,  'Premium',  Icons.diamond_rounded,               AppColors.premiumColor),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.darkOverlay, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _options.map((opt) {
          final (pref, label, icon, color) = opt;
          final isSelected = selected == pref;

          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _PrefChip(
              label: label,
              icon: icon,
              accentColor: color,
              isSelected: isSelected,
              onTap: () => onSelected(pref),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PrefChip extends StatefulWidget {
  const _PrefChip({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_PrefChip> createState() => _PrefChipState();
}

class _PrefChipState extends State<_PrefChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.isSelected ? 1 : 0,
    );
    _scale = Tween<double>(begin: 0.95, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_PrefChip old) {
    super.didUpdateWidget(old);
    if (widget.isSelected != old.isSelected) {
      widget.isSelected ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? widget.accentColor.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
              color: isSelected
                  ? widget.accentColor.withOpacity(0.5)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 15,
                color: isSelected ? widget.accentColor : AppColors.onDarkSubtle,
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? widget.accentColor : AppColors.onDarkMuted,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}