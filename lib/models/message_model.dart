// lib/models/message_model.dart

enum MediaType {
  text,  // 🔥 AJOUT POUR COMPATIBILITÉ
  image,
  video,
  audio,
}

class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final String? mediaUrl;
  final MediaType? mediaType;
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;
  final User? sender;
  final User? receiver;
  
  // 🔥 CHAMPS POUR LA SUPPRESSION
  final bool isDeleted;
  final bool isEdited;
  final bool deletedForSender;
  final bool deletedForReceiver;
  final bool deletedForEveryone; // 🆕 NOUVEAU CHAMP

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.mediaUrl,
    this.mediaType,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
    this.sender,
    this.receiver,
    this.isDeleted = false,
    this.isEdited = false,
    this.deletedForSender = false,
    this.deletedForReceiver = false,
    this.deletedForEveryone = false, // 🆕 AJOUT DU PARAMÈTRE
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? 0,
      senderId: json['senderId'] ?? 0,
      receiverId: json['receiverId'] ?? 0,
      content: json['content'] ?? '',
      mediaUrl: json['mediaUrl'],
      mediaType: _parseMediaType(json['mediaType']),
      isRead: json['isRead'] ?? false,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
      receiver: json['receiver'] != null ? User.fromJson(json['receiver']) : null,
      isDeleted: json['isDeleted'] ?? false,
      isEdited: json['isEdited'] ?? false,
      deletedForSender: json['deletedForSender'] ?? false,
      deletedForReceiver: json['deletedForReceiver'] ?? false,
      deletedForEveryone: false, // 🆕 Toujours false depuis l'API (géré côté client)
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType?.name,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sender': sender?.toJson(),
      'receiver': receiver?.toJson(),
      'isDeleted': isDeleted,
      'isEdited': isEdited,
      'deletedForSender': deletedForSender,
      'deletedForReceiver': deletedForReceiver,
      'deletedForEveryone': deletedForEveryone, // 🆕 AJOUT
    };
  }

  static MediaType? _parseMediaType(String? type) {
    if (type == null) return MediaType.text;
    switch (type.toLowerCase()) {
      case 'text':
        return MediaType.text;
      case 'image':
        return MediaType.image;
      case 'audio':
        return MediaType.audio;
      case 'video':
        return MediaType.video;
      default:
        return MediaType.text;
    }
  }

  // 🔥 MÉTHODE COPYWITH COMPLÈTE ET CORRIGÉE
  Message copyWith({
    int? id,
    int? senderId,
    int? receiverId,
    String? content,
    String? mediaUrl,
    MediaType? mediaType,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? sender,
    User? receiver,
    bool? isDeleted,
    bool? isEdited,
    bool? deletedForSender,
    bool? deletedForReceiver,
    bool? deletedForEveryone, // 🆕 PARAMÈTRE AJOUTÉ
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
      isDeleted: isDeleted ?? this.isDeleted,
      isEdited: isEdited ?? this.isEdited,
      deletedForSender: deletedForSender ?? this.deletedForSender,
      deletedForReceiver: deletedForReceiver ?? this.deletedForReceiver,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone, // 🆕 AJOUT
    );
  }

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get isImage => mediaType == MediaType.image;
  bool get isVideo => mediaType == MediaType.video;
  bool get isAudio => mediaType == MediaType.audio;
  bool get isTextOnly => mediaType == MediaType.text || mediaType == null;

  @override
  String toString() {
    return 'Message(id: $id, senderId: $senderId, content: $content, isRead: $isRead, isDeleted: $isDeleted, deletedForEveryone: $deletedForEveryone)';
  }
}

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String? photo;
  final String role;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      photo: json['photo'],
      role: json['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'photo': photo,
      'role': role,
    };
  }

  String get fullName => '$firstName $lastName';

  @override
  String toString() {
    return 'User(id: $id, name: $fullName, role: $role)';
  }
}

class Partner extends User {
  final String? partnerName;
  final String? partnerPhoto;
  final String? partnerRole;

  Partner({
    required int id,
    required String firstName,
    required String lastName,
    String? photo,
    required String role,
    this.partnerName,
    this.partnerPhoto,
    this.partnerRole,
  }) : super(
          id: id,
          firstName: firstName,
          lastName: lastName,
          photo: photo,
          role: role,
        );

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      id: json['id'] ?? 0,
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      photo: json['photo'],
      role: json['role'] ?? 'user',
      partnerName: json['partnerName'],
      partnerPhoto: json['partnerPhoto'],
      partnerRole: json['partnerRole'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'partnerName': partnerName,
      'partnerPhoto': partnerPhoto,
      'partnerRole': partnerRole,
    });
    return json;
  }
}

class Conversation {
  final int partnerId;
  final String partnerName;
  final String? partnerPhoto;
  final String partnerRole;
  final String? lastMessage;
  final String? lastMediaUrl;
  final String? lastMediaType;
  final DateTime lastMessageTime;
  final int unreadCount;

