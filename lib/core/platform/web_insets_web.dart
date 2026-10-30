import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

/// Reads the browser's safe-area insets (notch, home indicator) so the web
/// app can lay out exactly like the native one on iPhone and Android.
EdgeInsets webSafeInsets() {
  final body = web.document.body;
  if (body == null) return EdgeInsets.zero;
  final probe = web.document.createElement('div') as web.HTMLElement
    ..style.cssText = 'position:fixed;top:0;left:0;visibility:hidden;'
        'pointer-events:none;padding:env(safe-area-inset-top) '
        'env(safe-area-inset-right) env(safe-area-inset-bottom) '
        'env(safe-area-inset-left)';
  body.append(probe);
  final cs = web.window.getComputedStyle(probe);
  double px(String v) => double.tryParse(v.replaceAll('px', '')) ?? 0;
  final insets = EdgeInsets.fromLTRB(
    px(cs.paddingLeft),
    px(cs.paddingTop),
    px(cs.paddingRight),
    px(cs.paddingBottom),
  );
  probe.remove();
  return insets;
}
