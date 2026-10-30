import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Whether the app runs on a phone, natively or in a phone's browser/PWA.
/// Flutter web derives [defaultTargetPlatform] from the user agent, so an
/// iPhone or Android phone is recognised even in a browser.
bool isPhone(BuildContext context) {
  final handheld = defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  return handheld && MediaQuery.sizeOf(context).shortestSide < 600;
}

/// The wide desktop layout: only on a wide window that isn't a phone, so a
/// phone (even in landscape) always gets the same layout as the native app.
bool useDesktopLayout(BuildContext context) =>
    !isPhone(context) && MediaQuery.sizeOf(context).width >= 900;

/// Bottom-sheet popups instead of centred cards.
bool useSheet(BuildContext context) =>
    isPhone(context) || MediaQuery.sizeOf(context).width < 700;
