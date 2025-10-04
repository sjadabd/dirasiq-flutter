import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:dirasiq/core/services/api_service.dart';

class StudentCalendar extends StatefulWidget {
  const StudentCalendar({super.key});

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
                  leading: Icon(
                    Icons.menu_book_rounded,
                    color: cs.primary,
                  ),
                  title: Text(
                    e['course']?['name'] ?? "دورة",
                    style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "المعلم: ${e['teacher']?['name']} \n${e['startTime']} - ${e['endTime']}",
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
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

    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(6.0), // 👈 تقليل الهوامش
        child: TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.saturday,
          locale: 'ar',
          rowHeight: 28,
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
          calendarStyle: CalendarStyle(
            defaultTextStyle: TextStyle(fontSize: 10, color: cs.onSurface), // حجم ثابت
            weekendTextStyle: TextStyle(fontSize: 10, color: cs.error),
            todayDecoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.75), // لون الدائرة عند التحديد
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(
              fontSize: 10, // 👈 نفس الحجم، ما يكبر
              fontWeight: FontWeight.bold,
              color: cs.onPrimary, // الرقم داخل الدائرة باللون المناسب
            ),
            markersMaxCount: 1,
            markerDecoration: BoxDecoration(
              color: cs.secondary,
              shape: BoxShape.circle,
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
            weekendStyle: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: cs.error,
            ),
          ),
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
            leftChevronIcon: Icon(Icons.chevron_left, size: 18, color: cs.onSurface),
            rightChevronIcon: Icon(Icons.chevron_right, size: 18, color: cs.onSurface),
          ),
        ),
      ),
    );
  }
}
