// Multi-select student picker — two ways to add members:
//
//   1. "الطلاب" tab — paginated, server-side search across the teacher's
//      full confirmed-bookings roster. Tick individuals.
//   2. "الكورسات" tab — list of the teacher's courses; tapping one bulk-adds
//      every confirmed student of that course (deduped against the current
//      selection and the `excludeUserIds` set).
//
// Selection state is shared across tabs: a tuple `(id, name)` Map so the
// confirm action can pop both the ids (for `addMembers` POST) and the names
// (for the create-group preview chips) without a second round-trip.
//
// Usage:
//   final picked = await StudentPickerSheet.show(
//     context,
//     excludeUserIds: existingMemberIds,
//     title: 'إضافة طلاب',
//   );
//   if (picked != null && picked.isNotEmpty) {
//     final ids   = picked.map((p) => p.id).toList();
//     final names = picked.map((p) => p.name).toList();
//   }

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../services/chat_api_service.dart';

class StudentPickerSheet {
  /// Opens the picker as a draggable bottom sheet. Returns the selected
  /// `(id, name)` tuples, or `null` if the teacher dismisses without
  /// confirming.
  static Future<List<({String id, String name})>?> show(
    BuildContext context, {
    required String title,
    Set<String> excludeUserIds = const {},
  }) {
    return showModalBottomSheet<List<({String id, String name})>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _StudentPickerSheetBody(
        title: title,
        excludeUserIds: excludeUserIds,
      ),
    );
  }
}

class _StudentPickerSheetBody extends StatefulWidget {
  const _StudentPickerSheetBody({
    required this.title,
    required this.excludeUserIds,
  });
  final String title;
  final Set<String> excludeUserIds;

  @override
  State<_StudentPickerSheetBody> createState() =>
      _StudentPickerSheetBodyState();
}

