// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:highcharts_flutter_webwebview/webview_flutter_web.dart';

class WrappedWebView extends StatefulWidget {
  WrappedWebView(
    this._controller,
    { super.key }
  );

  final WebWebViewController _controller;

  @override
  State<StatefulWidget> createState() => _WrappedWebViewState();
}

class _WrappedWebViewState extends State<WrappedWebView> {
  @override
  Widget build (BuildContext context) {
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
            child: PlatformWebViewWidget(
              PlatformWebViewWidgetCreationParams(controller: widget._controller),
            ).build(context),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget._controller.dispose();
    super.dispose();
  }
}