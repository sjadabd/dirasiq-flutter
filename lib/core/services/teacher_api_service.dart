import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'api_service.dart';

/// Teacher-side API client.
///
/// Reuses the shared [ApiService]'s Dio instance so we inherit the
/// `Authorization: Bearer ...` interceptor and the 401 → /login auto-logout.
///
/// IMPORTANT — business rules baked into this client:
///   • Teachers cannot register from mobile.
///   • Subscription / Wayl payment is dashboard-only.
class TeacherApiService {
  TeacherApiService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  Dio get _dio => _apiService.dio;

  // ===========================================================================
  // Dashboard / Reference
  // ===========================================================================

  Future<Map<String, dynamic>> fetchDashboardOverview() async {
    final res = await _dio.get('/teacher/dashboard');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// Today's remaining sessions for the dashboard activity feed. Backed by
  /// the existing GET /api/teacher/dashboard/upcoming-today endpoint, which
  /// returns `data: [ { sessionId, courseName, startTime, endTime, state, ... } ]`.
  Future<Map<String, dynamic>> fetchTodayUpcomingSessions() async {
    final res = await _dio.get('/teacher/dashboard/upcoming-today');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// Monthly performance aggregates (attendance / homework / collection %).
  Future<Map<String, dynamic>> fetchDashboardPerformance() async {
    final res = await _dio.get('/teacher/dashboard/performance');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// Recent teacher activity feed (bookings, deposits, invoices).
  Future<Map<String, dynamic>> fetchDashboardActivity({int limit = 10}) async {
    final res = await _dio.get(
      '/teacher/dashboard/activity',
      queryParameters: {'limit': limit},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchAcademicYears() async {
    final res = await _dio.get('/teacher/academic-years');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchCourseNames() async {
    final res = await _dio.get('/teacher/courses/names');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// Unpaid invoices + pending reservation deposits, grouped by course.
  Future<Map<String, dynamic>> fetchCourseFinancialAlerts() async {
    final res = await _dio.get('/teacher/courses/financial-alerts');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// Settlement debt for a single course (invoices + deposits).
  Future<Map<String, dynamic>> fetchCourseFinancialAlert(String courseId) async {
    final res = await _dio.get('/teacher/courses/$courseId/financial-alert');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchAllGrades() async {
    final res = await _dio.get('/grades/all');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  // Teacher self-service: read + replace the grade set the teacher
  // declared they teach for the currently-active academic year. Backed by
  // /api/teacher/my-grades (GET to hydrate the profile screen's chips,
  // PUT for a replace-set sync). The PUT body must carry the FULL desired
  // gradeIds list — the server soft-deletes anything that fell out of
  // the set and upserts the rest in one transaction.
  Future<Map<String, dynamic>> fetchMyTeacherGrades() async {
    final res = await _dio.get('/teacher/my-grades');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> syncMyTeacherGrades(
    List<String> gradeIds,
  ) async {
    final res = await _dio.put(
      '/teacher/my-grades',
      data: {'gradeIds': gradeIds},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchWallet() async {
    final res = await _dio.get('/teacher/wallet');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchPaymentFeatures() {
    return _apiService.fetchPaymentFeatures();
  }

  /// Create a Wayl payment link to top up the wallet by [amount] IQD.
  /// Returns the envelope; `data` carries `{ url, referenceId, amount }`.
  Future<Map<String, dynamic>> createWalletTopup(int amount) async {
    final res = await _dio.post(
      '/teacher/wallet/topup',
      data: {'amount': amount},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchWalletTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get(
      '/teacher/wallet/transactions',
      queryParameters: {'page': page, 'limit': limit},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// Request a payout. The super-admin reviews + executes it.
  Future<Map<String, dynamic>> createWalletWithdrawal({
    required int amount,
    String? notes,
    String? destination,
  }) async {
    final res = await _dio.post(
      '/teacher/wallet/withdrawals',
      data: {
        'amount': amount,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (destination != null && destination.trim().isNotEmpty)
          'destination': destination.trim(),
      },
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// The teacher's withdrawal history (pending / approved / paid / rejected).
  Future<Map<String, dynamic>> fetchWalletWithdrawals({
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '/teacher/wallet/withdrawals',
      queryParameters: {'page': page, 'limit': limit},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// Fetch the transfer-receipt image bytes for one of the teacher's own
  /// withdrawals. The file is private on the server and only reachable with the
  /// auth token (the Dio interceptor attaches it).
  Future<Uint8List> fetchWithdrawalReceipt(String id) async {
    final res = await _dio.get(
      '/teacher/wallet/withdrawals/$id/receipt',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(List<int>.from(res.data as List));
  }

  // ===========================================================================
  // Reservation payments (course deposits)
  // ===========================================================================

  Future<Map<String, dynamic>> fetchReservationPayments({
    required String studyYear,
    int page = 1,
    int limit = 200,
  }) async {
    final res = await _dio.get(
      '/teacher/payments/reservations',
      queryParameters: {'studyYear': studyYear, 'page': page, 'limit': limit},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> markReservationPaid(String bookingId) async {
    final res = await _dio.patch(
      '/teacher/payments/reservations/$bookingId/mark-paid',
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  // ===========================================================================
  // Student invoices (full installments + payments)
  // ===========================================================================

  Future<Map<String, dynamic>> fetchInvoices({
    required String studyYear,
    String? status,
    String? paymentMode,
    String? search,
    String? courseId,
    bool? deleted,
    int page = 1,
    int limit = 50,
  }) async {
    final qp = <String, dynamic>{
      'studyYear': studyYear,
      'page': page,
      'limit': limit,
    };
    if (status != null && status.isNotEmpty) qp['status'] = status;
    if (paymentMode != null && paymentMode.isNotEmpty)
      qp['paymentMode'] = paymentMode;
    if (search != null && search.isNotEmpty) qp['search'] = search;
    if (courseId != null && courseId.isNotEmpty) qp['courseId'] = courseId;
    if (deleted == true) qp['deleted'] = 'true';
    final res = await _dio.get('/teacher/invoices', queryParameters: qp);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchInvoicesSummary({
    required String studyYear,
    String? status,
  }) async {
    final qp = <String, dynamic>{'studyYear': studyYear};
    if (status != null && status.isNotEmpty) qp['status'] = status;
    final res = await _dio.get(
      '/teacher/invoices/summary',
      queryParameters: qp,
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchInvoiceFull(String invoiceId) async {
    final res = await _dio.get('/teacher/invoices/$invoiceId');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// Create a student invoice. Wire-shape mirrors the dashboard's
  /// create-invoice.vue payload — `studentId`, `courseId`, `studyYear`,
  /// `paymentMode` ('cash' | 'installments'), `amountDue`, optional
  /// `discountAmount`/`invoiceDate`/`dueDate`/`notes`, and for installments the
  /// auto-split trio `installmentsCount` / `installmentIntervalDays` /
  /// `installmentFirstDueDate`. The backend (invoiceCreateSchema) validates
  /// every field and, on success, fires a best-effort push notification to the
  /// student ("فاتورة جديدة").
  Future<Map<String, dynamic>> createInvoice(
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post('/teacher/invoices', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> addInvoicePayment(
    String invoiceId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post(
      '/teacher/invoices/$invoiceId/payments',
      data: payload,
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// Full invoice edit — replaces amount/discount/dates/notes/mode and
  /// regenerates the installment plan, then the backend notifies the student.
  /// Same payload shape as [createInvoice] minus student/course/studyYear
  /// (those are immutable). Only allowed before any payment was collected.
  Future<Map<String, dynamic>> updateInvoiceFull(
    String invoiceId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.put('/teacher/invoices/$invoiceId', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> setInvoiceDiscount(
    String invoiceId,
    num discountAmount,
  ) async {
    final res = await _dio.patch(
      '/teacher/invoices/$invoiceId/discount',
      data: {'discountAmount': discountAmount},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> updateInvoiceMeta(
    String invoiceId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch(
      '/teacher/invoices/$invoiceId/meta',
      data: payload,
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> deleteInvoice(String invoiceId) async {
    final res = await _dio.delete('/teacher/invoices/$invoiceId');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  // ===========================================================================
  // Bookings
  // ===========================================================================

  Future<Map<String, dynamic>> fetchBookings({
    required String studyYear,
    String? status,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final qp = <String, dynamic>{
      'studyYear': studyYear,
      'page': page,
      'limit': limit,
    };
    if (status != null && status.isNotEmpty) qp['status'] = status;
    if (search != null && search.isNotEmpty) qp['search'] = search;
    final res = await _dio.get('/teacher/bookings', queryParameters: qp);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchBookingStats(String studyYear) async {
    final res = await _dio.get(
      '/teacher/bookings/stats/summary',
      queryParameters: {'studyYear': studyYear},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> preApproveBooking(
    String id, {
    String? teacherResponse,
  }) async {
    final res = await _dio.patch(
      '/teacher/bookings/$id/pre-approve',
      data: {if (teacherResponse != null) 'teacherResponse': teacherResponse},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> confirmBooking(
    String id, {
    String? teacherResponse,
    bool reservationPaid = true,
  }) async {
    final res = await _dio.patch(
      '/teacher/bookings/$id/confirm',
      data: {
        if (teacherResponse != null) 'teacherResponse': teacherResponse,
        'reservationPaid': reservationPaid,
      },
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> rejectBooking(
    String id, {
    required String rejectionReason,
    String? teacherResponse,
  }) async {
    final res = await _dio.patch(
      '/teacher/bookings/$id/reject',
      data: {
        'rejectionReason': rejectionReason,
        if (teacherResponse != null) 'teacherResponse': teacherResponse,
      },
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> reactivateBooking(
    String id, {
    String? teacherResponse,
  }) async {
    final res = await _dio.patch(
      '/teacher/bookings/$id/reactivate',
      data: {if (teacherResponse != null) 'teacherResponse': teacherResponse},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> deleteBooking(String id) async {
    final res = await _dio.delete('/teacher/bookings/$id');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchSubscriptionCapacity() async {
    final res = await _dio.get(
      '/teacher/bookings/subscription/remaining-students',
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  // ===========================================================================
  // Notifications (teacher's outgoing pushes)
  // ===========================================================================

  Future<Map<String, dynamic>> fetchNotifications({
    int page = 1,
    int limit = 50,
    String? q,
    String? subType,
    String? courseId,
  }) async {
    final qp = <String, dynamic>{'page': page, 'limit': limit};
    if (q != null && q.isNotEmpty) qp['q'] = q;
    if (subType != null && subType.isNotEmpty) qp['subType'] = subType;
    if (courseId != null && courseId.isNotEmpty) qp['courseId'] = courseId;
    final res = await _dio.get('/teacher/notifications', queryParameters: qp);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> createNotification(
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post('/teacher/notifications', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> deleteNotification(String id) async {
    final res = await _dio.delete('/teacher/notifications/$id');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchTeacherStudents() async {
    final res = await _dio.get('/teacher/students');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchStudentsByCourse(String courseId) async {
    final res = await _dio.get('/teacher/students/by-course/$courseId');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  // ===========================================================================
  // Assignments
  // ===========================================================================

  Future<Map<String, dynamic>> createAssignment(
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post('/teacher/assignments', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchAssignments({
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '/teacher/assignments',
      queryParameters: {'page': page, 'limit': limit},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchAssignmentOverview(String id) async {
    final res = await _dio.get('/teacher/assignments/$id/overview');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> updateAssignment(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch('/teacher/assignments/$id', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> deleteAssignment(String id) async {
    final res = await _dio.delete('/teacher/assignments/$id');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> gradeAssignment(
    String assignmentId,
    String studentId, {
    required num score,
    String? feedback,
  }) async {
    final res = await _dio.put(
      '/teacher/assignments/$assignmentId/grade/$studentId',
      data: {
        'score': score,
        if (feedback != null && feedback.trim().isNotEmpty)
          'feedback': feedback.trim(),
      },
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> markAssignmentReceived(
    String assignmentId,
    String studentId,
    bool received,
  ) async {
    final res = await _dio.put(
      '/teacher/assignments/$assignmentId/received/$studentId',
      data: {'received': received},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  // ===========================================================================
  // Exams
  // ===========================================================================

  Future<Map<String, dynamic>> createExam(Map<String, dynamic> payload) async {
    final res = await _dio.post('/teacher/exams', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchExams({
    int page = 1,
    int limit = 100,
    String? type,
  }) async {
    final qp = <String, dynamic>{'page': page, 'limit': limit};
    if (type != null && type.isNotEmpty) qp['type'] = type;
    final res = await _dio.get('/teacher/exams', queryParameters: qp);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchExamById(String id) async {
    final res = await _dio.get('/teacher/exams/$id');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchExamStudents(
    String id, {
    String? sessionId,
  }) async {
    final qp = <String, dynamic>{};
    if (sessionId != null && sessionId.isNotEmpty) qp['sessionId'] = sessionId;
    final res = await _dio.get(
      '/teacher/exams/$id/students',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> gradeExam(
    String examId,
    String studentId,
    num score,
  ) async {
    final res = await _dio.put(
      '/teacher/exams/$examId/grade/$studentId',
      data: {'score': score},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> updateExam(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch('/teacher/exams/$id', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> deleteExam(String id) async {
    final res = await _dio.delete('/teacher/exams/$id');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  // ===========================================================================
  // Student evaluations
  // ===========================================================================

  Future<Map<String, dynamic>> fetchEvaluationStudents(
    String courseId,
    String date,
  ) async {
    final res = await _dio.get(
      '/teacher/evaluations/students-with-eval',
      queryParameters: {'courseId': courseId, 'date': date, 'limit': 100},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> bulkUpsertEvaluations(
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post(
      '/teacher/evaluations/bulk-upsert',
      data: payload,
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchEvaluationsByStudent(
    String studentId, {
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '/teacher/evaluations',
      queryParameters: {'studentId': studentId, 'page': page, 'limit': limit},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  // ===========================================================================
  // Sessions + attendance
  // ===========================================================================

  Future<Map<String, dynamic>> fetchSessions({
    int page = 1,
    int limit = 100,
    int? weekday,
    String? courseId,
    String? search,
  }) async {
    final qp = <String, dynamic>{'page': page, 'limit': limit};
    if (weekday != null) qp['weekday'] = weekday;
    if (courseId != null && courseId.isNotEmpty) qp['courseId'] = courseId;
    if (search != null && search.isNotEmpty) qp['search'] = search;
    final res = await _dio.get('/teacher/sessions', queryParameters: qp);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchSessionAttendees(String sessionId) async {
    final res = await _dio.get('/teacher/sessions/$sessionId/attendees');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchSessionAttendanceByDate(
    String sessionId,
    String dateISO,
  ) async {
    final res = await _dio.get(
      '/teacher/sessions/$sessionId/attendance',
      queryParameters: {'date': dateISO},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> bulkSetSessionAttendance(
    String sessionId,
    String dateISO,
    List<Map<String, dynamic>> items,
  ) async {
    final res = await _dio.post(
      '/teacher/sessions/$sessionId/attendance',
      data: {'date': dateISO, 'items': items},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> createSession(
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post('/teacher/sessions', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> deleteSession(String sessionId) async {
    final res = await _dio.delete('/teacher/sessions/$sessionId');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  // ===========================================================================
  // Courses + subjects
  // ===========================================================================

  Future<Map<String, dynamic>> fetchCourses({
    int page = 1,
    int limit = 50,
    String? studyYear,
    String? gradeId,
    String? subjectId,
    String? search,
    bool? deleted,
  }) async {
    final qp = <String, dynamic>{'page': page, 'limit': limit};
    if (studyYear != null) qp['study_year'] = studyYear;
    if (gradeId != null) qp['grade_id'] = gradeId;
    if (subjectId != null) qp['subject_id'] = subjectId;
    if (search != null && search.isNotEmpty) qp['search'] = search;
    if (deleted == true || deleted == false) qp['deleted'] = deleted;
    final res = await _dio.get('/teacher/courses', queryParameters: qp);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> deleteCourse(String id) async {
    final res = await _dio.delete('/teacher/courses/$id');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> setCourseRegistrationOpen(
    String id, {
    required bool isOpen,
  }) async {
    final res = await _dio.patch(
      '/teacher/courses/$id/registration',
      data: {'registration_open': isOpen},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// Create a regular (non-video) teacher course. Wire-shape mirrors the
  /// dashboard's AddCourse.vue payload — snake_case keys, study_year as
  /// `YYYY-YYYY`, course_images as an array of data-URL base64 strings.
  /// The backend Zod schema (`courseCreateSchema`) enforces every required
  /// field; an empty body returns a 400 with `errors[].field` per missing
  /// key, so the caller doesn't need to defensively pre-validate.
  Future<Map<String, dynamic>> createCourse(
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post('/teacher/courses', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> restoreCourse(String id) async {
    final res = await _dio.patch('/teacher/courses/$id/restore');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchSubjects({
    int page = 1,
    int limit = 50,
    String? search,
    bool? isDeleted,
  }) async {
    final qp = <String, dynamic>{'page': page, 'limit': limit};
    if (search != null && search.isNotEmpty) qp['search'] = search;
    if (isDeleted == true || isDeleted == false) qp['is_deleted'] = isDeleted;
    final res = await _dio.get('/teacher/subjects', queryParameters: qp);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> createSubject(
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post('/teacher/subjects', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> updateSubject(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.put('/teacher/subjects/$id', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> deleteSubject(String id) async {
    final res = await _dio.delete('/teacher/subjects/$id');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> restoreSubject(String id) async {
    final res = await _dio.patch('/teacher/subjects/$id/restore');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  // ===========================================================================
  // Expenses
  // ===========================================================================

  Future<Map<String, dynamic>> fetchExpenses({
    int page = 1,
    int limit = 50,
    String? studyYear,
    String? from,
    String? to,
    String? category,
    String? paymentMethod,
    String? search,
    bool? deleted,
  }) async {
    final qp = <String, dynamic>{'page': page, 'limit': limit};
    if (studyYear != null && studyYear.isNotEmpty) qp['studyYear'] = studyYear;
    if (from != null && from.isNotEmpty) qp['from'] = from;
    if (to != null && to.isNotEmpty) qp['to'] = to;
    if (category != null && category.isNotEmpty) qp['category'] = category;
    if (paymentMethod != null && paymentMethod.isNotEmpty)
      qp['paymentMethod'] = paymentMethod;
    if (search != null && search.isNotEmpty) qp['search'] = search;
    if (deleted == true) qp['deleted'] = 'true';
    final res = await _dio.get('/teacher/expenses', queryParameters: qp);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> createExpense(
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post('/teacher/expenses', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> updateExpense(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch('/teacher/expenses/$id', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> deleteExpense(String id) async {
    final res = await _dio.delete('/teacher/expenses/$id');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> restoreExpense(String id) async {
    final res = await _dio.patch('/teacher/expenses/$id/restore');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  // ===========================================================================
  // Financial report
  // ===========================================================================

  Future<Map<String, dynamic>> fetchFinancialReport({
    String? studyYear,
    String? from,
    String? to,
  }) async {
    final qp = <String, dynamic>{};
    if (studyYear != null && studyYear.isNotEmpty) qp['studyYear'] = studyYear;
    if (from != null && from.isNotEmpty) qp['from'] = from;
    if (to != null && to.isNotEmpty) qp['to'] = to;
    final res = await _dio.get(
      '/teacher/reports/financial',
      queryParameters: qp,
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  // ===========================================================================
  // Phase 10.1.B — Video Courses (teacher-owned VOD)
  // ===========================================================================

  Future<Map<String, dynamic>> fetchMyVideoCourses({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final qp = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null && status.isNotEmpty && status != 'all')
      qp['status'] = status;
    final res = await _dio.get('/teacher/video-courses', queryParameters: qp);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchMyVideoCourse(String id) async {
    final res = await _dio.get('/teacher/video-courses/$id');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchMyVideoCourseLessons(String id) async {
    final res = await _dio.get('/teacher/video-courses/$id/lessons');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> createVideoCourse(
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post('/teacher/video-courses', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> updateVideoCourse(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch('/teacher/video-courses/$id', data: payload);
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<void> deleteVideoCourse(String id) async {
    await _dio.delete('/teacher/video-courses/$id');
  }

  /// Upload a cover image (multipart). Cap: 5 MB; backend re-validates via
  /// magic-byte detection.
  Future<Map<String, dynamic>> uploadVideoCourseCoverImage(
    String id,
    String filePath, {
    ProgressCallback? onSendProgress,
  }) async {
    final fd = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post(
      '/teacher/video-courses/$id/cover-image',
      data: fd,
      onSendProgress: onSendProgress,
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// Create a lesson on a course. Backend mints a Bunny videoId + returns
  /// the upload contract { url, method, headers } that the client uses
  /// for the direct-PUT call (see [putToBunny]).
  Future<Map<String, dynamic>> createVideoLesson({
    required String courseId,
    required String title,
    String? description,
    int? displayOrder,
  }) async {
    final body = <String, dynamic>{'title': title};
    if (description != null && description.isNotEmpty)
      body['description'] = description;
    if (displayOrder != null) body['displayOrder'] = displayOrder;
    final res = await _dio.post(
      '/teacher/video-courses/$courseId/lessons',
      data: body,
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> updateVideoLesson({
    required String courseId,
    required String lessonId,
    String? title,
    String? description,
    int? displayOrder,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (displayOrder != null) body['displayOrder'] = displayOrder;
    final res = await _dio.patch(
      '/teacher/video-courses/$courseId/lessons/$lessonId',
      data: body,
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<void> deleteVideoLesson({
    required String courseId,
    required String lessonId,
  }) async {
    await _dio.delete('/teacher/video-courses/$courseId/lessons/$lessonId');
  }

  Future<Map<String, dynamic>> reorderVideoLessons({
    required String courseId,
    required List<String> lessonIds,
  }) async {
    final res = await _dio.post(
      '/teacher/video-courses/$courseId/lessons/reorder',
      data: {'lessonIds': lessonIds},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> syncVideoLesson({
    required String courseId,
    required String lessonId,
  }) async {
    final res = await _dio.post(
      '/teacher/video-courses/$courseId/lessons/$lessonId/sync',
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// Stream a video file directly to Bunny Stream using the contract the
  /// backend returned from [createVideoLesson]. Reports 0..100 via the
  /// optional [onProgress] callback.
  ///
  /// The dio instance's `baseUrl` is bypassed because the contract URL is
  /// already absolute (https://video.bunnycdn.com/...).
  Future<void> putToBunny({
    required Map<String, dynamic> uploadContract,
    required String filePath,
    void Function(int progress0to100)? onProgress,
  }) async {
    final url = uploadContract['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw Exception('upload contract is missing url');
    }
    final headers = <String, dynamic>{};
    final hdrs = uploadContract['headers'];
    if (hdrs is Map) {
      for (final entry in hdrs.entries) {
        headers[entry.key.toString()] = entry.value;
      }
    }
    // Use a one-shot Dio so the global Authorization interceptor doesn't
    // attach our JWT to Bunny (which would 401 us).
    final raw = Dio(
      BaseOptions(
        headers: headers,
        receiveTimeout: const Duration(minutes: 60),
        sendTimeout: const Duration(minutes: 60),
        followRedirects: true,
      ),
    );
    final file = await MultipartFile.fromFile(filePath);
    // Bunny expects the raw bytes — NOT multipart. Use a FileStream.
    final stream = (await MultipartFile.fromFile(filePath)).finalize();
    final length = file.length;
    await raw.put(
      url,
      data: stream,
      options: Options(
        headers: {...headers, Headers.contentLengthHeader: length},
      ),
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(((sent / total) * 100).clamp(0, 99).toInt());
        }
      },
    );
    onProgress?.call(100);
  }

  // ---- Teacher intro video (Bunny + admin review) ---------------------------

  Future<Map<String, dynamic>> getIntroVideo() async {
    final res = await _dio.get('/teacher/profile/intro-video');
    return Map<String, dynamic>.from(res.data?['data'] ?? res.data ?? {});
  }

  Future<Map<String, dynamic>> startBunnyIntroVideoUpload() async {
    final res = await _dio.post('/teacher/profile/intro-video/bunny');
    return Map<String, dynamic>.from(res.data?['data'] ?? res.data ?? {});
  }

  Future<Map<String, dynamic>> syncIntroVideo() async {
    final res = await _dio.post('/teacher/profile/intro-video/sync');
    return Map<String, dynamic>.from(res.data?['data'] ?? res.data ?? {});
  }

  Future<Map<String, dynamic>> confirmIntroVideoUpload() async {
    final res = await _dio.post('/teacher/profile/intro-video/confirm-upload');
    return Map<String, dynamic>.from(res.data?['data'] ?? res.data ?? {});
  }

  // ---- Teacher catalog dropdowns (subjects + grades) ----------------------
  // These already exist as side methods elsewhere in the app, but we expose
  // narrow wrappers here so the video-courses UI doesn't reach into other
  // services. Both endpoints are auth-gated to the calling teacher.

  Future<List<Map<String, dynamic>>> fetchMySubjectsCatalog() async {
    final res = await _dio.get('/teacher/subjects/all');
    return _extractList(res.data, const ['subjects', 'items', 'data']);
  }

  Future<List<Map<String, dynamic>>> fetchMyGradesCatalog() async {
    final res = await _dio.get('/grades/my-grades');
    return _extractList(res.data, const ['grades', 'items', 'data']);
  }

  // ===========================================================================
  // Teacher advertisements
  // ===========================================================================

  Future<Map<String, dynamic>> fetchAdvertisements({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final res = await _dio.get(
      '/teacher/advertisements',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchAdvertisementStatistics() async {
    final res = await _dio.get('/teacher/advertisements/statistics');
    return Map<String, dynamic>.from(res.data?['data'] ?? res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchAdvertisementSettings() async {
    final res = await _dio.get('/teacher/advertisements/settings');
    return Map<String, dynamic>.from(res.data?['data'] ?? res.data ?? {});
  }

  Future<Map<String, dynamic>> fetchAdvertisementById(String id) async {
    final res = await _dio.get('/teacher/advertisements/$id');
    return Map<String, dynamic>.from(res.data?['data'] ?? res.data ?? {});
  }

  Future<Map<String, dynamic>> createAdvertisement(
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.post('/teacher/advertisements', data: body);
    return Map<String, dynamic>.from(res.data?['data'] ?? res.data ?? {});
  }

  Future<Map<String, dynamic>> updateAdvertisement(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.patch('/teacher/advertisements/$id', data: body);
    return Map<String, dynamic>.from(res.data?['data'] ?? res.data ?? {});
  }

  Future<void> deleteAdvertisement(String id) async {
    await _dio.delete('/teacher/advertisements/$id');
  }

  Future<Map<String, dynamic>> submitAdvertisement(String id) async {
    final res = await _dio.post('/teacher/advertisements/$id/submit');
    return Map<String, dynamic>.from(res.data?['data'] ?? res.data ?? {});
  }

  Future<Map<String, dynamic>> cancelAdvertisement(String id) async {
    final res = await _dio.post('/teacher/advertisements/$id/cancel');
    return Map<String, dynamic>.from(res.data?['data'] ?? res.data ?? {});
  }

  Future<List<Map<String, dynamic>>> fetchTeacherPlatformNews({
    int limit = 8,
  }) async {
    final res = await _dio.get(
      '/teacher/news',
      queryParameters: {'page': 1, 'limit': limit},
    );
    final raw = res.data?['data'];
    final List list = raw is List
        ? raw
        : (raw is Map && raw['data'] is List ? raw['data'] as List : const []);
    return list
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  Future<Map<String, dynamic>> fetchTeacherPlatformNewsDetail(String id) async {
    final res = await _dio.get('/teacher/news/$id');
    return Map<String, dynamic>.from(res.data?['data'] ?? res.data ?? {});
  }

  /// Defensive list-extractor for backend responses that don't share a single
  /// envelope. Tries:
  ///   1. `value` is a List directly.
  ///   2. `value.data` is a List.
  ///   3. `value.data[key]` is a List for each key in [keys].
  ///   4. `value[key]` is a List for each key in [keys].
  /// Returns an empty list (never null) so callers can iterate safely.
  List<Map<String, dynamic>> _extractList(dynamic value, List<String> keys) {
    List<Map<String, dynamic>> normalize(dynamic v) {
      if (v is List) {
        return v
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
      return const [];
    }

    if (value is List) return normalize(value);
    if (value is Map) {
      final m = Map<String, dynamic>.from(value);
      final data = m['data'];
      if (data is List) return normalize(data);
      if (data is Map) {
        final dataMap = Map<String, dynamic>.from(data);
        for (final k in keys) {
          if (dataMap[k] is List) return normalize(dataMap[k]);
        }
      }
      for (final k in keys) {
        if (m[k] is List) return normalize(m[k]);
      }
    }
    return const [];
  }
}