class _StudentPickerSheetBodyState extends State<_StudentPickerSheetBody>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 50;

  late final TabController _tabs;

  /// Shared across both tabs. Key=userId, value=name.
  final Map<String, String> _selected = <String, String>{};

  // ── Students tab state ─────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _studentsScroll = ScrollController();
  Timer? _searchDebounce;
  String _currentQuery = '';
  int _studentsPage = 1;
  int _studentsTotal = 0;
  int _studentsTotalPages = 0;
  bool _studentsLoading = false;
  bool _studentsLoadingMore = false;
  String? _studentsError;
  final List<({String id, String name})> _students = [];

  // ── Courses tab state ──────────────────────────────────────────────────
  bool _coursesLoading = false;
  String? _coursesError;
  List<({String id, String name})> _courses = const [];
  String? _addingCourseId; // course currently being bulk-added

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _studentsScroll.addListener(_onStudentsScroll);
    _loadStudents(reset: true);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _studentsScroll.removeListener(_onStudentsScroll);
    _studentsScroll.dispose();
    super.dispose();
  }

  void _onStudentsScroll() {
    if (!_studentsScroll.hasClients) return;
    final pos = _studentsScroll.position;
    if (pos.pixels < pos.maxScrollExtent - 220) return;
    if (_studentsLoadingMore || _studentsLoading) return;
    if (_studentsPage >= _studentsTotalPages) return;
    _loadStudents(reset: false);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final q = value.trim();
      if (q == _currentQuery) return;
      _currentQuery = q;
      _loadStudents(reset: true);
    });
  }

  Future<void> _loadStudents({required bool reset}) async {
    if (reset) {
      setState(() {
        _studentsLoading = true;
        _studentsError = null;
        _studentsPage = 1;
      });
    } else {
      setState(() => _studentsLoadingMore = true);
    }
    try {
      final result = await ChatApiService.instance.fetchTeacherStudentsPaged(
        page: reset ? 1 : _studentsPage + 1,
        limit: _pageSize,
        search: _currentQuery.isEmpty ? null : _currentQuery,
      );
      final filtered = result.rows
          .where((r) => !widget.excludeUserIds.contains(r.id))
          .toList(growable: false);
      setState(() {
        if (reset) {
          _students
            ..clear()
            ..addAll(filtered);
        } else {
          // Server may return duplicates across boundaries — dedupe.
          final existing = _students.map((r) => r.id).toSet();
          _students.addAll(filtered.where((r) => !existing.contains(r.id)));
        }
        _studentsPage = result.page;
        _studentsTotal = result.total;
        _studentsTotalPages = result.totalPages;
      });
    } catch (e, st) {
      developer.log(
        'fetchTeacherStudentsPaged failed',
        name: 'chat.picker',
        error: e,
        stackTrace: st,
      );
      setState(() => _studentsError = _humanise(e));
    } finally {
      if (mounted) {
        setState(() {
          _studentsLoading = false;
          _studentsLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadCourses() async {
    if (_courses.isNotEmpty || _coursesLoading) return;
    setState(() {
      _coursesLoading = true;
      _coursesError = null;
    });
    try {
      final list = await ChatApiService.instance.fetchTeacherCourseNames();
      _courses = list;
    } catch (e, st) {
      developer.log(
        'fetchTeacherCourseNames failed',
        name: 'chat.picker',
        error: e,
        stackTrace: st,
      );
      _coursesError = _humanise(e);
    } finally {
      if (mounted) setState(() => _coursesLoading = false);
    }
  }

  Future<void> _addAllFromCourse(({String id, String name}) course) async {
    setState(() => _addingCourseId = course.id);
    try {
      final roster =
          await ChatApiService.instance.fetchStudentsByCourse(course.id);
      final eligible = roster
          .where((s) => !widget.excludeUserIds.contains(s.id))
          .toList(growable: false);
      final added = <String>[];
      for (final s in eligible) {
        if (!_selected.containsKey(s.id)) {
          _selected[s.id] = s.name;
          added.add(s.id);
        }
      }
      if (!mounted) return;
      setState(() {});
      final msg = added.isEmpty
          ? (eligible.isEmpty
              ? 'لا يوجد طلاب مؤكَّدون في هذا الكورس'
              : 'كل طلاب الكورس مضافون مسبقاً')
          : 'تمت إضافة ${added.length} من طلاب «${course.name}»';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    } catch (e, st) {
      developer.log(
        'fetchStudentsByCourse failed',
        name: 'chat.picker',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_humanise(e))),
      );
    } finally {
      if (mounted) setState(() => _addingCourseId = null);
    }
  }

  String _humanise(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'تحقّق من الإنترنت ثم حاول مجدّداً.';
    }
    if (s.contains('UNAUTHORIZED') || s.contains('401')) {
      return 'انتهت جلستك. أعد تسجيل الدخول.';
    }
    final detail = s.length > 120 ? '${s.substring(0, 120)}…' : s;
    return 'تعذّر تحميل البيانات.\n$detail';
  }

  void _toggleStudent(({String id, String name}) row) {
    setState(() {
      if (_selected.containsKey(row.id)) {
        _selected.remove(row.id);
      } else {
        _selected[row.id] = row.name;
      }
    });
  }

  void _clearSelection() {
    setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, _) {
        return Column(
          children: [
            const SizedBox(height: 6),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  if (_selected.isNotEmpty) ...[
                    GestureDetector(
                      onTap: _clearSelection,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_selected.length} مختار',
                              style: TextStyle(
                                color: cs.onPrimaryContainer,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.close,
                                size: 14, color: cs.onPrimaryContainer),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: cs.primary,
              indicatorColor: cs.primary,
              onTap: (i) {
                if (i == 1) _loadCourses();
              },
              tabs: const [
                Tab(text: 'الطلاب', icon: Icon(Icons.people_alt_outlined, size: 18)),
                Tab(text: 'الكورسات', icon: Icon(Icons.menu_book_outlined, size: 18)),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildStudentsTab(cs),
                  _buildCoursesTab(cs),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                12 + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () {
                              final picked = _selected.entries
                                  .map((e) => (id: e.key, name: e.value))
                                  .toList(growable: false);
                              Navigator.of(context).pop(picked);
                            },
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        _selected.isEmpty
                            ? 'حدّد عناصر'
                            : 'تأكيد (${_selected.length})',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Students tab ─────────────────────────────────────────────────────────
  Widget _buildStudentsTab(ColorScheme cs) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'ابحث بالاسم أو رقم الهاتف…',
              isDense: true,
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _studentsLoading && _students.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _studentsError != null && _students.isEmpty
                  ? _ErrorView(
                      message: _studentsError!,
                      onRetry: () => _loadStudents(reset: true),
                    )
                  : _students.isEmpty
                      ? _EmptyRoster(
                          hasQuery: _currentQuery.isNotEmpty,
                          hasExcluded: widget.excludeUserIds.isNotEmpty,
                        )
                      : ListView.separated(
                          controller: _studentsScroll,
                          itemCount: _students.length + 1,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: cs.outlineVariant.withValues(alpha: 0.4),
                          ),
                          itemBuilder: (_, i) {
                            if (i == _students.length) {
                              return _buildStudentsFooter(cs);
                            }
                            final s = _students[i];
                            final checked = _selected.containsKey(s.id);
                            return CheckboxListTile(
                              value: checked,
                              onChanged: (_) => _toggleStudent(s),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              secondary: CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    cs.primary.withValues(alpha: 0.12),
                                child: Text(
                                  s.name.isNotEmpty
                                      ? s.name.characters.first
                                      : '?',
                                  style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildStudentsFooter(ColorScheme cs) {
    if (_studentsLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_studentsPage >= _studentsTotalPages && _studentsTotal > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'عرض ${_students.length} من $_studentsTotal',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }

  // ── Courses tab ──────────────────────────────────────────────────────────
  Widget _buildCoursesTab(ColorScheme cs) {
    if (_coursesLoading && _courses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_coursesError != null && _courses.isEmpty) {
      return _ErrorView(message: _coursesError!, onRetry: _loadCourses);
    }
    if (_courses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text('لا يوجد كورسات مضافة بعد.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'اختر كورساً لإضافة جميع طلابه المؤكَّدين دفعةً واحدة.',
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _courses.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
            itemBuilder: (_, i) {
              final c = _courses[i];
              final busy = _addingCourseId == c.id;
              return ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.secondary.withValues(alpha: 0.12),
                  child: Icon(Icons.menu_book_outlined,
                      color: cs.secondary, size: 18),
                ),
                title: Text(
                  c.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                trailing: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: _addingCourseId != null
                            ? null
                            : () => _addAllFromCourse(c),
                        icon: const Icon(Icons.group_add_outlined, size: 16),
                        label: const Text('إضافة الكل'),
                      ),
                onTap: _addingCourseId != null || busy
                    ? null
                    : () => _addAllFromCourse(c),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 40),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster({required this.hasQuery, required this.hasExcluded});
  final bool hasQuery;
  final bool hasExcluded;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5), size: 48),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? 'لا توجد نتائج مطابقة.'
                  : hasExcluded
                      ? 'جميع طلابك مضافون بالفعل في هذه المجموعة.'
                      : 'لا يوجد طلاب مؤكَّدون في حجوزاتك بعد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
