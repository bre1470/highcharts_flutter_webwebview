// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop' as js;
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web/web.dart' as web;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:highcharts_flutter_webwebview/webview_flutter_web.dart';

import 'wrapped_webview.dart';

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('WebWebViewController', () {
    WebWebViewController controller =
        WebWebViewController(const PlatformWebViewControllerCreationParams());
    Widget webView = Container();

    setUp(() async {
      controller =
          WebWebViewController(const PlatformWebViewControllerCreationParams());
      webView = WrappedWebView(controller);
      await controller.loadHtmlString('<html></html>');
    });

    tearDown(() async {
      if (controller.mounted) {
        controller.dispose();
      }
    });

    testWidgets('loadRequest', (WidgetTester tester) async {
      try {
        const fakeUrl = 'about:blank';

        await controller.loadRequest(
          LoadRequestParams(uri: Uri.parse(fakeUrl)),
        );

        await tester.pumpWidget(webView);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Assert an iFrame has been rendered to the DOM with the correct src attribute.
        final web.HTMLIFrameElement? element =
            web.document.querySelector('iframe') as web.HTMLIFrameElement?;
        expect(element, isNotNull);
        expect(element!.src, fakeUrl);
      } finally {
        await tester.pumpWidget(Container());
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }
    });

    testWidgets('loadHtmlString', (WidgetTester tester) async {
      try {
        await tester.pumpWidget(webView);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Assert an iFrame has been rendered to the DOM with the correct src attribute.
        final web.HTMLIFrameElement? element =
            web.document.querySelector('iframe') as web.HTMLIFrameElement?;
        expect(element, isNotNull);
        expect(element!.src, 'about:blank');
      } finally {
        await tester.pumpWidget(Container());
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }
    });

    testWidgets('addJavaScriptChannel', (WidgetTester tester) async {
      try {
        await tester.pumpWidget(webView);
        await tester.pumpAndSettle(Duration(seconds: 1));

        Completer<bool> completer = Completer<bool>();

        late final JavaScriptChannelParams channel;

        channel = JavaScriptChannelParams(
            name: 'webview_flutter_test',
            onMessageReceived: (JavaScriptMessage message) {
              if (!completer.isCompleted) {
                // Trigger completer
                completer.complete(message.message == 'ping');
              }
            });

        expect(channel, isA<JavaScriptChannelParams>());

        // Test addJavaScriptChannel
        await tester.runAsync(() async {
          completer = Completer();

          await controller.runJavaScript('''(function () {
            addEventListener('message', (e) => {
              e.ports[0].postMessage(
                typeof window.webview_flutter_test === 'object' ?
                  'ping' :
                  'pong'
              );
            });
          })();''');

          Future.delayed(Duration(seconds: 3)).then((_) {
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          });

          await controller.addJavaScriptChannel(channel);

          expect(await completer.future, true,
              reason: 'addJavaScriptChannel should trigger before timeout.');

          expect(
              (controller.params as WebWebViewControllerCreationParams)
                  .iFrame
                  .contentWindow
                  ?.hasProperty('webview_flutter_test'.toJS),
              true,
              reason: 'addJavaScriptChannel should add channel object.');
        });

        // Test removeJavaScriptChannel
        await tester.runAsync(() async {
          completer = Completer();

          Future.delayed(Duration(seconds: 3)).then((_) {
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          });

          await controller
              .removeJavaScriptChannel(channel.name)
              .then((_) => completer.complete(true));

          expect(await completer.future, true,
              reason: 'removeJavaScriptChannel should run successfully.');

          expect(
              (controller.params as WebWebViewControllerCreationParams)
                  .iFrame
                  .contentWindow
                  ?.hasProperty('webview_flutter_test'.toJS),
              false,
              reason: 'removeJavaScriptChannel should remove channel object.');
        });
      } finally {
        await tester.pumpWidget(Container());
        await tester.pumpAndSettle(Duration(seconds: 1));
      }
    });
  });
}
