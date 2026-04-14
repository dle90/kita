import 'dart:js_interop';

@JS('_kitaPlayAudio')
external JSPromise<JSAny?> _jsPlayAudio(JSString url);

/// Play audio from a URL using the browser's Audio API (bridged via JS).
Future<void> playAudioUrl(String url) async {
  try {
    await _jsPlayAudio(url.toJS).toDart;
  } catch (_) {}
}
