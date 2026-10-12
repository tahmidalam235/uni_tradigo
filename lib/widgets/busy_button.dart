import 'package:flutter/material.dart';

/// Variant controls the visual weight. `primary` is the default
/// filled CTA; `secondary` is a filled tonal button; `outline` is
/// the unfilled outlined button; `danger` is a destructive red.
enum ButtonVariant { primary, secondary, outline, danger, ghost }

/// BusyButton — a button that shows an inline spinner while busy,
/// so screens don't have to repeat the `if (busy) CircularProgressIndicator
/// else Text(label)` dance.
class BusyButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool busy;
  final String label;
  final IconData? icon;
  final ButtonVariant variant;
  final bool expand;
  final EdgeInsetsGeometry? padding;

  const BusyButton({
    super.key,
    required this.onPressed,
    required this.busy,
    required this.label,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.expand = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = busy || onPressed == null;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: _spinnerColor(context),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    final effectivePadding = padding ??
        const EdgeInsets.symmetric(vertical: 14, horizontal: 20);

    Widget btn;
    switch (variant) {
      case ButtonVariant.primary:
        btn = ElevatedButton(
          onPressed: disabled ? null : onPressed,
          child: child,
          style: ElevatedButton.styleFrom(padding: effectivePadding),
        );
        break;
      case ButtonVariant.secondary:
        btn = FilledButton.tonal(
          onPressed: disabled ? null : onPressed,
          child: child,
          style: FilledButton.styleFrom(padding: effectivePadding),
        );
        break;
      case ButtonVariant.outline:
        btn = OutlinedButton(
          onPressed: disabled ? null : onPressed,
          child: child,
          style: OutlinedButton.styleFrom(padding: effectivePadding),
        );
        break;
      case ButtonVariant.danger:
        btn = ElevatedButton(
          onPressed: disabled ? null : onPressed,
          child: child,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            padding: effectivePadding,
          ),
        );
        break;
      case ButtonVariant.ghost:
        btn = TextButton(
          onPressed: disabled ? null : onPressed,
          child: child,
          style: TextButton.styleFrom(padding: effectivePadding),
        );
        break;
    }
    if (expand) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }

  Color _spinnerColor(BuildContext context) {
    switch (variant) {
      case ButtonVariant.primary:
      case ButtonVariant.danger:
        return Theme.of(context).colorScheme.onPrimary;
      case ButtonVariant.secondary:
        return Theme.of(context).colorScheme.onSecondaryContainer;
      case ButtonVariant.outline:
        return Theme.of(context).colorScheme.primary;
      case ButtonVariant.ghost:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
