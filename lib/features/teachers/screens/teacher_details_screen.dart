import 'package:flutter/material.dart';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح الخرائط')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('تفاصيل المعلم')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError(cs)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // ✅ صورة المعلم في الأعلى
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.network(
                              _fullImageUrl(
                                _teacher?['profileImagePath'] ?? '',
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: cs.surfaceVariant,
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _teacher?['name'] ?? 'غير معروف',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ✅ المواد التي يدرّسها
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
                    ..._courses
                        .asMap()
                        .entries
                        .map(
                          (e) => _buildCourseItem(e.value, e.key, cs, isDark),
                        )
                        .toList(),
                ],
              ),
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
          color: isDark ? cs.primary.withOpacity(0.3) : cs.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
