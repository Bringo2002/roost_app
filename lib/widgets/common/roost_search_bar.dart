import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_colors.dart';

/// The single search-bar visual/interaction pattern used everywhere in
/// the app search happens (home feed, dedicated Search page).
///
/// Previously these were two independently hand-rolled `TextField`s: the
/// home feed used a full pill (radius 24) with a nice focus-glow border
/// animation, the Search page used a rounded rectangle (radius 14) with
/// a static border and no focus feedback, and both used raw hex colors
/// instead of the shared design tokens. This consolidates both into one
/// widget -- rounded-rectangle shape (matching the radius used
/// everywhere else in the app, from buttons to cards), with the home
/// bar's focus-glow behavior carried over since it was the better of
/// the two.
class RoostSearchBar extends StatefulWidget {
  const RoostSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.onSubmitted,
    this.onClear,
    this.trailing,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String>? onSubmitted;

  /// Called after the controller is cleared via the trailing X button,
  /// in addition to whatever listener the caller already has on
  /// [controller] -- lets a caller skip its own debounce delay for an
  /// explicit clear tap, the way the Search page's original clear
  /// button did, rather than waiting out the normal typing debounce.
  final VoidCallback? onClear;

  /// Optional widget placed after the search field -- e.g. the Search
  /// page's filter button with its active-filter-count badge. Kept
  /// outside this widget's own decoration so it reads as a separate
  /// tappable control rather than part of the field itself.
  final Widget? trailing;

  @override
  State<RoostSearchBar> createState() => _RoostSearchBarState();
}

class _RoostSearchBarState extends State<RoostSearchBar> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() => setState(() => _focused = widget.focusNode.hasFocus);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focused ? AppColors.white.withValues(alpha: 0.5) : AppColors.border,
                width: _focused ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.search, color: AppColors.grey500, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: widget.onSubmitted,
                    style: const TextStyle(color: AppColors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: const TextStyle(color: AppColors.grey600, fontSize: 15),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox(width: 14);
                    return IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: const Icon(Icons.close, color: AppColors.grey500, size: 18),
                      onPressed: () {
                        widget.controller.clear();
                        widget.onClear?.call();
                      },
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        if (widget.trailing != null) ...[
          const SizedBox(width: 10),
          widget.trailing!,
        ],
      ],
    );
  }
}
