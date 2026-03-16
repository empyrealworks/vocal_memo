// lib/widgets/connectivity_banner.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_theme.dart';

/// Wraps [child] and overlays a slim connectivity banner at the bottom of the
/// screen whenever the device is offline, or briefly when it comes back online.
///
/// Usage — wrap your [Scaffold] body or any subtree:
/// ```dart
/// ConnectivityBanner(child: Scaffold(...))
/// ```
/// Or inject it at the [MaterialApp.builder] level so it covers every route.
class ConnectivityIcon extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectivityIcon({super.key, required this.child});

  @override
  ConsumerState<ConnectivityIcon> createState() => _ConnectivityIconState();
}

class _ConnectivityIconState extends ConsumerState<ConnectivityIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _slideAnim;

  // Tracks whether we should show the icon and its current message/colour.
  bool _iconVisible = false;
  bool _isExpanded = false;
  bool _isOnline = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _showBanner(bool online) {
    _hideTimer?.cancel();
    setState(() {
      _iconVisible = true;
      _isOnline = online;
      if (_isOnline){
        _isExpanded = true;
      } else {
        _isExpanded = false;
      }
    });
    _animController.forward(from: 0);

    // Auto-dismiss the "back online" banner after 3 s.
    // The offline banner stays visible until connectivity returns.
    if (online) {
      _hideTimer = Timer(const Duration(seconds: 5), _hideBanner);
    }
  }

  void _hideBanner() {
    if (!mounted) return;
    _animController.reverse().then((_) {
      if (mounted) setState(() => _iconVisible = false);
    });
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    // React to every connectivity change.
    ref.listen<AsyncValue<bool>>(connectivityStreamProvider, (prev, next) {
      next.whenData((online) {
        if (!online) {
          _showBanner(false);
        } else if (prev?.value == false) {
          // Only show "back online" when we were previously offline.
          _showBanner(true);
        }
      });
    });

    return Stack(
      children: [
        widget.child,
        if (_iconVisible)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(_slideAnim),
              child: _BannerStrip(isOnline: _isOnline, isExpanded: _isExpanded, toggleExpanded: _toggleExpanded,),
            ),
          ),
      ],
    );
  }
}

// ─── Banner strip ─────────────────────────────────────────────────────────────

class _BannerStrip extends StatelessWidget {
  final bool isOnline;
  final bool isExpanded;
  final VoidCallback toggleExpanded;

  const _BannerStrip({
    required this.isOnline,
    required this.isExpanded,
    required this.toggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Swapped Container for Padding so empty space doesn't block touches
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
              onPressed: toggleExpanded,
              icon: Icon(
                isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: isOnline ? Colors.green : Colors.red,
                size: 24,
              )
          ),
          if (isExpanded) ...[
            const SizedBox(width: 8),
            Text(
              isOnline ? 'Back online' : 'Offline',
              style: TextStyle(
                color: isOnline ? Colors.green : Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ]
        ],
      ),
    );
  }
}
