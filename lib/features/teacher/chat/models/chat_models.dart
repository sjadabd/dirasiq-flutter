// Chat domain models mirrored from the chat service envelope.
//
// Every model has a `fromJson` for parsing REST responses + socket payloads,
// and a `toJson` for places where we send a model back to the server (rare
// — most send paths build payloads inline).
//
// Naming notes:
//   - The backend uses `camelCase` for chat responses (we own both sides).
//   - `Conversation.peer` is non-null for private conversations and null for
//     groups; the controller branches off that.

import 'package:flutter/foundation.dart';

enum ConversationType { private, group }

enum ConversationMode { open, announceOnly }

enum MemberRole { owner, admin, member }

enum MessageKind { text, image, file, system }

/// Local-only sentinel for a message that's pending the server `message:ack`.
/// Set on optimistic bubbles before the ack lands.
enum MessageStatus { sending, sent, failed }

// ---------------------------------------------------------------------------
//  User-summary embedded inside conversation rows + message rows
// ---------------------------------------------------------------------------

@immutable
class ChatUserSummary {
  const ChatUserSummary({
    required this.id,
    required this.name,
    required this.userType,
    this.profileImagePath,
  });

  final String id;
  final String name;
  final String? profileImagePath;

  /// `"super_admin" | "teacher" | "student"`.
  final String userType;

  factory ChatUserSummary.fromJson(Map<String, dynamic> json) {
    return ChatUserSummary(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '').toString(),
      profileImagePath: json['profileImagePath']?.toString(),
      userType: (json['userType'] ?? 'student').toString(),
    );
  }
}

// ---------------------------------------------------------------------------
//  Attachments
// ---------------------------------------------------------------------------

@immutable
class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.url,
    required this.mime,
    required this.sizeBytes,
    this.originalName,
    this.thumbnailUrl,
  });

  final String id;
  final String url;
  final String mime;
  final int sizeBytes;
  final String? originalName;
  final String? thumbnailUrl;

  bool get isImage => mime.startsWith('image/');
  bool get isVideo => mime.startsWith('video/');
  bool get isPdf => mime == 'application/pdf';

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id']?.toString() ?? '',
      url: (json['url'] ?? '').toString(),
      mime: (json['mime'] ?? '').toString(),
      sizeBytes: (json['sizeBytes'] is num)
          ? (json['sizeBytes'] as num).toInt()
          : int.tryParse('${json['sizeBytes']}') ?? 0,
      originalName: json['originalName']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
    );
  }
}

