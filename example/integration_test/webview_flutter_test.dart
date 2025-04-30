// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

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

        Completer<bool> received = Completer<bool>();

        late final JavaScriptChannelParams channel;

        channel = JavaScriptChannelParams(
            name: 'test',
            onMessageReceived: (JavaScriptMessage message) {
              if (!received.isCompleted) {
                received.complete(message is WebWebViewMessage);
              }
            });

        expect(channel, isA<JavaScriptChannelParams>());

        await controller.runJavaScript('''(function () {
          addEventListener('message', (e) => {
            const port = e.ports[0];

            port.postMessage({ 'ping': 'pong' });
            port.onmessage = () => port.postMessage({ 'ping': 'pong' });
          });
        })();''');

        await tester.runAsync(() async {
          received = Completer();
          await controller.addJavaScriptChannel(channel);
          expect(await received.future, true,
              reason: 'addJavaScriptChannel should run successfully.');
        });

        await tester.runAsync(() async {
          received = Completer();
          final timer = Timer(Duration(seconds: 3), () {
            if (!received.isCompleted) {
              received.complete(false);
            }
          });

          await controller.removeJavaScriptChannel(channel.name);

          expect(timer.isActive && !received.isCompleted, true,
              reason: 'removeJavaScriptChannel should run successfully.');

          timer.cancel();
        });
      } finally {
        await tester.pumpWidget(Container());
        await tester.pumpAndSettle(Duration(seconds: 1));
      }
    });
  });
}
