// Student → Video course detail (preview + lesson list + playback launcher).
//
// MulhimIQ design-system pass. Visibility is enforced by the backend (only
// approved + public courses are returned by /api/student/video-courses/:id).
// Lessons are pre-filtered to bunnyStatus='ready' server-side, so every row
// here is guaranteed playable.
//
// Playback, paid-gating, purchase, and the local "watched" tracking are
// UNCHANGED — only the presentation was restyled.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/api_service.dart';
import '../../../core/utils/money.dart';
import '../../../shared/design_system/design_system.dart';
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

  // الدروس | نظرة عامة
  int _tab = 0;

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

  Future<void> _playLesson(Map<String, dynamic> lesson) {
    final idx = _lessons.indexWhere((l) => l['id']?.toString() == lesson['id']?.toString());
    return _playLessonAt(idx < 0 ? 0 : idx);
  }

  /// Mints a fresh signed URL for the lesson at [index] and opens the player.
  /// When [replace] is true (used by in-player next/prev), the current player
  /// route is replaced so each lesson is a brand-new player instance — the
  /// Bunny playback / progress logic is never re-entered, just reconstructed.
  Future<void> _playLessonAt(int index, {bool replace = false}) async {
    if (index < 0 || index >= _lessons.length) return;
    final lesson = _lessons[index];
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

    final player = UnifiedVideoPlayerScreen(
      videoUrl: playbackUrl,
      videoId: lessonId,
      title: lesson['title']?.toString() ?? 'درس',
      subtitle: _course?['title']?.toString(),
      thumbnailUrl: lesson['bunnyThumbnailUrl']?.toString(),
      ownerLabel: _ownerLabel,
      lessonTitles: _lessons.map((l) => (l['title'] ?? 'درس').toString()).toList(),
      lessonIndex: index,
      onSelectLesson: (i) => _playLessonAt(i, replace: true),
    );
    if (replace) {
      Get.off(() => player);
    } else {
      Get.to(() => player);
    }
  }

  // ─── Phase 7 paid-gating helpers (UNCHANGED) ──────────────────────────────

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

  bool get _isFree {
    final c = _course;
    if (c == null) return false;
    return c['isFree'] == true || c['is_free'] == true || c['price'] == 0;
  }

  /// Ownership label for the player watermark — the course teacher, if known.
  String? get _ownerLabel {
    final c = _course;
    if (c == null) return null;
    final t = (c['teacherName'] ??
            c['teacher_name'] ??
            (c['teacher'] is Map ? (c['teacher'] as Map)['name'] : null) ??
            '')
        .toString()
        .trim();
    return t.isEmpty ? null : t;
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

  int get _totalSeconds {
    var sum = 0;
    for (final l in _lessons) {
      final v = l['durationSeconds'];
      sum += (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '0') ?? 0;
    }
    return sum;
  }

  String get _totalDurationLabel {
    final n = _totalSeconds;
    if (n <= 0) return '';
    final h = n ~/ 3600;
    final m = (n % 3600) ~/ 60;
    if (h > 0) return '$h س $m د';
    if (m > 0) return '$m د';
    return '$n ث';
  }

  // ----- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();
    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.mq.page,
            body: _loading
                ? _skeleton(context)
                : _error.isNotEmpty
                    ? _errorView(context)
                    : _course == null
                        ? Center(child: Text('الدورة غير متوفرة', style: context.text.bodyMedium))
                        : RefreshIndicator(
                            onRefresh: _fetch,
                            child: CustomScrollView(
                              slivers: [
                                _buildAppBar(context),
                                SliverToBoxAdapter(child: _buildMetaPanel(context)),
                                SliverToBoxAdapter(child: _buildTabBar(context)),
                                if (_tab == 0)
                                  _buildLessonsSliver(context)
                                else
                                  SliverToBoxAdapter(child: _buildOverview(context)),
                                const SliverToBoxAdapter(child: SizedBox(height: MqSpacing.xxxl)),
                              ],
                            ),
                          ),
          ),
        ),
      ),
    );
  }

  Widget _errorView(BuildContext context) {
    final m = context.mq;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 44, color: m.error),
          MqSpacing.gapMd,
          Text(_error, textAlign: TextAlign.center, style: context.text.bodyMedium),
          MqSpacing.gapMd,
          MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: _fetch),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final m = context.mq;
    final c = _course!;
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: m.page,
      foregroundColor: m.ink,
      title: Text(c['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
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
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black45, Colors.transparent, Colors.black54],
                ),
              ),
            ),
            const Center(
              child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 56),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaPanel(BuildContext context) {
    final m = context.mq;
    final c = _course!;
    final price = c['price'];
    final priceLabel = (price is num && price > 0) ? '${fmtMoney(price)} د.ع' : '—';
    return Padding(
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c['title']?.toString() ?? '', style: context.text.titleLarge),
          if (_ownerLabel != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.person_outline_rounded, size: 14, color: m.ink3),
              MqSpacing.gapXxs,
              Text(_ownerLabel!, style: context.text.bodySmall),
            ]),
          ],
          MqSpacing.gapSm,
          Wrap(spacing: MqSpacing.xs, runSpacing: MqSpacing.xs, children: [
            if ((c['subject']?.toString() ?? '').isNotEmpty)
              MqBadge(label: c['subject'].toString(), tone: MqBadgeTone.accent, icon: Icons.book_outlined),
            if ((c['teachingStage']?.toString() ?? '').isNotEmpty)
              MqBadge(label: c['teachingStage'].toString(), tone: MqBadgeTone.neutral, icon: Icons.school_outlined),
            MqBadge(
              label: _isFree ? 'مجاني' : '${fmtMoney(c['price'])} د.ع',
              tone: _isFree ? MqBadgeTone.success : MqBadgeTone.orange,
            ),
            if (_lessons.isNotEmpty)
              MqBadge(label: '${_lessons.length} درس', tone: MqBadgeTone.neutral, icon: Icons.playlist_play_outlined),
            if (_totalDurationLabel.isNotEmpty)
              MqBadge(label: _totalDurationLabel, tone: MqBadgeTone.neutral, icon: Icons.schedule_rounded),
          ]),
          // CTA — preserve purchase vs play gating.
          if (_isPaidUnowned) ...[
            MqSpacing.gapMd,
            _buildPurchaseCta(context, priceLabel),
          ] else if (_lessons.isNotEmpty) ...[
            MqSpacing.gapMd,
            MqButton(
              label: _watched.isEmpty ? 'ابدأ المشاهدة' : 'متابعة المشاهدة',
              icon: Icons.play_arrow_rounded,
              onPressed: () => _playLesson(_firstUnwatchedOrFirst()),
            ),
            if (_watched.isNotEmpty) ...[
              MqSpacing.gapSm,
              MqLinearProgress(
                value: _lessons.isEmpty ? 0 : _watched.length / _lessons.length,
                showLabel: true,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _firstUnwatchedOrFirst() {
    for (final l in _lessons) {
      if (!_watched.contains(l['id']?.toString())) return l;
    }
    return _lessons.first;
  }

  Widget _buildPurchaseCta(BuildContext context, String priceLabel) {
    final m = context.mq;
    return MqSurface(
      tone: MqSurfaceTone.accent,
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(children: [
        Icon(Icons.lock_outline_rounded, color: m.accent, size: MqSize.iconMd),
        MqSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('دورة مدفوعة', style: context.text.titleSmall),
              const SizedBox(height: 2),
              Text('اشترك للوصول إلى كل الدروس · $priceLabel', style: context.text.bodySmall),
            ],
          ),
        ),
        MqSpacing.gapSm,
        MqButton(
          label: 'اشترك الآن',
          icon: Icons.shopping_bag_outlined,
          size: MqButtonSize.small,
          expand: false,
          onPressed: _openPurchaseSheet,
        ),
      ]),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.xs),
      child: Row(children: [
        MqChip(
          label: 'الدروس${_lessons.isNotEmpty ? ' (${_lessons.length})' : ''}',
          selected: _tab == 0,
          onTap: () => setState(() => _tab = 0),
        ),
        const SizedBox(width: MqSpacing.xs),
        MqChip(
          label: 'نظرة عامة',
          selected: _tab == 1,
          onTap: () => setState(() => _tab = 1),
        ),
      ]),
    );
  }

  Widget _buildOverview(BuildContext context) {
    final c = _course!;
    final desc = (c['description']?.toString() ?? '').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.sm),
      child: MqCard(
        padding: const EdgeInsets.all(MqSpacing.md),
        child: desc.isEmpty
            ? Text('لا يوجد وصف لهذه الدورة.', style: context.text.bodySmall)
            : Text(desc, style: context.text.bodyMedium?.copyWith(height: 1.6)),
      ),
    );
  }

  Widget _buildLessonsSliver(BuildContext context) {
    final m = context.mq;
    if (_lessons.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(MqSpacing.xxl),
          child: Column(
            children: [
              Icon(Icons.video_library_outlined, size: 44, color: m.ink3),
              MqSpacing.gapSm,
              Text('لم تُضف دروس جاهزة بعد', style: context.text.bodyMedium),
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.lg, vertical: MqSpacing.xs),
      sliver: SliverList.separated(
        itemCount: _lessons.length,
        separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
        itemBuilder: (_, idx) => _buildLessonCard(context, _lessons[idx], idx),
      ),
    );
  }

  Widget _buildLessonCard(BuildContext context, Map<String, dynamic> lesson, int idx) {
    final m = context.mq;
    final id = lesson['id']?.toString() ?? '';
    final watched = _watched.contains(id);
    final busy = _busyLessonId == id;
    final dur = _formatDuration(lesson['durationSeconds']);
    final locked = _isPaidUnowned;
    final desc = lesson['description']?.toString() ?? '';

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.sm),
      onTap: busy ? null : () => _playLesson(lesson),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with play / lock overlay.
          SizedBox(
            width: 96,
            height: 56,
            child: ClipRRect(
              borderRadius: MqRadius.brMd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    url: lesson['bunnyThumbnailUrl']?.toString() ?? '',
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.movie_outlined,
                  ),
                  Container(color: Colors.black.withValues(alpha: 0.22)),
                  Center(
                    child: Icon(
                      locked ? Icons.lock_rounded : Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  if (dur.isNotEmpty)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(dur, style: const TextStyle(color: Colors.white, fontSize: 9)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          MqSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: watched ? m.success.withValues(alpha: 0.15) : m.accentSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: watched
                        ? Icon(Icons.check_rounded, size: 14, color: m.success)
                        : Text('${idx + 1}',
                            style: context.text.labelSmall?.copyWith(
                                color: m.accent, fontWeight: FontWeight.w700)),
                  ),
                  MqSpacing.gapSm,
                  Expanded(
                    child: Text(lesson['title']?.toString() ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                  ),
                  if (busy)
                    const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (watched)
                    MqBadge(label: 'تمت المشاهدة', tone: MqBadgeTone.success),
                ]),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeleton(BuildContext context) {
    final m = context.mq;
    Widget box(double h, {double? w, BorderRadius? r}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: m.fill2, borderRadius: r ?? MqRadius.brLg));
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        box(220, r: BorderRadius.zero),
        Padding(
          padding: const EdgeInsets.all(MqSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              box(20, w: 240),
              MqSpacing.gapSm,
              box(14, w: 160),
              MqSpacing.gapLg,
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: MqSpacing.sm),
                  child: MqCard(
                    padding: const EdgeInsets.all(MqSpacing.sm),
                    child: Row(children: [
                      box(56, w: 96, r: MqRadius.brMd),
                      MqSpacing.gapMd,
                      Expanded(child: box(14)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
