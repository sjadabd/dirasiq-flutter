/// Single source of truth for teacher route names.
///
/// Used by:
///   • main.dart — to register each screen as a named GetPage
///   • TeacherDrawer — to navigate via Get.offNamed (no stacking) and to
///     highlight the active item via Get.currentRoute.
class TeacherRoutes {
  TeacherRoutes._();

  static const home               = '/teacher/home';
  static const reservationPayments = '/teacher/reservation-payments';
  static const invoices           = '/teacher/invoices';
  static const expenses           = '/teacher/expenses';
  static const reports            = '/teacher/reports';
  static const wallet             = '/teacher/wallet';
  static const subjects           = '/teacher/subjects';
  static const courses            = '/teacher/courses';
  static const videoCourses       = '/teacher/video-courses';
  static const sessions           = '/teacher/sessions';
  static const bookings           = '/teacher/bookings';
  static const notifications      = '/teacher/notifications';
  static const profile            = '/teacher/profile';

  /// Stable list of all named routes (used to detect if a current route is
  /// one of "our" pages — for the drawer highlight).
  static const all = <String>[
    home, reservationPayments, invoices, expenses, reports, wallet,
    subjects, courses, videoCourses, sessions, bookings, notifications, profile,
  ];
}
