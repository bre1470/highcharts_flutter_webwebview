// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'content_type.dart';
import 'http_request_factory.dart';

@immutable
class WebWebViewMessage extends JavaScriptMessage {
  WebWebViewMessage({required String message, this.extraData = null})
      : super(message: message);

  final dynamic extraData;
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
      : super.implementation(params is WebWebViewControllerCreationParams
            ? params
            : WebWebViewControllerCreationParams
                .fromPlatformWebViewControllerCreationParams(params));

  String? _htmlString;

  web.HTMLScriptElement? _iScript;

  String? _javaScript;

  final Map<String, web.MessageChannel> _messageChannels = {};

  bool get mounted => _webWebViewParams.iFrame.parentElement != null;

  WebWebViewControllerCreationParams get _webWebViewParams =>
      params as WebWebViewControllerCreationParams;

  @override
  Future<void> addJavaScriptChannel(
      JavaScriptChannelParams javaScriptChannelParams) async {
    final String channelName = javaScriptChannelParams.name;

    if (_messageChannels.containsKey(channelName)) {
      throw new ArgumentError(
        'A JavaScriptChannel with name `$channelName` already exists.',
      );
    }

    final channel = new web.MessageChannel();

    channel.port1.onmessage = (web.MessageEvent e) {
      javaScriptChannelParams.onMessageReceived(
          new WebWebViewMessage(message: channelName, extraData: e.data));
    }.toJS;
    _connectMessageChannel(channel);
    _messageChannels[channelName] = channel;
  }

  void _connectMessageChannel(web.MessageChannel channel) {
    if (_webWebViewParams.iFrame.contentWindow != null) {
      _webWebViewParams.iFrame.contentWindow
          ?.postMessage('init'.toJS, '*'.toJS, [channel.port2].toJS);
    }
  }

  void dispose() {
    _messageChannels.entries.forEach((entry) {
      entry.value.port1.close();
      entry.value.port2.close();
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
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {
    if (_messageChannels.containsKey(javaScriptChannelName)) {
      final channel = _messageChannels.remove(javaScriptChannelName)!;
      channel.port1.close();
      channel.port2.close();
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
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    if (!params.uri.hasScheme) {
      throw ArgumentError(
          'LoadRequestParams#uri is required to have a scheme.');
    }

    if (params.headers.isEmpty &&
        (params.body == null || params.body!.isEmpty) &&
        params.method == LoadRequestMethod.get) {
      _webWebViewParams.iFrame.src = params.uri.toString();
    } else {
      await _updateIFrameFromXhr(params);
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

          if (javaScript != null) {
            /// Restore JavaScript
            _controller.runJavaScript(javaScript);
          }

          _controller._messageChannels.values
              .forEach(_controller._connectMessageChannel);
        }).toJS;

        iFrame?.addEventListener('load', listener);
        iFrame?.src = 'about:blank';
      },
      viewType: _controller._webWebViewParams.iFrame.id,
    );
  }
}
