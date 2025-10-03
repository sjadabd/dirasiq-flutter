import 'package:flutter/material.dart';
import 'dart:io';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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

  String _fullImageUrl(String? p) {
    if (p == null || p.isEmpty) return '';
    if (p.startsWith('http')) return p;
    if (p.startsWith('/')) return '${AppConfig.serverBaseUrl}$p';
    return p;
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<void> _openOnMaps() async {
    final lat = _toDouble(_teacher?['latitude']);
    final lng = _toDouble(_teacher?['longitude']);
    if (lat != null && lng != null) {
      // نحاول بعدة روابط لضمان العمل على معظم الأجهزة
      final latStr = lat.toStringAsFixed(6);
      final lngStr = lng.toStringAsFixed(6);

      final candidates = <Uri>[
        // Google Maps app
        Uri.parse('comgooglemaps://?q=$latStr,$lngStr'),
        // Android geo scheme
        Uri.parse('geo:$latStr,$lngStr?q=$latStr,$lngStr'),
        // Google Maps web
        Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latStr,$lngStr',
        ),
        // Apple Maps (iOS)
        Uri.parse('https://maps.apple.com/?q=$latStr,$lngStr'),
      ];

      bool launched = false;
      Uri? googleWeb;
      for (final u in candidates) {
        if (Platform.isIOS && u.scheme == 'geo')
          continue; // geo لا يعمل على iOS
        if (u.scheme.startsWith('http')) googleWeb = u; // خزّن رابط الويب
        if (await canLaunchUrl(u)) {
          launched = await launchUrl(u, mode: LaunchMode.externalApplication);
          if (launched) break;
        }
      }

      // محاولات إضافية لروابط الويب في حال لم يُفتح تطبيق خارجي
      if (!launched && googleWeb != null) {
        // جرّب الإطلاق بالإعداد الافتراضي للنظام
        launched = await launchUrl(googleWeb, mode: LaunchMode.platformDefault);
        if (!launched) {
          // جرّب فتح داخل التطبيق كمتصفح مدمج
          launched = await launchUrl(
            googleWeb,
            mode: LaunchMode.inAppBrowserView,
          );
        }
      }

      if (!launched && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر فتح الخرائط')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('إحداثيات المعلم غير متوفرة')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المعلم')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: cs.error, size: 36),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 72,
                          height: 72,
                          color: cs.surfaceVariant,
                          child:
                              (_fullImageUrl(
                                _teacher?['profileImagePath'],
                              ).isEmpty)
                              ? Icon(Icons.person, color: cs.onSurfaceVariant)
                              : Image.network(
                                  _fullImageUrl(_teacher?['profileImagePath']),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.person,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_teacher?['name'] ?? '').toString(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _subjects
                                  .map(
                                    (s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.secondaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        (s['name'] ?? '').toString(),
                                        style: TextStyle(
                                          color: cs.onSecondaryContainer,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _openOnMaps,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('عرض موقع المعلم على الخريطة'),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'الدورات',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._courses.map((c) => _CourseItem(course: c)).toList(),
                ],
              ),
            ),
    );
  }
}

class _CourseItem extends StatelessWidget {
  final Map<String, dynamic> course;
  const _CourseItem({required this.course});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
    final gradeName = course['grade'] is Map
        ? (course['grade']['name'] ?? '').toString()
        : (course['grade_name'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 52,
            height: 52,
            color: cs.surfaceVariant,
            child: imgUrl.isEmpty
                ? Icon(Icons.school, color: cs.onSurfaceVariant)
                : Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.school, color: cs.onSurfaceVariant),
                  ),
          ),
        ),
        title: Text(
          (course['course_name'] ?? '').toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (gradeName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      gradeName,
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontSize: 11,
                      ),
                    ),
                  ),
                if (subjectName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      subjectName,
                      style: TextStyle(
                        color: cs.onSecondaryContainer,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'السعر: $priceStr د.ع',
              style: TextStyle(
                color: cs.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: cs.onSurfaceVariant,
        ),
        onTap: () {
          // لاحقاً: فتح تفاصيل الكورس لو أردت
        },
      ),
    );
  }
}
