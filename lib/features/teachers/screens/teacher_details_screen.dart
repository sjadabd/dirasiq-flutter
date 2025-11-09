import 'package:flutter/material.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:better_player_plus/better_player_plus.dart';

class TeacherDetailsScreen extends StatefulWidget {
  final String teacherId;
  const TeacherDetailsScreen({super.key, required this.teacherId});

  @override
  State<TeacherDetailsScreen> createState() => _TeacherDetailsScreenState();
}

class _TeacherDetailsScreenState extends State<TeacherDetailsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _teacher;
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _courses = [];
  // Intro video state
  bool _introLoading = true;
  String? _introError;
  Map<String, dynamic>? _introData; // response.data
  String?
  _contentBase; // response.content_url normalized without trailing slash
  BetterPlayerController? _bpController;

  @override
  void initState() {
    super.initState();
    _load();
    _loadIntro();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchTeacherSubjectsCourses(widget.teacherId);
      setState(() {
        _teacher = Map<String, dynamic>.from(data['teacher'] ?? {});
        _subjects = List<Map<String, dynamic>>.from(data['subjects'] ?? []);
        _courses = List<Map<String, dynamic>>.from(data['courses'] ?? []);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadIntro() async {
    setState(() {
      _introLoading = true;
      _introError = null;
    });
    try {
      final res = await _api.fetchTeacherIntroVideo(widget.teacherId);
      final base = (res['content_url']?.toString() ?? '').replaceAll(
        RegExp(r"/+$"),
        '',
      );
      final data = Map<String, dynamic>.from(res['data'] ?? {});
      setState(() {
        _introData = data;
        _contentBase = base.isEmpty ? AppConfig.serverBaseUrl : base;
      });
    } catch (e) {
      setState(() => _introError = e.toString());
    } finally {
      if (mounted) setState(() => _introLoading = false);
    }
  }

  String _absFromContent(String? p) {
    if (p == null || p.isEmpty) return '';
    final base = (_contentBase ?? AppConfig.serverBaseUrl).replaceAll(
      RegExp(r"/+$"),
      '',
    );
    if (p.startsWith('http')) return p;
    if (p.startsWith('/')) return '$base$p';
    return '$base/$p';
  }

  void _setupBetterPlayer({required String manifestUrl, String? thumbnail}) {
    try {
      final url = _absFromContent(manifestUrl);
      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        url,
        useAsmsSubtitles: true,
        useAsmsTracks: true,
        placeholder: (thumbnail != null && thumbnail.isNotEmpty)
            ? Image.network(_absFromContent(thumbnail), fit: BoxFit.cover)
            : null,
      );
      final config = BetterPlayerConfiguration(
        autoPlay: false,
        looping: false,
        fit: BoxFit.cover,
        handleLifecycle: true,
        autoDetectFullscreenDeviceOrientation: true,
        allowedScreenSleep: false,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          enableSkips: true,
          enableQualities: true,
          enableFullscreen: true,
          showControlsOnInitialize: false,
        ),
      );
      final controller = BetterPlayerController(config);
      controller.setupDataSource(dataSource);
      setState(() => _bpController = controller);
    } catch (e) {
      setState(() => _introError = 'تعذر تشغيل الفيديو: $e');
    }
  }

  @override
  void dispose() {
    _bpController?.dispose();
    super.dispose();
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<void> _openOnMaps() async {
    final lat = _toDouble(_teacher?['latitude']);
    final lng = _toDouble(_teacher?['longitude']);
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('إحداثيات المعلم غير متوفرة')),
      );
      return;
    }

    final latStr = lat.toStringAsFixed(6);
    final lngStr = lng.toStringAsFixed(6);
    final googleMapsUri = Uri.parse('comgooglemaps://?q=$latStr,$lngStr');
    final fallbackWebUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latStr,$lngStr',
    );

    try {
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(fallbackWebUri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح الخرائط')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = (_teacher?['name'] ?? _teacher?['full_name'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: Text(name.isEmpty ? 'تفاصيل المعلم' : name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null
                ? _buildError(cs)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildIntroVideoSection(cs),
                        const SizedBox(height: 16),
                        if (_subjects.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _subjects
                                .map(
                                  (s) => Chip(
                                    label: Text(
                                      s['name'] ?? '',
                                      style: TextStyle(
                                        color: cs.onSecondaryContainer,
                                      ),
                                    ),
                                    backgroundColor: cs.secondaryContainer,
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _openOnMaps,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('عرض موقع المعلم على الخريطة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'الدورات',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_courses.isEmpty)
                          Text(
                            'لا توجد دورات حالياً',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          )
                        else
                          ..._courses.asMap().entries.map(
                            (e) => _buildCourseItem(e.value, e.key, cs, isDark),
                          ),
                      ],
                    ),
                  )),
    );
  }

  Widget _buildIntroVideoSection(ColorScheme cs) {
    if (_introLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('جاري تحميل الفيديو التعريفي...'),
          ],
        ),
      );
    }

    if (_introError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(_introError!, style: TextStyle(color: cs.onErrorContainer)),
      );
    }

    final data = _introData ?? const {};
    final status = (data['status'] ?? 'none').toString();
    if (status != 'ready') {
      final msg =
          {
            'processing': 'الفيديو قيد المعالجة، حاول لاحقاً',
            'failed': 'تعذر تجهيز الفيديو التعريفي',
            'none': 'لا يوجد فيديو تعريفي',
          }[status] ??
          'لا يوجد فيديو تعريفي';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          ],
        ),
      );
    }

    final manifest = data['manifestUrl']?.toString() ?? '';
    final thumb = data['thumbnailUrl']?.toString() ?? '';
    final controller = _bpController;

    if (controller == null && manifest.isNotEmpty) {
      // initialize once when data becomes ready
      _setupBetterPlayer(manifestUrl: manifest, thumbnail: thumb);
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: (_bpController != null)
            ? BetterPlayer(controller: _bpController!)
            : Container(color: cs.surfaceContainerHighest),
      ),
    );
  }

  Widget _buildError(ColorScheme cs) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 36),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
        ],
      ),
    ),
  );

  Widget _buildCourseItem(
    Map<String, dynamic> course,
    int index,
    ColorScheme cs,
    bool isDark,
  ) {
    final images = (course['course_images'] is List)
        ? (course['course_images'] as List)
        : const [];
    final img = images.isNotEmpty ? images.first?.toString() : null;
    String imgUrl;
    if (img == null || img.isEmpty) {
      imgUrl = '';
    } else if (img.startsWith('http')) {
      imgUrl = img;
    } else {
      imgUrl = '${AppConfig.serverBaseUrl}$img';
    }

    final priceNum = (course['price'] is num)
        ? (course['price'] as num).toDouble()
        : double.tryParse(course['price']?.toString() ?? '0') ?? 0;
    final priceStr = NumberFormat('#,###').format(priceNum);

    final subjectName = course['subject'] is Map
        ? (course['subject']['name'] ?? '').toString()
        : (course['subject_name'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 52,
            height: 52,
            color: cs.surfaceContainerHighest,
            child: imgUrl.isEmpty
                ? Icon(Icons.school, color: cs.onSurfaceVariant)
                : Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.school, color: cs.onSurfaceVariant),
                  ),
          ),
        ),
        title: Text(
          course['course_name'] ?? '',
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'المادة: $subjectName\nالسعر: $priceStr د.ع',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
