import 'dart:js_interop';

@JS('_kitaPlayTone')
external void _kitaPlayTone(double frequency, double duration, String type);

/// Calls the _kitaPlayTone JS function defined in index.html.
void playWebTone(double frequency, double duration, String type) {
  try {
    _kitaPlayTone(frequency, duration, type);
  } catch (_) {
    // Silently fail if audio context not available
  }
}
