import 'dart:convert';
import 'dart:typed_data';

import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/encryption_service.dart';
import 'package:roost_app/models/user.dart';
import 'package:roost_app/models/message.dart';

/// Raw file size cap before encryption/base64 (~5MB). Kept in sync with
/// the backend's MAX_ATTACHMENT_BASE64_CHARS.
const int kMaxAttachmentBytes = 5 * 1024 * 1024;

class _CachedAttachment {
  _CachedAttachment({
    required this.bytes,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
  });

  final Uint8List bytes;
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;
}

class ChatService {
  /// Decrypted content/attachments, cached by message id. Chat history is
  /// re-fetched in full on every 5-second poll, but a given message's
  /// content never changes once sent -- without this cache, every poll
  /// would re-decrypt every message and re-download every attachment
  /// from R2 from scratch, which both wastes bandwidth and, for images,
  /// visibly "flickers" the UI as a fresh byte array gets re-decoded into
  /// a new image every few seconds even though nothing changed.
  static final Map<int, String> _decryptedContentCache = {};
  static final Map<int, _CachedAttachment> _decryptedAttachmentCache = {};

  static Future<List<User>> getActiveChats() async {
    final response = await ApiService.get('/api/chat/active');
    if (response is List) {
      return response.map((json) => User.fromJson(json)).toList();
    }
    return [];
  }

  /// Fetches a single user's current profile -- used to refresh a chat
  /// partner's online/last-seen status independently of message history.
  static Future<User?> getUserProfile(int userId) async {
    try {
      final response = await ApiService.get('/api/users/$userId');
      if (response is Map<String, dynamic>) {
        return User.fromJson(response);
      }
    } catch (_) {}
    return null;
  }

  /// Fetches the encrypted history with [userId] and decrypts every
  /// message (and any attachment) in place before returning -- callers
  /// always receive plaintext, never ciphertext. Reuses cached results
  /// for messages already decrypted on a previous poll.
  static Future<List<Message>> getChatHistory(int userId) async {
    final response = await ApiService.get('/api/chat/history/$userId');
    if (response is! List) return [];

    final messages = response.map((json) => Message.fromJson(json)).toList();
    for (final message in messages) {
      final cachedContent = _decryptedContentCache[message.id];
      if (cachedContent != null) {
        message.content = cachedContent;
      } else if (message.content.isNotEmpty || message.nonce != null) {
        message.content = await EncryptionService.decryptFrom(
          userId,
          message.content,
          message.nonce,
        );
        _decryptedContentCache[message.id] = message.content;
      }

      if (message.hasAttachment) {
        final cached = _decryptedAttachmentCache[message.id];
        if (cached != null) {
          message.attachmentBytes = cached.bytes;
          message.attachmentFileName = cached.fileName;
          message.attachmentMimeType = cached.mimeType;
          message.attachmentSizeBytes = cached.sizeBytes;
        } else {
          await _decryptAttachment(message, userId);
          if (message.attachmentBytes != null) {
            _decryptedAttachmentCache[message.id] = _CachedAttachment(
              bytes: message.attachmentBytes!,
              fileName: message.attachmentFileName,
              mimeType: message.attachmentMimeType,
              sizeBytes: message.attachmentSizeBytes,
            );
          }
        }
      }
    }
    return messages;
  }

  static Future<void> _decryptAttachment(Message message, int otherUserId) async {
    try {
      final metaJson = await EncryptionService.decryptFrom(
        otherUserId,
        message.attachmentMeta!,
        message.attachmentMetaNonce,
      );
      final meta = jsonDecode(metaJson) as Map<String, dynamic>;
      message.attachmentFileName = meta['name'] as String?;
      message.attachmentMimeType = meta['mimeType'] as String?;
      message.attachmentSizeBytes = (meta['size'] as num?)?.toInt();

      final bytes = await EncryptionService.decryptBytesFrom(
        otherUserId,
        message.attachmentData!,
        message.attachmentNonce!,
      );
      if (bytes != null) {
        message.attachmentBytes = Uint8List.fromList(bytes);
      }
    } catch (_) {
      // Leave attachment fields null; the UI shows a "couldn't load
      // attachment" state when attachmentBytes is null but hasAttachment
      // is true.
    }
  }

  /// Encrypts [content] for [recipientId] end-to-end, sends it, and
  /// returns a [Message] with the original plaintext already attached
  /// (no need to round-trip a decrypt for a message we just wrote).
  ///
  /// Throws [RecipientKeyUnavailableException] if the recipient hasn't
  /// enabled secure messaging yet.
  static Future<Message?> sendMessage(int recipientId, String content) async {
    final encrypted = await EncryptionService.encryptFor(recipientId, content);
    final response = await ApiService.post('/api/chat', {
      'recipientId': recipientId,
      'content': encrypted.content,
      'nonce': encrypted.nonce,
    });
    if (response == null) return null;

    final message = Message.fromJson(response);
    message.content = content;
    _decryptedContentCache[message.id] = content;
    return message;
  }

  /// Encrypts [fileBytes] (and an optional [caption]) for [recipientId],
  /// sends it as an attachment, and returns a Message with the plaintext
  /// caption and decrypted attachment fields already populated.
  ///
  /// Throws [RecipientKeyUnavailableException] if the recipient hasn't
  /// enabled secure messaging yet, or [ArgumentError] if the file exceeds
  /// [kMaxAttachmentBytes].
  static Future<Message?> sendAttachment(
    int recipientId, {
    required String fileName,
    required String mimeType,
    required Uint8List fileBytes,
    String? caption,
  }) async {
    if (fileBytes.length > kMaxAttachmentBytes) {
      throw ArgumentError('Attachment is too large (max ${kMaxAttachmentBytes ~/ (1024 * 1024)}MB)');
    }

    final payload = <String, dynamic>{'recipientId': recipientId};

    if (caption != null && caption.trim().isNotEmpty) {
      final encryptedCaption = await EncryptionService.encryptFor(recipientId, caption.trim());
      payload['content'] = encryptedCaption.content;
      payload['nonce'] = encryptedCaption.nonce;
    }

    final encryptedFile = await EncryptionService.encryptBytesFor(recipientId, fileBytes);
    payload['attachmentData'] = encryptedFile.content;
    payload['attachmentNonce'] = encryptedFile.nonce;

    final meta = jsonEncode({
      'name': fileName,
      'mimeType': mimeType,
      'size': fileBytes.length,
    });
    final encryptedMeta = await EncryptionService.encryptFor(recipientId, meta);
    payload['attachmentMeta'] = encryptedMeta.content;
    payload['attachmentMetaNonce'] = encryptedMeta.nonce;

    final response = await ApiService.post('/api/chat', payload);
    if (response == null) return null;

    final message = Message.fromJson(response);
    final resolvedCaption = caption?.trim() ?? '';
    message.content = resolvedCaption;
    message.attachmentBytes = fileBytes;
    message.attachmentFileName = fileName;
    message.attachmentMimeType = mimeType;
    message.attachmentSizeBytes = fileBytes.length;

    _decryptedContentCache[message.id] = resolvedCaption;
    _decryptedAttachmentCache[message.id] = _CachedAttachment(
      bytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
      sizeBytes: fileBytes.length,
    );
    return message;
  }

  static Future<void> markAsRead(int userId) async {
    try {
      await ApiService.post('/api/chat/mark-read/$userId', {});
    } catch (_) {}
  }
}
