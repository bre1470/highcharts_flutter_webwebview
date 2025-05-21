// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'content_type.dart';
import 'http_request_factory.dart';

@immutable
class WebWebViewMessageChannel {
  WebWebViewMessageChannel({
    required this.name,
    required this.webChannel,
  });

  final String name;
  final web.MessageChannel webChannel;
}

/// An implementation of [PlatformWebViewControllerCreationParams] using Flutter
/// for Web API.
@immutable
class WebWebViewControllerCreationParams
    extends PlatformWebViewControllerCreationParams {
  /// Creates a new [AndroidWebViewControllerCreationParams] instance.
  WebWebViewControllerCreationParams({
    @visibleForTesting this.httpRequestFactory = const HttpRequestFactory(),
  }) : super();

  /// Creates a [WebWebViewControllerCreationParams] instance based on
  /// [PlatformWebViewControllerCreationParams].
  WebWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams(
    // Recommended placeholder to prevent being broken by platform interface.
    // ignore: avoid_unused_constructor_parameters
    PlatformWebViewControllerCreationParams params, {
    @visibleForTesting
    HttpRequestFactory httpRequestFactory = const HttpRequestFactory(),
  }) : this(httpRequestFactory: httpRequestFactory);

  static int _nextIFrameId = 0;

  /// Handles creating and sending URL requests.
  final HttpRequestFactory httpRequestFactory;

  /// The underlying element used as the WebView.
  final web.HTMLIFrameElement iFrame = web.HTMLIFrameElement()
    ..id = 'webView${_nextIFrameId++}'
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.border = 'none';

  void dispose() {
    if (iFrame.parentElement != null) {
      iFrame.remove();
    }
  }
}

/// An implementation of [PlatformWebViewController] using Flutter for Web API.
class WebWebViewController extends PlatformWebViewController {
  /// Constructs a [WebWebViewController].
  WebWebViewController(PlatformWebViewControllerCreationParams params)
      : super.implementation(
          params is WebWebViewControllerCreationParams
              ? params
              : WebWebViewControllerCreationParams
                  .fromPlatformWebViewControllerCreationParams(
                  params,
                ),
        );

  String? _htmlString;

  web.HTMLScriptElement? _iScript;

  String? _javaScript;

  final Map<String, WebWebViewMessageChannel> _messageChannels = {};

  bool get mounted => _webWebViewParams.iFrame.parentElement != null;

  WebWebViewControllerCreationParams get _webWebViewParams =>
      params as WebWebViewControllerCreationParams;

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    final String channelName = javaScriptChannelParams.name;

    if (_messageChannels.containsKey(channelName)) {
      throw new ArgumentError(
        'A JavaScriptChannel with name `$channelName` already exists.',
      );
    }

    final channel = WebWebViewMessageChannel(
      name: channelName,
      webChannel: web.MessageChannel(),
    );
    final completer = Completer<bool>();

    channel.webChannel.port1.onmessage = (web.MessageEvent e) {
      if (e.data.toString() == 'flutter_webwebview._connected') {
        completer.complete(true);
      }
    }.toJS;

    _connectMessageChannel(channel);

    await completer.future;

    channel.webChannel.port1.onmessage = (web.MessageEvent e) {
      javaScriptChannelParams.onMessageReceived(
        new JavaScriptMessage(message: e.data.toString()),
      );
    }.toJS;

