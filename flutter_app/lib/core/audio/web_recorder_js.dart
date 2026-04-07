import 'dart:async';
import 'dart:js_interop';

@JS('_kitaStartRecording')
external JSPromise<JSBoolean> _jsStartRecording();

@JS('_kitaStopRecording')
external JSPromise<JSString?> _jsStopRecording();

/// Start recording via JS MediaRecorder.
Future<bool> startWebRecording() async {
  try {
    final result = await _jsStartRecording().toDart;
    return result.toDart;
  } catch (_) {
    return false;
  }
}

/// Stop recording and return base64-encoded audio data.
Future<String?> stopWebRecording() async {
  try {
    final result = await _jsStopRecording().toDart;
    return result?.toDart;
  } catch (_) {
    return null;
  }
}