// ---------------------------------------------------------------------------
//  Messages
// ---------------------------------------------------------------------------

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.kind,
    required this.createdAt,
    required this.attachments,
    this.sender,
    this.replyToMessageId,
    this.isPinned = false,
    this.editedAt,
    this.deletedAt,
    this.status = MessageStatus.sent,
    this.clientMessageId,
  });

  /// Server id once persisted; for optimistic messages this is the same as
  /// `clientMessageId` until `message:ack` arrives.
  String id;
  String conversationId;
  String senderId;
  String? body;
  MessageKind kind;
  DateTime createdAt;
  List<ChatAttachment> attachments;
  ChatUserSummary? sender;
  String? replyToMessageId;
  bool isPinned;
  DateTime? editedAt;
  DateTime? deletedAt;

  /// Local-only — `sending` until ack, `failed` on error, `sent` afterwards.
  MessageStatus status;

  /// Local-only correlation id for optimistic sends.
  String? clientMessageId;

  bool get isDeleted => deletedAt != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId: (json['conversationId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      body: json['body']?.toString(),
      kind: _parseKind(json['kind']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      attachments: (json['attachments'] is List)
          ? (json['attachments'] as List)
              .whereType<Map>()
              .map((m) => ChatAttachment.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : <ChatAttachment>[],
      sender: json['sender'] is Map
          ? ChatUserSummary.fromJson(Map<String, dynamic>.from(json['sender']))
          : null,
      replyToMessageId: json['replyToMessageId']?.toString(),
      isPinned: json['isPinned'] == true,
      editedAt: _parseDate(json['editedAt']),
      deletedAt: _parseDate(json['deletedAt']),
      status: MessageStatus.sent,
    );
  }

  static MessageKind _parseKind(dynamic v) {
    switch (v?.toString()) {
      case 'image':
        return MessageKind.image;
      case 'file':
        return MessageKind.file;
      case 'system':
        return MessageKind.system;
      default:
        return MessageKind.text;
    }
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }
}

// ---------------------------------------------------------------------------
//  Conversation
// ---------------------------------------------------------------------------

class ChatConversation {
  ChatConversation({
    required this.id,
    required this.type,
    required this.name,
    required this.imagePath,
    required this.description,
    required this.mode,
    required this.isArchived,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.myRole,
    required this.notificationsMuted,
    required this.peer,
    required this.lastMessage,
    required this.createdAt,
  });

  String id;
  ConversationType type;
  String? name;
  String? imagePath;
  String? description;
  ConversationMode mode;
  bool isArchived;
  DateTime? lastMessageAt;
  int unreadCount;
  MemberRole myRole;
  bool notificationsMuted;
  ChatUserSummary? peer;
  ChatMessage? lastMessage;
  DateTime createdAt;

  bool get isGroup => type == ConversationType.group;
  bool get canManage => myRole == MemberRole.owner || myRole == MemberRole.admin;
  bool get isOwner => myRole == MemberRole.owner;

  /// Display name — peer name for privates, group name otherwise.
  String displayName() {
    if (type == ConversationType.private) {
      return peer?.name ?? 'محادثة';
    }
    return name ?? 'مجموعة';
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id']?.toString() ?? '',
      type: (json['type']?.toString() == 'group')
          ? ConversationType.group
          : ConversationType.private,
      name: json['name']?.toString(),
      imagePath: json['imagePath']?.toString(),
      description: json['description']?.toString(),
      mode: (json['mode']?.toString() == 'announce_only')
          ? ConversationMode.announceOnly
          : ConversationMode.open,
      isArchived: json['isArchived'] == true,
      lastMessageAt: _parseDate(json['lastMessageAt']),
      unreadCount: (json['unreadCount'] is num)
          ? (json['unreadCount'] as num).toInt()
          : int.tryParse('${json['unreadCount']}') ?? 0,
      myRole: _parseRole(json['myRole']),
      notificationsMuted: json['notificationsMuted'] == true,
      peer: json['peer'] is Map
          ? ChatUserSummary.fromJson(Map<String, dynamic>.from(json['peer']))
          : null,
      lastMessage: json['lastMessage'] is Map
          ? ChatMessage.fromJson(Map<String, dynamic>.from(json['lastMessage']))
          : null,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  static MemberRole _parseRole(dynamic v) {
    switch (v?.toString()) {
      case 'owner':
        return MemberRole.owner;
      case 'admin':
        return MemberRole.admin;
      default:
        return MemberRole.member;
    }
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }
}

// ---------------------------------------------------------------------------
//  Group member (with profile)
// ---------------------------------------------------------------------------

class ChatMember {
  ChatMember({
    required this.userId,
    required this.role,
    required this.notificationsMuted,
    required this.isMutedByAdminUntil,
    required this.profile,
    required this.joinedAt,
    required this.leftAt,
  });

  final String userId;
  MemberRole role;
  bool notificationsMuted;
  DateTime? isMutedByAdminUntil;
  ChatUserSummary? profile;
  DateTime joinedAt;
  DateTime? leftAt;

  bool get isActive => leftAt == null;

  bool get isMutedNow {
    final until = isMutedByAdminUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    return ChatMember(
      userId: (json['userId'] ?? '').toString(),
      role: ChatConversation._parseRole(json['role']),
      notificationsMuted: json['notificationsMuted'] == true,
      isMutedByAdminUntil: _parseDate(json['isMutedByAdminUntil']),
      profile: json['profile'] is Map
          ? ChatUserSummary.fromJson(Map<String, dynamic>.from(json['profile']))
          : null,
      joinedAt: _parseDate(json['joinedAt']) ?? DateTime.now(),
      leftAt: _parseDate(json['leftAt']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }
}
