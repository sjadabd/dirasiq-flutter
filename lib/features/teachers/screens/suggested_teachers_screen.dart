// Student → Suggested teachers (MulhimIQ design-system pass).
//
// Standalone pushed route (/suggested-teachers). Backed by
// ApiService.fetchSuggestedTeachers → GET /student/teachers/suggested. The
// recommendation logic is UNCHANGED — the backend returns teachers near the
// student, distance-sorted (closest first). Search is server-side.
//
// The endpoint returns ONLY: id, name, profile_image_path, distance, bio,
// experience_years, address (SuggestedTeacherRow). It does NOT return
// subject/specialization, academic stage, rating, course count, price range,
// or a "recommended" flag — so those fields, and the rating / stage /
// available-for-booking filter chips, are intentionally not rendered (no fake
// data). Distance is the only ranking signal and is already the default sort,
// so a redundant "الأقرب لك" chip is omitted too.
//
// There is no follow feature, and messaging a not-yet-connected teacher is a
// gated flow (only "My Teachers" exposes chat), so no متابعة / مراسلة button
// is shown here — the card action opens the existing teacher details screen.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'package:mulhimiq/shared/widgets/app_network_image.dart';
import 'package:mulhimiq/features/teachers/screens/teacher_details_screen.dart';

class SuggestedTeachersScreen extends StatefulWidget {
  const SuggestedTeachersScreen({super.key});

  @override
  State<SuggestedTeachersScreen> createState() => _SuggestedTeachersScreenState();
}

