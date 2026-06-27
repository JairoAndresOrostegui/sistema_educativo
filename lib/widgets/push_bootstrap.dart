import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider_v2.dart';
import '../utils/push_notifications.dart';
import '../utils/firebase_utils.dart';

class PushBootstrap extends StatefulWidget {
  final Widget child;
  final String? webVapidKey;
  const PushBootstrap({super.key, required this.child, this.webVapidKey});

  @override
  State<PushBootstrap> createState() => _PushBootstrapState();
}

class _PushBootstrapState extends State<PushBootstrap> {
  String? _initedForUserId;

  Future<void> _ensureInitForUser(String userId) async {
    if (_initedForUserId == userId) return;
    _initedForUserId = userId;

    await initializePush(
      webVapidKey: widget.webVapidKey,
      onNewToken: (t) async {
        await saveUserNotificationToken(userId: userId, token: t);
        if (!mounted) return;
        context.read<UserProviderV2>().updateNotificationToken(t);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProviderV2>().user;
    if (user == null) {
      _initedForUserId = null;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureInitForUser(user.id);
      });
    }
    return widget.child;
  }
}
