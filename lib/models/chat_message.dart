import 'dart:typed_data';

enum ChatMessageSender {
  user,
  bot,
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.imageBytes,
    this.imageMimeType,
    DateTime? timestamp,
    List<String>? sources,
    this.isLoading = false,
    this.isError = false,
  })  : timestamp = timestamp ?? DateTime.now(),
        sources = sources ?? <String>[];

  final String id;
  final ChatMessageSender sender;
  final String text;
  final Uint8List? imageBytes;
  final String? imageMimeType;
  final DateTime timestamp;
  final List<String> sources;
  final bool isLoading;
  final bool isError;

  bool get hasImage => imageBytes != null && imageBytes!.isNotEmpty;
  bool get isUser => sender == ChatMessageSender.user;
  bool get isBot => sender == ChatMessageSender.bot;

  ChatMessage copyWith({
    String? id,
    ChatMessageSender? sender,
    String? text,
    Uint8List? imageBytes,
    String? imageMimeType,
    DateTime? timestamp,
    List<String>? sources,
    bool? isLoading,
    bool? isError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      imageBytes: imageBytes ?? this.imageBytes,
      imageMimeType: imageMimeType ?? this.imageMimeType,
      timestamp: timestamp ?? this.timestamp,
      sources: sources ?? this.sources,
      isLoading: isLoading ?? this.isLoading,
      isError: isError ?? this.isError,
    );
  }
}
