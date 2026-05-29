// Teacher-application API client (Phase 6).
//
// Independent from `api_service.dart` because:
//   - This flow is unauthenticated (no Bearer token) — using the main Dio
//     would attach the wrong (or no) Authorization header.
//   - The upload endpoint takes an X-Upload-Token header, which we issue
//     from the create response and pass back here per file.
//
// Endpoints:
//   POST /api/teacher-applications                  → submit (no auth)
//   POST /api/teacher-applications/:id/files        → upload one file
//                                                     (X-Upload-Token)

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mulhimiq/core/config/app_config.dart';

class TeacherApplicationApiException implements Exception {
  TeacherApplicationApiException(this.message, {this.statusCode, this.code, this.fields});
  final String message;
  final int? statusCode;
  final String? code;
  final List<String>? fields;
  @override
  String toString() => 'TeacherApplicationApiException($statusCode $code): $message';
}

class TeacherApplicationApiService {
  TeacherApplicationApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 120), // file uploads
            headers: {
              'Accept': 'application/json',
            },
          ),
        );

  final Dio _dio;

  /// Submit a new application. Returns the created id + the upload token
  /// the caller will use to attach files in the same session.
  Future<TeacherApplicationSubmitResult> submit(
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _dio.post(
        '/teacher-applications',
        data: payload,
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = (res.data is Map ? (res.data['data'] as Map?) : null) ?? const {};
      return TeacherApplicationSubmitResult(
        applicationId: data['id'] as String? ?? '',
        applicationStatus: data['applicationStatus'] as String? ?? 'pending',
        uploadToken: data['uploadToken'] as String? ?? '',
        uploadTokenExpiresInSeconds:
            (data['uploadTokenExpiresInSeconds'] as num?)?.toInt() ?? 1800,
      );
    } on DioException catch (e) {
      throw _from(e);
    }
  }

  /// Phase 8 — verify the 6-digit OTP that was emailed after an
  /// `authProvider: 'email'` submission. On success the application moves
  /// from "awaiting verification" to "pending" and the super-admin alert
  /// fires server-side.
  Future<Map<String, dynamic>> verifyEmailOtp({
    required String applicationId,
    required String code,
  }) async {
    try {
      final res = await _dio.post(
        '/teacher-applications/$applicationId/verify-email',
        data: {'code': code},
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = (res.data is Map ? (res.data['data'] as Map?) : null) ?? const {};
      return Map<String, dynamic>.from(data);
    } on DioException catch (e) {
      throw _from(e);
    }
  }

  /// Phase 8 — re-issue a fresh OTP for an email-path application that
  /// hasn't been verified yet.
  Future<void> resendVerificationCode({
    required String applicationId,
  }) async {
    try {
      await _dio.post(
        '/teacher-applications/$applicationId/resend-verification',
        data: const <String, dynamic>{},
        options: Options(contentType: Headers.jsonContentType),
      );
    } on DioException catch (e) {
      throw _from(e);
    }
  }

  /// Phase 8.12 — request an OTP to retrieve the current status of an
  /// existing application. Always succeeds (anti-enumeration). The email is
  /// only sent server-side if a row matches.
  Future<void> requestStatusOtp({required String email}) async {
    try {
      await _dio.post(
        '/teacher-applications/status/request',
        data: {'email': email.trim()},
        options: Options(contentType: Headers.jsonContentType),
      );
    } on DioException catch (e) {
      throw _from(e);
    }
  }

  /// Phase 8.12 — verify the status-check OTP and return the application's
  /// current status. Throws on wrong/expired/locked code.
  Future<TeacherApplicationStatusResult> verifyStatusOtp({
    required String email,
    required String code,
  }) async {
    try {
      final res = await _dio.post(
        '/teacher-applications/status/verify',
        data: {'email': email.trim(), 'code': code},
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = (res.data is Map ? (res.data['data'] as Map?) : null) ?? const {};
      return TeacherApplicationStatusResult.fromMap(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw _from(e);
    }
  }

  /// Phase 8.12 — pull the public subjects catalog for the form dropdown.
  Future<List<String>> getSubjects() async {
    try {
      final res = await _dio.get('/public/subjects');
      final data = res.data is Map ? res.data['data'] : null;
      if (data is List) {
        return data.whereType<String>().toList(growable: false);
      }
      return const [];
    } on DioException catch (e) {
      throw _from(e);
    }
  }

  /// Phase 8.12 — pull the public teaching-stages catalog for the form
  /// dropdown. Same response shape as getSubjects().
  Future<List<String>> getTeachingStages() async {
    try {
      final res = await _dio.get('/public/teaching-stages');
      final data = res.data is Map ? res.data['data'] : null;
      if (data is List) {
        return data.whereType<String>().toList(growable: false);
      }
      return const [];
    } on DioException catch (e) {
      throw _from(e);
    }
  }

  /// Active grades from the super-admin-managed `grades` table. The
  /// teacher-application form picks one or more of these ids and submits
  /// them as `gradeIds` — they replace the old free-text teachingStage.
  Future<List<TeacherApplicationGrade>> getActiveGrades() async {
    try {
      final res = await _dio.get('/grades/all-student');
      final data = res.data is Map ? res.data['data'] : null;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((m) => TeacherApplicationGrade.fromMap(
                  Map<String, dynamic>.from(m),
                ))
            .where((g) => g.id.isNotEmpty && g.name.isNotEmpty)
            .toList(growable: false);
      }
      return const [];
    } on DioException catch (e) {
      throw _from(e);
    }
  }

  /// Upload one file. `onProgress` reports 0.0…1.0.
  /// `kind` must be one of: profile_image | certificate_image |
  /// national_id_image | optional_attachment | intro_video.
  Future<Map<String, dynamic>> uploadFile({
    required String applicationId,
    required String uploadToken,
    required String kind,
    required File file,
    required String declaredMimeType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'kind': kind,
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : 'upload',
          contentType: _parseMime(declaredMimeType),
        ),
      });

      final res = await _dio.post(
        '/teacher-applications/$applicationId/files',
        data: formData,
        options: Options(
          headers: {
            'X-Upload-Token': uploadToken,
          },
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );
      final data = (res.data is Map ? (res.data['data'] as Map?) : null) ?? const {};
      return Map<String, dynamic>.from(data);
    } on DioException catch (e) {
      throw _from(e);
    }
  }

  // --- internals -------------------------------------------------------------

  TeacherApplicationApiException _from(DioException e) {
    final body = e.response?.data;
    final status = e.response?.statusCode;
    if (body is Map) {
      final message = body['message']?.toString() ?? e.message ?? 'خطأ في الاتصال';
      String? code;
      List<String>? fields;
      final errs = body['errors'];
      if (errs is List && errs.isNotEmpty) {
        final first = errs.first;
        if (first is Map) {
          code = first['code']?.toString();
        }
        fields = errs
            .whereType<Map>()
            .map((m) => m['field']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return TeacherApplicationApiException(
        message,
        statusCode: status,
        code: code,
        fields: fields,
      );
    }
    return TeacherApplicationApiException(
      e.message ?? 'تعذر إتمام الطلب — تحقق من الاتصال',
      statusCode: status,
    );
  }

  // Parse "image/jpeg" / "application/pdf" into Dio's MediaType so the
  // multipart Content-Type header reaches the backend untouched. Falls back
  // to application/octet-stream — the server's magic-byte check has the
  // final word anyway.
  DioMediaType _parseMime(String mime) {
    final parts = mime.split('/');
    if (parts.length != 2) return DioMediaType('application', 'octet-stream');
    return DioMediaType(parts[0], parts[1]);
  }
}

/// One row from GET /grades/all-student — the public grade catalog.
class TeacherApplicationGrade {
  const TeacherApplicationGrade({required this.id, required this.name});
  final String id;
  final String name;

  factory TeacherApplicationGrade.fromMap(Map<String, dynamic> m) {
    return TeacherApplicationGrade(
      id: (m['id'] ?? m['_id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
    );
  }
}

class TeacherApplicationSubmitResult {
  const TeacherApplicationSubmitResult({
    required this.applicationId,
    required this.applicationStatus,
    required this.uploadToken,
    required this.uploadTokenExpiresInSeconds,
  });
  final String applicationId;
  final String applicationStatus;
  final String uploadToken;
  final int uploadTokenExpiresInSeconds;
}

/// Server response for POST /api/teacher-applications/status/verify.
/// Mirrors the shape returned by TeacherApplicationService.verifyStatusCheck.
class TeacherApplicationStatusResult {
  const TeacherApplicationStatusResult({
    required this.applicationId,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
    this.adminNotes,
    this.rejectedAt,
    this.needsMoreInfoAt,
  });

  final String applicationId;

  /// One of: 'pending' | 'approved' | 'rejected' | 'needs_more_info'.
  final String status;

  final String createdAt;
  final String? rejectionReason;
  final String? adminNotes;
  final String? rejectedAt;
  final String? needsMoreInfoAt;

  factory TeacherApplicationStatusResult.fromMap(Map<String, dynamic> m) {
    return TeacherApplicationStatusResult(
      applicationId: m['applicationId']?.toString() ?? '',
      status: m['status']?.toString() ?? 'pending',
      createdAt: m['createdAt']?.toString() ?? '',
      rejectionReason: m['rejectionReason']?.toString(),
      adminNotes: m['adminNotes']?.toString(),
      rejectedAt: m['rejectedAt']?.toString(),
      needsMoreInfoAt: m['needsMoreInfoAt']?.toString(),
    );
  }
}
