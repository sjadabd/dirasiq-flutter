import 'package:flutter/material.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/features/assignments/screens/assignment_details_screen.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  State<StudentAssignmentsScreen> createState() =>
      _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> {
  final _api = ApiService();
  final _scroll = ScrollController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetch();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool refresh = false}) async {
    try {
      if (refresh) {
        setState(() {
          _loading = true;
          _error = null;
          _page = 1;
          _items = [];
          _hasMore = true;
        });
      }
      if (!_hasMore && !refresh) return;

      final res = await _api.fetchStudentAssignments(page: _page, limit: 10);
      final list = List<Map<String, dynamic>>.from(
        (res['items'] ?? res['data'] ?? []) as List,
      );
      final pagination = Map<String, dynamic>.from(res['pagination'] ?? {});
      final total = (pagination['total'] ?? list.length) as int;

      setState(() {
        _items.addAll(list);
        _loading = false;
        _hasMore = _items.length < total;
        if (_hasMore) _page += 1;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      if (!_loading && _hasMore) _fetch();
    }
  }

  String _readableDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.background,
      appBar: const GlobalAppBar(title: 'الواجبات', centerTitle: true),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.red),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: () => _fetch(refresh: true),
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetch(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [Center(child: Text('لا توجد واجبات حالياً'))],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetch(refresh: true),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final a = _items[index];
          final title = (a['title'] ?? a['name'] ?? 'واجب').toString();
          final desc = (a['description'] ?? '').toString();
          final dueAt = (a['due_at'] ?? a['dueAt'])?.toString();

          // 🎨 لون البوردر حسب المود
          final borderColor = Theme.of(context).brightness == Brightness.dark
              ? Colors.white12
              : Colors.grey.shade300;

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primary.withOpacity(.1),
                child: Icon(Icons.assignment_outlined, color: scheme.primary),
              ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                  fontSize: 16,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    if (dueAt != null && dueAt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              color: scheme.primary,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'تسليم حتى: ${_readableDate(dueAt)}',
                              style: TextStyle(
                                color: scheme.primary.withOpacity(0.8),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Colors.grey,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssignmentDetailsScreen(
                      assignmentId: (a['id'] ?? a['_id']).toString(),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
