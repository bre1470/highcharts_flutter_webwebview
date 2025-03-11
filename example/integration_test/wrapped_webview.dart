// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:highcharts_flutter_webwebview/webview_flutter_web.dart';

/// Returns the webview widget for a given [controller], wrapped so it works
/// in our integration tests.
Widget wrappedWebView(WebWebViewController controller) {
  return _wrapped(
    Builder(
      builder: (BuildContext ctx) => PlatformWebViewWidget(
        PlatformWebViewWidgetCreationParams(controller: controller),
      ).build(ctx),
    ),
  );
}

// Wraps a [child] widget in the scaffolding this test needs.
Widget _wrapped(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.red,
            ),
          ),
          width: 320,
          height: 200,
          child: child,
        ),
      ),
    ),
  );
}
