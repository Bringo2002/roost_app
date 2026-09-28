import 'package:flutter/material.dart';
import 'package:roost_app/theme/app_colors.dart';
import 'package:roost_app/theme/app_theme.dart';

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
///
/// Hardening notes:
///  * The focus listener follows the [FocusNode] if the parent swaps it.
///  * The border width is constant (only its colour animates) so focusing
///    the field never shifts the content by a pixel.
///  * Height is a *minimum*, so the bar grows with large system font sizes
///    instead of clipping.
///  * Autocorrect/suggestions are off: this is a query box, not prose, and
///    the keyboard's composing underline reads as a UI glitch.
///  * The clear button has a tooltip/semantic label and a 48dp touch target.
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
  static const double _minHeight = 48;
  static const double _clearTargetSize = 48;
  static const double _fontSize = 15;
  static const Duration _focusAnimation = Duration(milliseconds: 200);

  late bool _focused = widget.focusNode.hasFocus;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant RoostSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
      _focused = widget.focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    final hasFocus = widget.focusNode.hasFocus;
    if (hasFocus != _focused) setState(() => _focused = hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: _focusAnimation,
            constraints: const BoxConstraints(minHeight: _minHeight),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadii.input),
              // Constant width: only the colour animates, so focusing
              // never changes layout.
              border: Border.all(
                color: _focused ? AppColors.white.withValues(alpha: 0.5) : AppColors.border,
                width: 1,
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
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: widget.onSubmitted,
                    onTapOutside: (_) => widget.focusNode.unfocus(),
                    style: const TextStyle(color: AppColors.white, fontSize: _fontSize),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      // grey400 on surfaceRaised is ~6.5:1 (WCAG AA needs 4.5:1);
                      // the previous grey600 was ~2.8:1.
                      hintStyle: const TextStyle(color: AppColors.grey400, fontSize: _fontSize),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox(width: 14);
                    // Taps on the clear button count as "inside" the text
                    // field, so onTapOutside doesn't drop focus first.
                    return TextFieldTapRegion(
                      child: IconButton(
                        tooltip: 'Clear search',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: _clearTargetSize,
                          minHeight: _clearTargetSize,
                        ),
                        icon: const Icon(Icons.close, color: AppColors.grey500, size: 18),
                        onPressed: () {
                          widget.controller.clear();
                          widget.onClear?.call();
                        },
                      ),
                    );
                  },
                ),
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
