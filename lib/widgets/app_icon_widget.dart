import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/usage_tracking_service.dart';

class AppIconWidget extends StatefulWidget {
  final String packageName;
  final String appName;
  final Uint8List? initialIcon;
  final double size;
  final double? borderRadius;

  const AppIconWidget({
    super.key,
    required this.packageName,
    required this.appName,
    this.initialIcon,
    this.size = 40,
    this.borderRadius,
  });

  @override
  State<AppIconWidget> createState() => _AppIconWidgetState();
}

class _AppIconWidgetState extends State<AppIconWidget> {
  Uint8List? _iconBytes;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _resolveIcon();
  }

  @override
  void didUpdateWidget(covariant AppIconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName || oldWidget.initialIcon != widget.initialIcon) {
      _resolveIcon();
    }
  }

  void _resolveIcon() {
    if (widget.initialIcon != null && widget.initialIcon!.isNotEmpty) {
      _iconBytes = widget.initialIcon;
      return;
    }

    final cached = UsageTrackingService.getCachedIcon(widget.packageName);
    if (cached != null && cached.isNotEmpty) {
      _iconBytes = cached;
      return;
    }

    _fetchIconAsync();
  }

  Future<void> _fetchIconAsync() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final icon = await UsageTrackingService.fetchAppIcon(widget.packageName);
      if (mounted && icon != null && icon.isNotEmpty) {
        setState(() {
          _iconBytes = icon;
        });
      }
    } catch (_) {
    } finally {
      _isFetching = false;
    }
  }

  Color _getFallbackColor(String name) {
    if (name.isEmpty) return const Color(0xFF6C5CE7);
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    const colors = [
      Color(0xFF6C5CE7),
      Color(0xFF0984E3),
      Color(0xFF00CEC9),
      Color(0xFF00B894),
      Color(0xFFE17055),
      Color(0xFFFD79A8),
      Color(0xFFFFA502),
      Color(0xFF6C5CE7),
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? (widget.size * 0.26);

    if (_iconBytes != null && _iconBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          _iconBytes!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallback(radius),
        ),
      );
    }

    return _buildFallback(radius);
  }

  Widget _buildFallback(double radius) {
    final color = _getFallbackColor(widget.appName);
    final initial = widget.appName.trim().isNotEmpty
        ? widget.appName.trim()[0].toUpperCase()
        : '?';

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withOpacity(0.4), width: 1.2),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: widget.size * 0.44,
          ),
        ),
      ),
    );
  }
}
