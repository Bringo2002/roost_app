import 'package:flutter/material.dart';

/// Global navigator key so services outside the widget tree (e.g. a
/// top-level FCM foreground-message listener, which has no BuildContext
/// of its own) can still show UI via navigatorKey.currentContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