class _SuggestedTeachersScreenState extends State<SuggestedTeachersScreen> {
  final _api = ApiService();
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  bool _loading = false;
  bool _initialLoaded = false;
  String? _error;
  int _page = 1;
  final int _limit = 10;
  final double _maxDistance = 10.0;
  String? _search;
  List<Map<String, dynamic>> _items = [];
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) _error = null;
    });
    try {
      if (reset) {
        _page = 1;
        _items = [];
        _hasMore = true;
      }
      final res = await _api.fetchSuggestedTeachers(
        page: _page,
        limit: _limit,
        maxDistance: _maxDistance,
        search: _search,
      );
      final newItems = List<Map<String, dynamic>>.from(res['items'] ?? []);
      setState(() {
        _items.addAll(newItems);
        _hasMore = newItems.length >= _limit;
        _page++;
        _initialLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل المعلمين المقترحين');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _load();
    }
  }

  Future<void> _onRefresh() => _load(reset: true);

  void _submitSearch() {
    _search = _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim();
    _load(reset: true);
  }

  String _fullImageUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return '';
    if (pathOrUrl.startsWith('http')) return pathOrUrl;
    if (pathOrUrl.startsWith('/')) return '${AppConfig.serverBaseUrl}$pathOrUrl';
    return pathOrUrl;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();
    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Scaffold(
              backgroundColor: context.mq.page,
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('المعلمون المقترحون'),
                    Text('اكتشف أساتذة مناسبين لمرحلتك واهتماماتك', style: context.text.bodySmall),
                  ],
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: _searchField(context),
                ),
              ),
              body: RefreshIndicator(onRefresh: _onRefresh, child: _body(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final m = context.mq;
    return Padding(
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, 0, MqSpacing.lg, MqSpacing.sm),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        style: context.text.bodyMedium,
        onSubmitted: (_) => _submitSearch(),
        onChanged: (v) {
          if (v.isEmpty && _search != null) {
            _search = null;
            _load(reset: true);
          }
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: 'ابحث عن معلم…',
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: m.ink3),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          filled: true,
          fillColor: m.fill,
          border: OutlineInputBorder(borderRadius: MqRadius.brMd, borderSide: BorderSide(color: m.line)),
          enabledBorder: OutlineInputBorder(borderRadius: MqRadius.brMd, borderSide: BorderSide(color: m.line)),
          focusedBorder: OutlineInputBorder(borderRadius: MqRadius.brMd, borderSide: BorderSide(color: m.accent)),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _search = null;
                    _load(reset: true);
                    setState(() {});
                  },
                ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (!_initialLoaded && _loading) return _skeleton(context);
    if (_error != null && _items.isEmpty) return _errorView(context);
    if (_items.isEmpty) return _empty(context);

    return ListView.separated(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.xxxl),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: MqSpacing.md),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        return _teacherCard(context, _items[index]);
      },
    );
  }

  Widget _teacherCard(BuildContext context, Map<String, dynamic> t) {
    final name = (t['name'] ?? t['teacher_name'] ?? 'غير معروف').toString();
    final imgUrl = _fullImageUrl(
        (t['profileImagePath'] ?? t['profile_image_path'] ?? t['teacher_profile_image_path'] ?? t['avatar'] ?? '')
            .toString());
    final bio = (t['bio'] ?? '').toString().trim();
    final exp = t['experience_years'] ?? t['experienceYears'];
    final expYears = (exp is num) ? exp.toInt() : int.tryParse(exp?.toString() ?? '') ?? 0;
    final distance = t['distance'];
    final distStr = distance is num ? '${distance.toStringAsFixed(1)} كم' : '';
    final id = (t['id'] ?? t['teacher_id'] ?? t['teacherId'] ?? '').toString();

    void openDetails() {
      if (id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هوية المعلم غير متوفرة')));
        return;
      }
      Get.to(() => TeacherDetailsScreen(teacherId: id));
    }

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      onTap: openDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: AppNetworkImage(
                    url: imgUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person_rounded,
                  ),
                ),
              ),
              MqSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(bio, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    if (expYears > 0 || distStr.isNotEmpty) ...[
                      MqSpacing.gapXs,
                      Wrap(spacing: MqSpacing.xs, runSpacing: MqSpacing.xxs, children: [
                        if (expYears > 0)
                          MqBadge(label: '$expYears سنوات خبرة', tone: MqBadgeTone.accent, icon: Icons.workspace_premium_outlined),
                        if (distStr.isNotEmpty)
                          MqBadge(label: distStr, tone: MqBadgeTone.neutral, icon: Icons.location_on_outlined),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
          MqSpacing.gapSm,
          Align(
            alignment: Alignment.centerLeft,
            child: MqButton(
              label: 'عرض التفاصيل',
              icon: Icons.arrow_back_rounded,
              size: MqButtonSize.small,
              variant: MqButtonVariant.tonal,
              expand: false,
              onPressed: openDetails,
            ),
          ),
        ],
      ),
    );
  }

  // ── states ──────────────────────────────────────────────────────────────────

  Widget _empty(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(child: Column(children: [
          Container(
            padding: const EdgeInsets.all(MqSpacing.lg),
            decoration: BoxDecoration(color: m.accentSoft, shape: BoxShape.circle),
            child: Icon(Icons.person_search_outlined, size: 44, color: m.accent),
          ),
          MqSpacing.gapMd,
          Text('لا يوجد معلمون مقترحون', style: context.text.titleMedium),
          MqSpacing.gapXs,
          Text('جرّب توسيع بحثك أو تحديث الصفحة لاحقاً.', textAlign: TextAlign.center, style: context.text.bodySmall),
        ])),
      ],
    );
  }

  Widget _errorView(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 44, color: m.error),
          MqSpacing.gapMd,
          Text(_error ?? 'حدث خطأ', textAlign: TextAlign.center, style: context.text.bodyMedium),
          MqSpacing.gapMd,
          MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: () => _load(reset: true)),
        ])),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.lg),
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.sm),
            child: MqCard(
              padding: const EdgeInsets.all(MqSpacing.md),
              child: Row(children: [
                Container(width: 54, height: 54, decoration: BoxDecoration(color: m.fill2, shape: BoxShape.circle)),
                MqSpacing.gapMd,
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 14, width: 140, decoration: BoxDecoration(color: m.fill2, borderRadius: MqRadius.brSm)),
                    const SizedBox(height: 8),
                    Container(height: 11, width: double.infinity, decoration: BoxDecoration(color: m.fill2, borderRadius: MqRadius.brSm)),
                  ]),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
