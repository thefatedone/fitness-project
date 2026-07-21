import 'package:flutter/foundation.dart';

import '../../auth/providers/auth_api.dart';
import '../models/chat_message_model.dart';
import 'chat_api.dart';

/// `ChangeNotifier` that owns the state of the AI chat screen — the
/// message list, in-flight flags, last error, and the identifier of the
/// conversation we're currently talking to.
///
/// Single responsibility: provide a UI-friendly, observable view over
/// [ChatApi] with optimistic UI updates so the user's bubble appears
/// instantly and the assistant's bubble grows in real time as streamed
/// text arrives. No transport / parsing lives here — that's [ChatApi].
class ChatProvider extends ChangeNotifier {
  /// All chat turns currently displayed, in chronological order. Mutated
  /// in place as the stream progresses; the [ChangeNotifier] contract
  /// means the UI rebuilds on every `notifyListeners()` regardless of
  /// identity change, so we don't need to allocate a fresh list per
  /// chunk.
  List<ChatMessageModel> messages = <ChatMessageModel>[];

  /// `true` while the initial `GET /history` is in flight.
  bool isLoadingHistory = false;

  /// `true` while a `/chat` response is streaming (or attempting to).
  /// Drives the bubble's pulsing animation and the disabled-state of the
  /// input field.
  bool isSending = false;

  /// Last user-facing error from any chat action. Cleared at the start of
  /// every operation.
  String? errorMessage;

  /// Identifier of the conversation we're currently inside. `null` means
  /// "use the server's default thread". The backend already understands
  /// and persists this — the UI just hasn't been wired to multi-
  /// conversation yet, but threading it through the provider now means
  /// we won't have to re-plumb the API layer when that UI lands.
  String? conversationId;

  final ChatApi _chatApi = ChatApi();

  // ---- public actions --------------------------------------------------------

  /// `GET /ai/history` (or `/ai/history/{id}` if [conversationId] is set)
  /// → reassigns [messages]. Safe to call on screen mount and on
  /// pull-to-refresh alike.
  Future<void> loadHistory() async {
    isLoadingHistory = true;
    errorMessage = null;
    notifyListeners();

    try {
      messages = await _chatApi.getHistory(conversationId: conversationId);
    } on ApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Optimistically appends the user's text, drops in an empty
  /// assistant bubble, and grows that bubble per SSE chunk as the
  /// server streams the reply in.
  ///
  /// On stream failure: drops the placeholder entirely if it never
  /// received any text (so the UI doesn't carry a permanently-empty
  /// bubble); keeps whatever partial text has arrived if the failure
  /// happened mid-stream.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    // Empty strings (all-whitespace taps) are silently dropped — saves
    // a round-trip and matches what every chat UI does.
    if (trimmed.isEmpty) return;

    // Optimistic user bubble — appears immediately, before any network.
    messages.add(ChatMessageModel.local(role: 'user', content: trimmed));

    // Empty assistant bubble — this row will grow as streamed chunks
    // arrive. Note its index now; we're going to mutate the slot in
    // place for the rest of this method instead of reallocating the
    // whole list per chunk.
    messages.add(ChatMessageModel.local(role: 'assistant', content: ''));
    final assistantIndex = messages.length - 1;

    isSending = true;
    errorMessage = null;
    notifyListeners();

    try {
      await for (final chunk
          in _chatApi.sendMessageStream(trimmed, conversationId: conversationId)) {
        // Replace the assistant bubble's row in place — `messages` keeps
        // the same identity, so watchers don't churn reference equality.
        // The `createdAt` is intentionally re-stamped each chunk; the
        // assistant bubble is a live placeholder until the stream
        // completes, and the server-assigned timestamp is irrelevant
        // for in-progress UI.
        final current = messages[assistantIndex];
        messages[assistantIndex] = ChatMessageModel(
          role: current.role,
          content: current.content + chunk,
          createdAt: DateTime.now(),
        );
        // One notify per chunk — yes, that's more `notifyListeners()`
        // calls than batching would, but it's the whole point of
        // streaming: the user should see the reply appear
        // character-by-character.
        notifyListeners();
      }
      isSending = false;
      notifyListeners();
    } catch (e) {
      // The catch covers BOTH an ApiException from the initial POST
      // (handled by fromDioError with a Russian message) and any
      // other exception that might escape the streaming generator
      // (defensive — the API layer is supposed to suppress these, but
      // we don't want a thrown exception to leave `isSending` stuck on).
      errorMessage = e is ApiException
          ? e.message
          : 'Что-то пошло не так. Попробуй ещё раз.';
      isSending = false;
      _cleanupFailedPlaceholder(assistantIndex);
      notifyListeners();
    }
  }

  /// `DELETE /ai/history` → on success, empties [messages]. Returns
  /// `true` on success so callers (e.g. a "Clear history" button) can
  /// show a confirmation toast.
  Future<bool> clearHistory() async {
    try {
      await _chatApi.deleteHistory();
      messages = <ChatMessageModel>[];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Clears [errorMessage] — use after the UI has shown an error banner
  /// so it doesn't linger into the next state.
  void clearError() {
    if (errorMessage != null) {
      errorMessage = null;
      notifyListeners();
    }
  }

  // ---- private helpers --------------------------------------------------------

  /// Removes the assistant placeholder bubble if it ended up empty
  /// (stream failed before any text arrived). A non-empty placeholder
  /// is left in place — partial text is better than nothing.
  void _cleanupFailedPlaceholder(int index) {
    if (index >= messages.length) return;
    if (messages[index].content.isEmpty) {
      messages.removeAt(index);
    }
  }
}
