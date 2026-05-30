// Student → Course detail (preview + lesson list + playback launcher).
//
// Visibility is enforced by the backend (only approved + public courses
// are returned by /api/student/video-courses/:id). Lessons are pre-
// filtered to bunnyStatus='ready' server-side, so every row here is
// guaranteed playable.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/api_service.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/unified_video_player/unified_video_player_screen.dart';
import '../../video_marketplace/controllers/video_marketplace_controller.dart';
import '../../video_marketplace/widgets/purchase_bottom_sheet.dart';

class StudentVideoCourseDetailScreen extends StatefulWidget {
  const StudentVideoCourseDetailScreen({super.key, required this.courseId});
  final String courseId;

  @override
  State<StudentVideoCourseDetailScreen> createState() => _StudentVideoCourseDetailScreenState();
}

class _StudentVideoCourseDetailScreenState extends State<StudentVideoCourseDetailScreen> {
  final _api = ApiService();
  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _course;
  List<Map<String, dynamic>> _lessons = [];

  // Track "watched" lessons locally (no backend progress endpoint yet —
  // hook for a future Phase 10.x progress-tracking API).
  final Set<String> _watched = <String>{};

  // Per-lesson "minting playback URL" spinner.
  String? _busyLessonId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await _api.fetchPublicVideoCourse(widget.courseId);
      final data = (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : <String, dynamic>{};
      _course = (data['course'] is Map) ? Map<String, dynamic>.from(data['course']) : null;
      _lessons = (data['lessons'] is List)
          ? (data['lessons'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : [];
    } catch (_) {
      _error = 'تعذّر تحميل الدورة';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _playLesson(Map<String, dynamic> lesson) async {
    final lessonId = lesson['id']?.toString();
    if (lessonId == null) return;

    // Phase 7 — block playback if the course is paid-and-unowned. The
    // backend signed-URL endpoint also rejects (402), but bouncing here
    // gives a clean UX before the round-trip.
    if (_isPaidUnowned) {
      _showSnack('عليك شراء الدورة أولاً.', error: true);
      await _openPurchaseSheet();
      return;
    }

    setState(() => _busyLessonId = lessonId);
    String playbackUrl = lesson['bunnyPlaybackUrl']?.toString() ?? '';
    try {
      // Mint a freshly-signed URL — short TTL means we should ALWAYS
      // re-mint at play time rather than rely on the URL embedded in
      // the list response (which could be stale by minutes).
      final res = await _api.fetchVideoLessonPlaybackUrl(
        courseId: widget.courseId,
        lessonId: lessonId,
      );
      final signed = res['url']?.toString();
      if (signed != null && signed.isNotEmpty) playbackUrl = signed;
    } catch (e) {
      // Paid courses currently return 402 — surface a friendly message.
      if (!mounted) return;
      _showSnack(_humanizePlaybackError(e), error: true);
      setState(() => _busyLessonId = null);
      return;
    }
    if (!mounted) return;
    setState(() {
      _busyLessonId = null;
      _watched.add(lessonId);
    });

    if (playbackUrl.isEmpty) {
      _showSnack('رابط التشغيل غير متوفر', error: true);
      return;
    }
    Get.to(() => UnifiedVideoPlayerScreen(
          videoUrl: playbackUrl,
          videoId: lessonId,
          title: lesson['title']?.toString() ?? 'درس',
          subtitle: _course?['title']?.toString(),
          thumbnailUrl: lesson['bunnyThumbnailUrl']?.toString(),
        ));
  }

  // ─── Phase 7 paid-gating helpers ──────────────────────────────────────────

  bool get _isPaidUnowned {
    final c = _course;
    if (c == null) return false;
    final isFree = c['isFree'] == true || c['is_free'] == true || c['price'] == 0;
    if (isFree) return false;
    final isOwned = c['isOwned'] == true ||
        c['is_owned'] == true ||
        c['hasAccess'] == true ||
        c['has_access'] == true;
    return !isOwned;
  }

  Widget _buildPurchaseCta(ColorScheme scheme) {
    final price = _course?['price'];
    final priceLabel = (price is num && price > 0) ? '${price.toInt()} د.ع' : '—';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.lock_outline, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('دورة مدفوعة',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              Text('اشترِ الدورة للوصول إلى الدروس · $priceLabel',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _openPurchaseSheet,
          icon: const Icon(Icons.shopping_bag_outlined, size: 16),
          label: const Text('شراء'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: scheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      ]),
    );
  }

  Future<void> _openPurchaseSheet() async {
    if (_course == null) return;
    final ctl = Get.isRegistered<VideoMarketplaceController>(tag: 'video-marketplace')
        ? Get.find<VideoMarketplaceController>(tag: 'video-marketplace')
        : Get.put(VideoMarketplaceController(), tag: 'video-marketplace-detail');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => PurchaseBottomSheet(course: _course!, controller: ctl),
    );
    // Refresh course state — a just-completed purchase flips isOwned.
    await _fetch();
  }

  String _humanizePlaybackError(Object e) {
    final s = e.toString();
    if (s.contains('402') || s.contains('coming soon') || s.contains('قريباً')) {
      return 'الدورات المدفوعة قريباً — قيد التطوير.';
    }
    if (s.contains('409')) {
      return 'هذا الدرس قيد المعالجة. حاول بعد قليل.';
    }
    if (s.contains('SocketException') || s.contains('DioException')) {
      return 'خطأ في الاتصال — تحقّق من الإنترنت ثم أعد المحاولة.';
    }
    return 'تعذّر تشغيل الفيديو الآن.';
  }

  void _showSnack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red.shade700 : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _formatDuration(dynamic seconds) {
    final n = (seconds is num) ? seconds.toInt() : int.tryParse(seconds?.toString() ?? '0') ?? 0;
    if (n <= 0) return '';
    final m = n ~/ 60;
    final s = n % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ----- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _errorView(scheme)
              : _course == null
                  ? const Center(child: Text('الدورة غير متوفرة'))
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: CustomScrollView(
                        slivers: [
                          _buildAppBar(scheme),
                          SliverToBoxAdapter(child: _buildMetaPanel(scheme)),
                          _buildLessonsSliver(scheme),
                          const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        ],
                      ),
                    ),
    );
  }

