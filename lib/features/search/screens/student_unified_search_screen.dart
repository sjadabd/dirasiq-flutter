import 'package:flutter/material.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/features/teachers/screens/teacher_details_screen.dart';
import 'package:mulhimiq/features/courses/screens/course_details_screen.dart';

class StudentUnifiedSearchScreen extends StatefulWidget {
  final String? initialQuery;
  const StudentUnifiedSearchScreen({super.key, this.initialQuery});

  @override
  State<StudentUnifiedSearchScreen> createState() =>
      _StudentUnifiedSearchScreenState();
}

class _StudentUnifiedSearchScreenState
    extends State<StudentUnifiedSearchScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String _query = '';
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _subjects = [];

  @override
  void initState() {
    super.initState();
    // Autofocus when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      if (widget.initialQuery != null &&
          widget.initialQuery!.trim().isNotEmpty) {
        _controller.text = widget.initialQuery!.trim();
        _performSearch(widget.initialQuery!);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String q) async {
    final query = q.trim();
    setState(() {
      _query = query;
      _error = null;
      _loading = query.isNotEmpty;
      _teachers = [];
      _courses = [];
      _subjects = [];
    });
    if (query.isEmpty) return;
    try {
      final resp = await _api.searchStudentUnified(
        q: query,
        page: 1,
        limit: 10,
        maxDistance: 8,
      );
      final data = resp['data'] ?? resp;
      setState(() {
        _teachers = List<Map<String, dynamic>>.from(
          (data['teachers'] ?? []) as List,
        );
        _courses = List<Map<String, dynamic>>.from(
          (data['courses'] ?? []) as List,
        );
        _subjects = List<Map<String, dynamic>>.from(
          (data['subjects'] ?? []) as List,
        );
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: _performSearch,
          onChanged: (v) {
            // Optional: only search when 2+ chars to reduce calls
            if (v.trim().length >= 2) {
              _performSearch(v);
            } else {
              setState(() {
                _query = v;
                _teachers = [];
                _courses = [];
                _subjects = [];
                _loading = false;
                _error = null;
              });
            }
          },
          decoration: InputDecoration(
            hintText: 'ابحث عن مادة، معلم، أو دورة...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              'ابدأ البحث بكتابة كلمة مفتاحية',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.error),
          ),
        ),
      );
    }

    final hasAny =
        _teachers.isNotEmpty || _courses.isNotEmpty || _subjects.isNotEmpty;
    if (!hasAny) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'لا توجد نتائج لـ "$_query"',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_teachers.isNotEmpty) ...[
          _SectionHeader(title: 'معلمون'),
          ..._teachers.map((t) => _TeacherTile(t)),
          const SizedBox(height: 10),
        ],
        if (_courses.isNotEmpty) ...[
          _SectionHeader(title: 'كورسات'),
          ..._courses.map((c) => _CourseTile(c)),
          const SizedBox(height: 10),
        ],
        if (_subjects.isNotEmpty) ...[
          _SectionHeader(title: 'مواد'),
          ..._subjects.map((s) => _SubjectTile(s)),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 4,
        end: 4,
        top: 6,
        bottom: 6,
      ),
      child: Text(
        title,
        textAlign: TextAlign.right,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TeacherTile extends StatelessWidget {
  final Map<String, dynamic> t;
  const _TeacherTile(this.t);
  @override
  Widget build(BuildContext context) {
    final name = t['name']?.toString() ?? '';
    final address = t['address']?.toString() ?? '';
    final distanceVal = _toDouble(t['distance']);
    final distanceStr = distanceVal != null
        ? '${distanceVal.toStringAsFixed(1)} كم'
        : null;
    return ListTile(
      isThreeLine: address.isNotEmpty,
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(name, textAlign: TextAlign.right),
      subtitle: address.isNotEmpty
          ? Text(address, textAlign: TextAlign.right)
          : null,
      trailing: distanceStr != null ? Text(distanceStr) : null,
      onTap: () {
        final id = (t['id'] ?? '').toString();
        if (id.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherDetailsScreen(teacherId: id),
          ),
        );
      },
    );
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class _CourseTile extends StatelessWidget {
  final Map<String, dynamic> c;
  const _CourseTile(this.c);
  @override
  Widget build(BuildContext context) {
    final name = (c['courseName'] ?? c['course_name'] ?? '').toString();
    final teacher = (c['teacher']?['name'] ?? c['teacher_name'] ?? '')
        .toString();
    final distanceVal = _toDouble(c['distance']);
    final distanceStr = distanceVal != null
        ? '${distanceVal.toStringAsFixed(1)} كم'
        : null;
    final courseId = (c['id'] ?? '').toString();
    return ListTile(
      isThreeLine: teacher.isNotEmpty,
      leading: const CircleAvatar(child: Icon(Icons.menu_book_rounded)),
      title: Text(name, textAlign: TextAlign.right),
      subtitle: teacher.isNotEmpty
          ? Text(teacher, textAlign: TextAlign.right)
          : null,
      trailing: distanceStr != null ? Text(distanceStr) : null,
      onTap: () {
        if (courseId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourseDetailsScreen(courseId: courseId),
          ),
        );
      },
    );
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class _SubjectTile extends StatelessWidget {
  final Map<String, dynamic> s;
  const _SubjectTile(this.s);
  @override
  Widget build(BuildContext context) {
    final name = s['name']?.toString() ?? '';
    final desc = s['description']?.toString() ?? '';
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.category)),
      title: Text(name, textAlign: TextAlign.right),
      subtitle: desc.isNotEmpty ? Text(desc, textAlign: TextAlign.right) : null,
      onTap: () {
        // افتح شاشة البحث نفسها بإدخال اسم المادة لإظهار كورسات تخص المادة
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentUnifiedSearchScreen(initialQuery: name),
          ),
        );
      },
    );
  }
}
