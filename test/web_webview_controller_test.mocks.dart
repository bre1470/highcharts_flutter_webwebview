// Mocks generated by Mockito 5.4.4 from annotations
// in webview_flutter_web/test/web_webview_controller_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;
import 'dart:typed_data' as _i4;

import 'package:mockito/mockito.dart' as _i1;
import 'package:webview_flutter_web/src/http_request_factory.dart' as _i2;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeObject_0 extends _i1.SmartFake implements Object {
  _FakeObject_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [HttpRequestFactory].
///
/// See the documentation for Mockito's code generation for more information.
class MockHttpRequestFactory extends _i1.Mock
    implements _i2.HttpRequestFactory {
  @override
  _i3.Future<Object> request(
    String? url, {
    String? method = r'GET',
    bool? withCredentials = false,
    String? mimeType,
    Map<String, String>? requestHeaders,
    _i4.Uint8List? sendData,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #request,
          [url],
          {
            #method: method,
            #withCredentials: withCredentials,
            #mimeType: mimeType,
            #requestHeaders: requestHeaders,
            #sendData: sendData,
          },
        ),
        returnValue: _i3.Future<Object>.value(_FakeObject_0(
          this,
          Invocation.method(
            #request,
            [url],
            {
              #method: method,
              #withCredentials: withCredentials,
              #mimeType: mimeType,
              #requestHeaders: requestHeaders,
              #sendData: sendData,
            },
          ),
        )),
        returnValueForMissingStub: _i3.Future<Object>.value(_FakeObject_0(
          this,
          Invocation.method(
            #request,
            [url],
            {
              #method: method,
              #withCredentials: withCredentials,
              #mimeType: mimeType,
              #requestHeaders: requestHeaders,
              #sendData: sendData,
            },
          ),
        )),
      ) as _i3.Future<Object>);
}