    _messageChannels[channelName] = channel;
  }

  void _connectMessageChannel(WebWebViewMessageChannel channel) {
    if (_webWebViewParams.iFrame.contentWindow != null) {
      _webWebViewParams.iFrame.contentWindow?.postMessage(
        ['flutter_webwebview._connect'.toJS, channel.name.toJS].toJS,
        '*'.toJS,
        [channel.webChannel.port2].toJS,
      );
    }
  }

  Future<void> _disconnectMessageChannel(
      WebWebViewMessageChannel channel) async {
    final completer = Completer<bool>();

    channel.webChannel.port1.postMessage(
        ['flutter_webwebview._disconnect'.toJS, channel.name.toJS].toJS);

    channel.webChannel.port1.onmessage = (web.MessageEvent e) {
      if (e.data.toString() == 'flutter_webwebview._disconnected') {
        completer.complete(true);
      }
    }.toJS;

    await completer.future;

    channel.webChannel.port1.close();
  }

  void dispose() {
    _messageChannels.values.forEach((channel) {
      channel.webChannel.port1.close();
      channel.webChannel.port2.close();
    });
    if (_iScript?.parentElement != null) {
      _iScript!.remove();
    }
    _webWebViewParams.dispose();
  }

  @override
  Future<String> getTitle() async {
    final iFrame = _webWebViewParams.iFrame;
    final iDocument = iFrame.contentDocument;

    return iDocument?.title ?? '';
  }

  void _injectJavaScript(String javaScript) {
    final iDocument = _webWebViewParams.iFrame.contentDocument;
    final iBody = iDocument!.body!;

    /// Reset iScript.
    if (_iScript != null) {
      iBody.removeChild(_iScript!);
    }
    _iScript = iDocument.createElement('script') as web.HTMLScriptElement;
    iBody.appendChild(_iScript!);

    /// Inject JavaScript. Data URL to work around strict CSP.
    _iScript!.src = Uri.dataFromString(
      javaScript,
      mimeType: 'text/javascript',
      encoding: utf8,
    ).toString();
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    final iFrame = _webWebViewParams.iFrame;
    final iDocument = iFrame.contentDocument;

    if (iDocument == null) {
      // WebWebViewWidget will call me later.
      _htmlString = html;
    } else {
      // Reset iFrame and inject HTML.
      iFrame.src = 'about:blank';
      iDocument.write(html.toJS);
    }
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    if (!params.uri.hasScheme) {
      throw ArgumentError(
        'LoadRequestParams#uri is required to have a scheme.',
      );
    }

    if (params.headers.isEmpty &&
        (params.body == null || params.body!.isEmpty) &&
        params.method == LoadRequestMethod.get) {
      _webWebViewParams.iFrame.src = params.uri.toString();
    } else {
      await _updateIFrameFromXhr(params);
    }
  }

  @override
  Future<void> removeJavaScriptChannel(String name) async {
    if (_messageChannels.containsKey(name)) {
      final channel = _messageChannels.remove(name)!;
      await _disconnectMessageChannel(channel);
    }
  }

  @override
  Future<void> runJavaScript(String javaScript) async {
    final iDocument = _webWebViewParams.iFrame.contentDocument;
    final iBody = iDocument?.body;

    if (iDocument == null || iBody == null) {
      // WebWebViewWidget will call me later.
      _javaScript = javaScript;
    } else {
      _injectJavaScript(javaScript);
    }
  }

  /// Performs an AJAX request defined by [params].
  Future<void> _updateIFrameFromXhr(LoadRequestParams params) async {
    final web.Response response =
        await _webWebViewParams.httpRequestFactory.request(
      params.uri.toString(),
      method: params.method.serialize(),
      requestHeaders: params.headers,
      sendData: params.body,
    ) as web.Response;

    final String header = response.headers.get('content-type') ?? 'text/html';
    final ContentType contentType = ContentType.parse(header);
    final Encoding encoding = Encoding.getByName(contentType.charset) ?? utf8;

    _webWebViewParams.iFrame.src = Uri.dataFromString(
      (await response.text().toDart).toDart,
      mimeType: contentType.mimeType,
      encoding: encoding,
    ).toString();
  }
}

/// An implementation of [PlatformWebViewWidget] using Flutter the for Web API.
class WebWebViewWidget extends PlatformWebViewWidget {
  /// Constructs a [WebWebViewWidget].
  WebWebViewWidget(PlatformWebViewWidgetCreationParams params)
      : super.implementation(params) {
    ui_web.platformViewRegistry.registerViewFactory(
      _controller._webWebViewParams.iFrame.id,
      (int viewId) => _controller._webWebViewParams.iFrame,
    );
  }

  WebWebViewController get _controller =>
      params.controller as WebWebViewController;

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: params.key,
      onPlatformViewCreated: (id) {
        web.HTMLIFrameElement? iFrame = _controller._webWebViewParams.iFrame;
        web.EventListener? listener;

        listener = (() {
          if (iFrame?.contentDocument?.readyState != null &&
              iFrame?.contentDocument?.readyState != 'complete') {
            return;
          }

          iFrame?.removeEventListener('load', listener);
          iFrame = null;

          final htmlString = _controller._htmlString;
          final javaScript = _controller._javaScript;

          _controller._htmlString = null;
          _controller._javaScript = null;

          if (htmlString != null) {
            /// Restore HTML
            _controller.loadHtmlString(htmlString);
          }

          _controller._injectJavaScript('''try {
            addEventListener('message', function (e) {
              if (
                e.data instanceof Array &&
                e.data[0] === 'flutter_webwebview._connect'
              ) {
                const name = e.data[1];
                const port = e.ports[0];

                window[name] = {
                  postMessage: (message) => {
                    port.postMessage(message);
                  },
                };

                port.onmessage = (e) => {
                  if (
                    e.data instanceof Array &&
                    e.data[0] === 'flutter_webwebview._disconnect'
                  ) {
                    try {
                      delete window[name];
                      port.postMessage('flutter_webwebview._disconnected');
                    } finally {
                      port.close();
                    }
                  }
                };

                port.postMessage('flutter_webwebview._connected');
              }
            });
          } catch {}''');

          if (javaScript != null) {
            /// Restore JavaScript
            _controller.runJavaScript(javaScript);
          }

          _controller._messageChannels.values.forEach(
            _controller._connectMessageChannel,
          );
        }).toJS;

        iFrame?.addEventListener('load', listener);
        iFrame?.src = 'about:blank';
      },
      viewType: _controller._webWebViewParams.iFrame.id,
    );
  }
}
