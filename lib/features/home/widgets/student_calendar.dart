import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:mulhimiq/core/services/api_service.dart';

class StudentCalendar extends StatefulWidget {
  /// Bump this from the parent (e.g. on pull-to-refresh) to force the
  /// calendar to refetch its weekly schedule. Same pattern as NewsCarousel.
  final int refreshToken;
  const StudentCalendar({super.key, this.refreshToken = 0});

  @override
  State<StudentCalendar> createState() => _StudentCalendarState();
}

class _StudentCalendarState extends State<StudentCalendar> {
  Map<String, List<Map<String, dynamic>>> scheduleByDay = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  @override
  void didUpdateWidget(covariant StudentCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadSchedule();
    }
  }

  /// تحميل البيانات من API
  Future<void> _loadSchedule() async {
    try {
      final data = await ApiService().fetchStudentWeeklySchedule();
      if (mounted) {
        setState(() {
          scheduleByDay = Map<String, List<Map<String, dynamic>>>.from(
            data['scheduleByDay'],
          );
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// جلب المحاضرات لليوم المحدد
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final weekday = day.weekday; // Monday=1 ... Sunday=7
    return scheduleByDay["$weekday"] ?? [];
  }

  /// عرض تفاصيل المحاضرات في نافذة سفلية
  void _showDayDetails(DateTime day) {
    final events = _getEventsForDay(day);
    if (events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("لا توجد محاضرات في هذا اليوم"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "محاضرات يوم ${DateFormat.EEEE('ar').format(day)}",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...events.map(
                (e) => ListTile(
                  leading: Icon(Icons.menu_book_rounded, color: cs.primary),
                  title: Text(
                    e['course']?['name'] ?? "دورة",
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    "المعلم: ${e['teacher']?['name']} \n${e['startTime']} - ${e['endTime']}",
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.saturday,
          locale: 'ar',
          rowHeight: 26, // 👈 تقليل ارتفاع الخلية
          daysOfWeekHeight: 18,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            _showDayDetails(selectedDay);
          },
          eventLoader: _getEventsForDay,

          // 🎨 الخلايا + البوردر
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              return Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.4),
                    width: 0.6,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              );
            },
            outsideBuilder: (context, day, focusedDay) {
              return Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.3),
                    width: 0.6,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              );
            },

            // ✅ اليوم الحالي
            todayBuilder: (context, day, focusedDay) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                  color: isDark
                      ? Colors
                            .white24 // خلفية فاتحة في الليلي
                      : Theme.of(context).primaryColor.withValues(
                          alpha: 0.15,
                        ), // فاتح في النهاري
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors
                              .white // نص أبيض في الليلي
                        : Theme.of(
                            context,
                          ).primaryColor, // نص Primary في النهاري
                  ),
                ),
              );
            },

            // ✅ اليوم المحدد
            selectedBuilder: (context, day, focusedDay) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                  color: isDark
                      ? Theme.of(context)
                            .colorScheme
                            .secondary // لون بارز في الليلي
                      : Theme.of(context).primaryColor, // Primary في النهاري
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.black : Colors.white, // يبان واضح
                  ),
                ),
              );
            },

            // ✅ النقاط (markers)
            markerBuilder: (context, day, events) {
              if (events.isEmpty) {
                return const SizedBox.shrink();
              }
              final isSelected = isSameDay(_selectedDay, day);
              final isToday = isSameDay(DateTime.now(), day);

              final isDark = Theme.of(context).brightness == Brightness.dark;
              Color baseColor = isDark ? Colors.white70 : Colors.black54;

              if (isSelected) {
                baseColor = Theme.of(context).colorScheme.secondary;
              }
              if (isToday) {
                baseColor = Theme.of(context).primaryColor;
              }

              return Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      events.length.clamp(0, 3),
                      (index) => Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: baseColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 🎨 عناوين الأيام
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            weekendStyle: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.error,
            ),
          ),

          // 🎨 الهيدر
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            headerPadding: const EdgeInsets.symmetric(vertical: 2),
          ),
        ),
      ),
    );
  }
}
