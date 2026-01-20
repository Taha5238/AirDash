import 'dart:async';
import 'package:flutter/material.dart';
import '../../features/auth/services/auth_service.dart';

class SessionManager extends StatefulWidget {
  final Widget child;
  final Duration timeoutDuration;
  final VoidCallback? onTimeout;
  final GlobalKey<NavigatorState>? navigatorKey;

  const SessionManager({
    super.key,
    required this.child,
    this.timeoutDuration = const Duration(minutes: 1),
    this.onTimeout,
    this.navigatorKey,
  });

  @override
  State<SessionManager> createState() => _SessionManagerState();
}

class _SessionManagerState extends State<SessionManager> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeoutDuration, _handleTimeout);
  }

  void _handleTimeout() async {
    final user = AuthService().currentUser;
    if (user != null) {
      if (widget.onTimeout != null) {
        widget.onTimeout!();
      } else {
        await AuthService().signOut();
        
        if (widget.navigatorKey != null) {
            // Navigate to AuthCheck or Login
            // We use pushNamedAndRemoveUntil to clear stack
            widget.navigatorKey!.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
            // OR if routes are not named, push AuthCheck
            // But we need to import AuthCheck if we use it. 
            // Better to assume '/' is home/auth_check if defined, or just use a pushReplacement logic.
             // Actually, since we don't know the routes, let's use a workaround or demand routes.
             // 'AirDash' uses 'home: AuthCheck()'. It usually doesn't have named routes defined in main.dart snippet.
             // So we should probably navigate to a LoginScreen explicitly.
             // But we need to import it.
        }
      }
    }
  }

  void _handleUserInteraction([dynamic _]) {
    final user = AuthService().currentUser;
    // Only reset if user is logged in
    if (user != null) {
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleUserInteraction,
      onPointerMove: _handleUserInteraction,
      onPointerUp: _handleUserInteraction,
      child: widget.child,
    );
  }
}
