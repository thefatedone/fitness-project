/// Single chat turn as surfaced by `GET /api/v1/ai/history` and used to
/// optimistic-render a turn the user just typed.
///
/// Single responsibility: carry one message + its metadata through the
/// provider → widget path. We don't model conversation ownership here
/// because the chat API keeps the conversation-id handling at the
/// transport layer for now (multi-conversation UI is planned but not
/// exposed).
class ChatMessageModel {
  /// Either `"user"` or `"assistant"`. Kept as a `String` rather than an
  /// enum so a future server-side role (e.g. `"system"`) doesn't break
  /// parsing; [isUser] is a convenience for the rendering layer.
  final String role;

  /// Decoded text of the turn. For assistant turns this is the final,
  /// post-stream full text (the server persists the *complete* reply
  /// after the SSE stream finishes, not the accumulated deltas).
  final String content;

  /// Server-assigned timestamp on chat-history rows; for optimistic
  /// local rows it's `DateTime.now()` at construction time. Floats back
  /// to the server (which is the source of truth) on the next history
  /// refetch.
  final DateTime createdAt;

  const ChatMessageModel({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  /// Optimistic local row — used for rendering the user message
  /// immediately while the streaming assistant reply is in flight, and
  /// for the placeholder bubble that lands before any server bytes
  /// arrive. Timestamps with `DateTime.now()`; the server doesn't see
  /// this row directly — it gets replaced on the next history refetch.
  factory ChatMessageModel.local({
    required String role,
    required String content,
  }) {
    return ChatMessageModel(
      role: role,
      content: content,
      createdAt: DateTime.now(),
    );
  }

  /// Parses the flat shape returned by `GET /ai/history`.
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convenience used by the chat bubble renderer — flips to `true` for
  /// the user side, `false` for the assistant (and any future role).
  bool get isUser => role == 'user';
}