  Widget _errorView(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 8),
            Text(_error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(ColorScheme scheme) {
    final c = _course!;
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      title: Text(c['title']?.toString() ?? '',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(
              url: c['coverImage']?.toString() ?? '',
              fit: BoxFit.cover,
              fallbackIcon: Icons.movie_outlined,
            ),
            // Gradient overlay for legibility
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaPanel(ColorScheme scheme) {
    final c = _course!;
    final isFree = c['isFree'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c['title']?.toString() ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip(c['subject']?.toString() ?? '—', scheme.primary, icon: Icons.book_outlined),
            _chip(c['teachingStage']?.toString() ?? '—', scheme.secondary, icon: Icons.school_outlined),
            _chip(isFree ? 'مجاني' : '${c['price'] ?? 0} د.ع', isFree ? Colors.green : Colors.orange),
            if (_lessons.isNotEmpty)
              _chip('${_lessons.length} درس', Colors.indigo, icon: Icons.playlist_play_outlined),
          ]),
          if ((c['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              c['description'].toString(),
              style: TextStyle(fontSize: 14, height: 1.6, color: scheme.onSurface.withValues(alpha: 0.85)),
            ),
          ],
          if (_isPaidUnowned) ...[
            const SizedBox(height: 14),
            _buildPurchaseCta(scheme),
          ],
          const SizedBox(height: 14),
          Row(children: [
            const Text('قائمة الدروس', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (_watched.isNotEmpty)
              Text('${_watched.length}/${_lessons.length} مكتمل',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ]),
        ],
      ),
    );
  }

  Widget _buildLessonsSliver(ColorScheme scheme) {
    if (_lessons.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.video_library_outlined, size: 48, color: scheme.outline),
              const SizedBox(height: 8),
              Text('لم تُضف دروس جاهزة بعد', style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    return SliverList.separated(
      itemCount: _lessons.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (_, idx) => _buildLessonRow(scheme, _lessons[idx], idx),
    );
  }

  Widget _buildLessonRow(ColorScheme scheme, Map<String, dynamic> lesson, int idx) {
    final id = lesson['id']?.toString() ?? '';
    final watched = _watched.contains(id);
    final busy = _busyLessonId == id;
    final dur = _formatDuration(lesson['durationSeconds']);
    return ListTile(
      onTap: busy ? null : () => _playLesson(lesson),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: SizedBox(
        width: 96,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                url: lesson['bunnyThumbnailUrl']?.toString() ?? '',
                fit: BoxFit.cover,
                fallbackIcon: Icons.movie_outlined,
              ),
              Container(color: Colors.black.withValues(alpha: 0.2)),
              const Center(child: Icon(Icons.play_circle_filled, color: Colors.white, size: 28)),
              if (dur.isNotEmpty)
                Positioned(
                  bottom: 2, right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(dur, style: const TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                ),
            ],
          ),
        ),
      ),
      title: Row(children: [
        Container(
          width: 22, height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: watched ? Colors.green.withValues(alpha: 0.15) : scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: watched
              ? const Icon(Icons.check, size: 14, color: Colors.green)
              : Text('${idx + 1}', style: TextStyle(fontSize: 11, color: scheme.primary, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            lesson['title']?.toString() ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
      subtitle: (lesson['description']?.toString().isNotEmpty ?? false)
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                lesson['description'].toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            )
          : null,
      trailing: busy
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.chevron_left, size: 22),
    );
  }

  Widget _chip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
