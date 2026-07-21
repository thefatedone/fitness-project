import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_api.dart';
import '../models/chat_message_model.dart';

/// HTTP client for the AI nutrition chat endpoints.
///
/// Single responsibility: speak the three `/api/v1/ai/*` routes the app
/// needs — history (default thread or a specific conversation), history
/// wipe, and the streaming `/ai/chat` SSE endpoint. Higher layers
/// (providers, screens) handle persistence, retry, and UI state.
///
/// Forward-compatibility note: the backend already understands a
/// `conversation_id` on chat requests and exposes a per-conversation
/// `/ai/history/{conversation_id}` filter; the UI just hasn't been
/// wired to multi-conversation yet. `conversationId` is threaded
/// through both the GET and the POST paths here so a future
/// conversation-switcher UI can pass an id without touching this layer
/// at all.
class ChatApi {
  /// The shared HTTP client — reuses [apiClient] so the auth-token
  /// interceptor is in effect, and our connection-level Dio settings
  /// (timeouts, baseUrl) match the rest of the app.
  final Dio _dio = apiClient.dio;

  /// `GET /ai/history` (default thread) or `GET /ai/history/{id}` (a
  /// specific conversation). Either path returns a flat chronological
  /// list of [ChatMessageModel].
  ///
  /// Passing [conversationId] routes to the per-conversation endpoint;
  /// `null` (or omitted) routes to the default-thread endpoint. The
  /// backend picks a single thread per user when no id is supplied.
  Future<List<ChatMessageModel>> getHistory({String? conversationId}) async {
    try {
      final path = conversationId == null
          ? '/ai/history'
          : '/ai/history/$conversationId';
      final res = await _dio.get<List<dynamic>>(path);
      final list = res.data ?? const [];
      // `growable: true` is the default for `Iterable.toList()`, but we
      // state it explicitly because callers (`ChatProvider.loadHistory`)
      // reassign this to a mutable field and then append to it in
      // place. Returning a fixed-length list here would silently break
      // the optimistic-bubble flow with an
      // "Unsupported operation: Cannot add to a fixed-length list".
      return list
          .cast<Map<String, dynamic>>()
          .map(ChatMessageModel.fromJson)
          .toList(growable: true);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// `DELETE /ai/history` — clears the entire history for the current
  /// user. There is no per-conversation delete on the backend yet; when
  /// multi-conversation UIs land, extend this to accept a
  /// `conversationId` and route to `/ai/history/{id}` (DELETE). For now
  /// this is intentionally whole-account.
  Future<void> deleteHistory() async {
    try {
      await _dio.delete<void>('/ai/history');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// `POST /ai/chat` and stream the response as plain text chunks.
  ///
  /// The endpoint replies with `Content-Type: text/event-stream` rather
  /// than JSON. Frames look like:
  ///
  ///   data: {"text": "partial reply"}\n\n
  ///   ...
  ///   data: [DONE]\n\n
  ///
  /// A single byte chunk read from the socket may carry zero, one,
  /// partial, or several complete frames — we have to buffer + split
  /// ourselves instead of assuming one read = one frame.
  ///
  /// If the **initial POST** fails (network, timeout, 5xx before
  /// streaming starts), the DioException propagates as an
  /// [ApiException] to the caller. Errors that occur *after* the stream
  /// is open are silently skipped per frame — by spec, the server
  /// surfaces chat-time failures as `{"text": "I am having trouble
  /// connecting..."}` + `[DONE]`, not as transport errors, so frame
  /// parsing failures here really should never happen on a healthy
  /// server.
  Stream<String> sendMessageStream(
    String message, {
    String? conversationId,
  }) async* {
    // Open the streaming response. If the POST itself fails, this
    // `await` throws and the `async*` never produces a single item;
    // the caller's `await for` receives the throw.
    //
    // Dio hands back a `Response<dynamic>` here whose `.data` is a
    // `ResponseBody` (a byte stream + metadata). We pull the body out
    // immediately so the rest of this function reads as cleanly as a
    // plain stream pipeline.
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/ai/chat',
      data: {'message': message, 'conversation_id': conversationId},
      options: Options(responseType: ResponseType.stream),
    );
    final body = response.data as ResponseBody;

    // Buffer that survives chunk boundaries — one TCP-level read can
    // carry parts of two SSE frames (or several of three), so we
    // collect raw text until we see a `\n\n` separator, then peel off
    // the frame.
    final raw = StringBuffer();

    // Latched when the server signals end-of-stream via `data: [DONE]`.
    // Closing the `async*` from inside the inner async helper isn't
    // possible, so the outer generator owns the sentinel and breaks
    // out itself.
    bool streamDone = false;

    // Decode the byte stream as UTF-8 — the network may split a single
    // multi-byte character across two chunks. `utf8.decoder` is a
    // converter for `List<int>`, but `body.stream` is `Stream<Uint8List>`,
    // so we widen with `.cast<List<int>>()` first.
    final stream = body.stream.cast<List<int>>().transform(utf8.decoder);

    await for (final chunk in stream) {
      if (streamDone) break;
      raw.write(chunk);

      // Pull off every complete "\n\n"-terminated frame in the buffer.
      // Whatever's left after the last `\n\n` is an incomplete frame;
      // leave it for the next iteration.
      var bufStr = raw.toString();
      int nlIdx;
      while ((nlIdx = bufStr.indexOf('\n\n')) != -1) {
        final frame = bufStr.substring(0, nlIdx);
        bufStr = bufStr.substring(nlIdx + 2);
        raw
          ..clear()
          ..write(bufStr);

        // [DONE] sentinel — the very last frame of any chat response.
        // Recognize it whether it arrives bare ("data: [DONE]") or with
        // a stray trailing chunk; we just trim and substring-match.
        if (_frameIsDone(frame)) {
          streamDone = true;
          break;
        }

        yield* _chunksFromFrame(frame);

        if (raw.isEmpty) break; // nothing left buffered
        bufStr = raw.toString();
      }

      if (streamDone) break;
    }
    // Any tail without a `\n\n` terminator is malformed — ignore.
    // The server is expected to close cleanly with `[DONE]\n\n`.
  }

  /// True iff [frame]'s payload, after trimming and stripping the SSE
  /// prefix, is exactly `[DONE]`. Defensive against extra whitespace
  /// or the spec's occasional trailing-junk frames.
  bool _frameIsDone(String frame) {
    for (final rawLine in const LineSplitter().convert(frame)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload == '[DONE]') return true;
    }
    return false;
  }

  /// Yields the parsed text deltas embedded in one SSE frame.
  ///
  /// Real SSE events can carry multiple `data:` lines per frame joined
  /// by `\n`. Each is yielded in order. A frame with no `data:` line
  /// (e.g. a comment frame beginning with `:`) yields nothing. The
  /// `[DONE]` sentinel is handled by the outer generator, not here —
  /// this helper just ignores it.
  ///
  /// `async*` (not `sync*`) so the outer generator can `yield*` it
  /// directly — `yield*` in an `async*` function expects a `Stream<T>`
  /// rather than an `Iterable<T>`.
  Stream<String> _chunksFromFrame(String frame) async* {
    for (final rawLine in const LineSplitter().convert(frame)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      // SSE comment lines start with `:` — skip them per the spec.
      if (line.startsWith(':')) continue;
      // Per-event `event:`, `id:`, `retry:` fields — we don't need any
      // of them on `/ai/chat` but handle them defensively by skipping
      // anything that isn't a `data:` line.
      if (!line.startsWith('data:')) continue;
      // Standard form is "data: <payload>" (one space). Be lenient
      // about extra leading whitespace.
      final payload = line.substring(5).trimLeft();
      if (payload == '[DONE]') continue; // outer loop handles this

      try {
        final decoded = json.decode(payload);
        if (decoded is Map && decoded['text'] is String) {
          yield decoded['text'] as String;
        }
      } catch (e, st) {
        // Malformed JSON inside a frame — never bubble this up; the
        // streaming generator is the wrong place to throw at the user.
        debugPrint('SSE frame parse skipped: $e\n$st');
      }
    }
  }
}
