// Phase 7 — resume-playback storage for the UnifiedVideoPlayer.
//
// Persists the last playback position per videoId in SharedPreferences so
// re-opening the same lesson resumes from where the student left off. Two
// conventions are baked in here so callers don't have to reinvent them:
//
//   - A 2-second rewind on read (softens the "drop into mid-sentence" feel).
//   - The widget self-clears the entry on completion via [clear], so a
//     fully-watched video re-starts from zero on its next open.
//
// The store is intentionally local-only — there is no per-account scoping,
// so a device shared between two students will see each other's resume
// points. That's an accepted trade-off until the backend grows a progress
// endpoint (queued for a future phase).

import 'package:shared_preferences/shared_preferences.dart';

class PlaybackProgressStorage {
  PlaybackProgressStorage._();

  /// Bumped if the on-disk shape ever needs to change. Old keys become
  /// invisible to the new code rather than getting mis-parsed.
  static const String _prefix = 'video_progress_v1:';

  /// Position seconds below this threshold are treated as "didn't really
  /// start" and not persisted.
  static const int _minSaveSeconds = 3;

  /// Rewind applied at read time so the resume lands a hair before the
  /// last save (avoids dropping the student into the middle of a word).
  static const int _readRewindSeconds = 2;

  /// Returns the saved position for [videoId], adjusted by a small rewind,
  /// or `null` if no entry exists. Caller is responsible for clamping to
  /// the actual video duration.
  static Future<Duration?> read(String videoId) async {
    if (videoId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt('$_prefix$videoId');
    if (seconds == null || seconds <= 0) return null;
    final adjusted = seconds - _readRewindSeconds;
    return Duration(seconds: adjusted < 0 ? 0 : adjusted);
  }

  /// Persists [position] for [videoId]. No-ops if the position is too
  /// short to be meaningful.
  static Future<void> save(String videoId, Duration position) async {
    if (videoId.isEmpty) return;
    final seconds = position.inSeconds;
    if (seconds < _minSaveSeconds) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$videoId', seconds);
  }

  /// Removes the saved position for [videoId]. Called on completion so a
  /// re-open of a fully-watched lesson starts from zero.
  static Future<void> clear(String videoId) async {
    if (videoId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$videoId');
  }
}
