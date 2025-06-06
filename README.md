highcharts\_flutter\_webwebview
===============================
Extended webview_flutter_web for Highcharts.

Additions:

- `addJavaScriptChannel`
- `dispose`
- `getTitle`
- `mounted`
- `removeJavaScriptChannel`
- `runJavaScript`

## Development

- Use `flutter build web` to build web target.
- Use `flutter test --platform=chrome` to run unit tests.
- Use the following to run integration tests:
  ```
  (cd example && flutter drive -d chrome --driver=test_driver/integration_test.dart --target=integration_test/webview_flutter_test.dart)
  ```
  This requires to run `highcharts_flutter_testserver`.

---

Following is the original README:

## webview\_flutter\_web

This is an implementation of the [`webview_flutter`](https://pub.dev/packages/webview_flutter) plugin for web.

It is currently severely limited and doesn't implement most of the available functionality.
The following functionality is currently available:

- `loadRequest`
- `loadHtmlString` (Without `baseUrl`)

Nothing else is currently supported.

## Usage

This package is not an endorsed implementation of the `webview_flutter` plugin
yet, so it currently requires extra setup to use:

* [Add this package](https://pub.dev/packages/webview_flutter_web/install)
  as an explicit dependency of your project, in addition to depending on
  `webview_flutter`.

Once the step above is complete, the APIs from `webview_flutter` listed
above can be used as normal on web.