  Conversation({
    required this.partnerId,
    required this.partnerName,
    this.partnerPhoto,
    required this.partnerRole,
    this.lastMessage,
    this.lastMediaUrl,
    this.lastMediaType,
    required this.lastMessageTime,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      partnerId: json['partnerId'] ?? 0,
      partnerName: json['partnerName'] ?? '',
      partnerPhoto: json['partnerPhoto'],
      partnerRole: json['partnerRole'] ?? 'user',
      lastMessage: json['lastMessage'],
      lastMediaUrl: json['lastMediaUrl'],
      lastMediaType: json['lastMediaType'],
      lastMessageTime: DateTime.parse(
        json['lastMessageTime'] ?? DateTime.now().toIso8601String(),
      ),
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'partnerId': partnerId,
      'partnerName': partnerName,
      'partnerPhoto': partnerPhoto,
      'partnerRole': partnerRole,
      'lastMessage': lastMessage,
      'lastMediaUrl': lastMediaUrl,
      'lastMediaType': lastMediaType,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }

  bool get hasUnreadMessages => unreadCount > 0;
  bool get hasLastMessage => lastMessage != null && lastMessage!.isNotEmpty;
  bool get hasLastMedia => lastMediaUrl != null && lastMediaUrl!.isNotEmpty;

  @override
  String toString() {
    return 'Conversation(partnerId: $partnerId, partnerName: $partnerName, unreadCount: $unreadCount)';
  }
}

class ConversationsResponse {
  final bool success;
  final List<Conversation> data;

  ConversationsResponse({
    required this.success,
    required this.data,
  });

  factory ConversationsResponse.fromJson(Map<String, dynamic> json) {
    return ConversationsResponse(
      success: json['success'] ?? false,
      data: (json['data'] as List<dynamic>? ?? [])
          .map((conversation) => Conversation.fromJson(conversation))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data.map((c) => c.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'ConversationsResponse(success: $success, conversations: ${data.length})';
  }
}

// 🔥 CLASSE POUR ENCAPSULER LES DONNÉES DE MESSAGES
class MessagesData {
  final Partner partner;
  final List<Message> messages;

  MessagesData({
    required this.partner,
    required this.messages,
  });

  factory MessagesData.fromJson(Map<String, dynamic> json) {
    return MessagesData(
      partner: Partner.fromJson(json['partner'] ?? {}),
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((message) => Message.fromJson(message))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'partner': partner.toJson(),
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}

// 🔥 CLASSE MESSAGESRESPONSE CORRIGÉE AVEC PROPRIÉTÉ DATA
class MessagesResponse {
  final bool success;
  final MessagesData data;

  MessagesResponse({
    required this.success,
    required this.data,
  });

  factory MessagesResponse.fromJson(Map<String, dynamic> json) {
    return MessagesResponse(
      success: json['success'] ?? false,
      data: MessagesData.fromJson(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data.toJson(),
    };
  }

  // 🔥 PROPRIÉTÉS DE COMPATIBILITÉ POUR L'ANCIEN CODE
  Partner get partner => data.partner;
  List<Message> get messages => data.messages;

  @override
  String toString() {
    return 'MessagesResponse(success: $success, partner: ${data.partner.fullName}, messages: ${data.messages.length})';
  }
}

class SendMessageResponse {
  final bool success;
  final String message;
  final Message data;

  SendMessageResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory SendMessageResponse.fromJson(Map<String, dynamic> json) {
    return SendMessageResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: Message.fromJson(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data.toJson(),
    };
  }

  @override
  String toString() {
    return 'SendMessageResponse(success: $success, message: $message)';
  }
}

class UnreadCountResponse {
  final bool success;
  final int unreadCount;

  UnreadCountResponse({
    required this.success,
    required this.unreadCount,
  });

  factory UnreadCountResponse.fromJson(Map<String, dynamic> json) {
    return UnreadCountResponse(
      success: json['success'] ?? false,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'unreadCount': unreadCount,
    };
  }

  @override
  String toString() {
    return 'UnreadCountResponse(success: $success, unreadCount: $unreadCount)';
  }
}

class SearchMessagesResponse {
  final bool success;
  final List<Message> data;

  SearchMessagesResponse({
    required this.success,
    required this.data,
  });

  factory SearchMessagesResponse.fromJson(Map<String, dynamic> json) {
    return SearchMessagesResponse(
      success: json['success'] ?? false,
      data: (json['data'] as List<dynamic>? ?? [])
          .map((message) => Message.fromJson(message))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data.map((m) => m.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'SearchMessagesResponse(success: $success, messages: ${data.length})';
  }
}

class MarkAsReadResponse {
  final bool success;
  final String message;
  final Message? data;
  final int? count;

  MarkAsReadResponse({
    required this.success,
    required this.message,
    this.data,
    this.count,
  });

  factory MarkAsReadResponse.fromJson(Map<String, dynamic> json) {
    return MarkAsReadResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? Message.fromJson(json['data']) : null,
      count: json['count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data?.toJson(),
      'count': count,
    };
  }

  @override
  String toString() {
    return 'MarkAsReadResponse(success: $success, count: $count)';
  }
}

class DeleteMessageResponse {
  final bool success;
  final String message;

  DeleteMessageResponse({
    required this.success,
    required this.message,
  });

  factory DeleteMessageResponse.fromJson(Map<String, dynamic> json) {
    return DeleteMessageResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
    };
  }

  @override
  String toString() {
    return 'DeleteMessageResponse(success: $success, message: $message)';
  }
}

// Exception personnalisée pour les erreurs de messages
class MessageException implements Exception {
  final String message;
  final String? code;

  MessageException(this.message, {this.code});

  @override
  String toString() {
    return 'MessageException: $message${code != null ? ' (Code: $code)' : ''}';
  }
}