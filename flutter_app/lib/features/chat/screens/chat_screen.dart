import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../models/chat_message_model.dart';
import '../providers/chat_provider.dart';

/// AI chat screen — NutriBot.
///
/// Single responsibility: render the [ChatProvider] message list as a
/// bubble UI, drive an input field that dispatches to
/// [ChatProvider.sendMessage], and react to the provider's
/// isSending / errorMessage / isLoadingHistory state. Networking and
/// message persistence live in the provider layer.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  /// Drives autoscroll-to-latest — the ListView jumps to its
  /// `maxScrollExtent` whenever a new message arrives or an in-progress
  /// assistant bubble grows.
  final ScrollController _scrollController = ScrollController();

  /// Two-way bound to the input TextField; cleared after each send.
  final TextEditingController _inputController = TextEditingController();

  /// Captured from the previous build so we can detect "messages changed"
  /// vs "messages unchanged" and only autoscroll when something new
  /// actually arrived. The same pair tracks the last bubble's content
  /// length so streamed chunks push the view down too.
  int _prevMessagesLength = 0;
  int _prevLastMessageLen = 0;

  /// Captured from the previous build; lets us show each new error
  /// exactly once via post-frame, then `clearError()` it so a rebuild
  /// doesn't re-fire the same SnackBar.
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    // Defer the first load until after the first frame so we don't
    // trigger a setState during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  // ---- confirmation dialog (overflow menu) -----------------------------------

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить всю историю переписки?'),
        content: const Text('Это действие необратимо.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<ChatProvider>().clearHistory();
  }

  // ---- send handling --------------------------------------------------------

  Future<void> _onSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    // Clear first so the keyboard-closing animation doesn't race the
    // optimistic user-bubble render.
    _inputController.clear();

    await context.read<ChatProvider>().sendMessage(text);
  }

  // ---- autoscroll + error toast (post-frame) --------------------------------

  /// Run from `build()` after the new state is in hand. Schedules a
  /// jump-to-bottom for the next frame if messages changed, and shows
  /// any new error message exactly once as a SnackBar.
  void _postBuildEffects({
    required int messagesLength,
    required int lastMessageLen,
    required String? errorMessage,
  }) {
    final messagesChanged = messagesLength != _prevMessagesLength;
    final lastMessageGrew = lastMessageLen != _prevLastMessageLen;
    _prevMessagesLength = messagesLength;
    _prevLastMessageLen = lastMessageLen;

    final shouldScroll =
        messagesChanged || lastMessageGrew;

    if (shouldScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_scrollController.hasClients) return;
        // Jump, don't animate — every token arriving during a stream
        // would re-trigger this path and a smooth animation on each
        // one is more annoying than a snappy scroll.
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      });
    }

    if (errorMessage != null && errorMessage != _lastShownError) {
      _lastShownError = errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              behavior: SnackBarBehavior.floating,
            ),
          );
        // Cleared here (not in the build where we detected it) so the
        // snackbar gets one frame to actually render before the
        // provider state flips back to null. Otherwise the next build
        // would race the ScaffoldMessenger.
        context.read<ChatProvider>().clearError();
      });
    }
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chat = context.watch<ChatProvider>();

    final messages = chat.messages;
    final lastMessageLen = messages.isEmpty
        ? 0
        : messages.last.content.length;

    _postBuildEffects(
      messagesLength: messages.length,
      lastMessageLen: lastMessageLen,
      errorMessage: chat.errorMessage,
    );

    return Scaffold(
      // Default `true` makes the body resize when the keyboard appears;
      // the input bar uses its own bottom padding + SafeArea so this
      // doesn't push the messages behind the IME.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('NutriBot'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Меню',
            onSelected: (value) {
              if (value == 'clear') _confirmClearHistory();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Очистить историю'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _buildMessages(theme, chat),
            ),
            _InputBar(
              controller: _inputController,
              isSending: chat.isSending,
              onSend: _onSend,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages(ThemeData theme, ChatProvider chat) {
    final messages = chat.messages;
    final showInitialLoader = chat.isLoadingHistory && messages.isEmpty;

    if (showInitialLoader) {
      return const Center(child: CircularProgressIndicator());
    }

    if (messages.isEmpty) {
      return _EmptyChatHint(theme: theme);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: messages.length,
      itemBuilder: (ctx, i) {
        final msg = messages[i];
        return _MessageBubble(
          message: msg,
          isLastEmptyInFlight: _isLastEmptyInFlight(msg, i, messages, chat),
        );
      },
    );
  }

  /// True iff [msg] is the very last row, hasn't been streamed into yet,
  /// belongs to the assistant, and we are currently sending. The
  /// combination of all four — last in the list AND empty content AND
  /// assistant AND `isSending` — is what marks the in-flight optimistic
  /// placeholder that [ChatProvider.sendMessage] inserts to give the UI
  /// somewhere to grow into while the first chunk is in flight.
  bool _isLastEmptyInFlight(
    ChatMessageModel msg,
    int index,
    List<ChatMessageModel> messages,
    ChatProvider chat,
  ) {
    if (msg.isUser) return false;
    if (msg.content.isNotEmpty) return false;
    if (index != messages.length - 1) return false;
    return chat.isSending;
  }
}

// =============================================================================
// Empty-state hint
// =============================================================================

class _EmptyChatHint extends StatelessWidget {
  const _EmptyChatHint({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Спроси меня о питании, целях по калориям или продуктах!',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Message bubble
// =============================================================================

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isLastEmptyInFlight,
  });

  final ChatMessageModel message;
  final bool isLastEmptyInFlight;

  /// Asymmetric bubble radius — the bottom corner pointing TOWARDS the
  /// sender (right for user, left for assistant) is flattened to suggest
  /// a "tail" the message came out of. Sibling 18 px corners give the
  /// rest of the bubble a pill-y feel that reads as chat.
  static const _userRadius = BorderRadius.only(
    topLeft: Radius.circular(18),
    topRight: Radius.circular(18),
    bottomLeft: Radius.circular(18),
    bottomRight: Radius.circular(4),
  );
  static const _assistantRadius = BorderRadius.only(
    topLeft: Radius.circular(18),
    topRight: Radius.circular(18),
    bottomLeft: Radius.circular(4),
    bottomRight: Radius.circular(18),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    final Color background;
    final Color foreground;
    final EdgeInsets padding;
    final BorderRadius radius;
    final Alignment align;

    if (isUser) {
      background = theme.colorScheme.primaryContainer;
      foreground = theme.colorScheme.onPrimaryContainer;
      padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
      radius = _userRadius;
      align = Alignment.centerRight;
    } else {
      background = theme.colorScheme.surfaceContainerHighest;
      foreground = theme.colorScheme.onSurface;
      padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
      radius = _assistantRadius;
      align = Alignment.centerLeft;
    }

    final Widget content;
    if (isLastEmptyInFlight) {
      // Stream-in-flight placeholder: never has markdown, never needs
      // selection. The pulsing-dot indicator is its own tree.
      content = _TypingIndicator(color: foreground);
    } else if (isUser) {
      // User messages are typed prose — no markdown, no parsing.
      // SelectableText keeps "copy-paste my own draft" working.
      content = SelectableText(
        message.content,
        // SelectableText doesn't pick up the bubble's `foreground`
        // automatically when there's no DefaultTextStyle ancestor — set
        // it explicitly.
        style: theme.textTheme.bodyMedium?.copyWith(
          color: foreground,
          height: 1.35,
        ),
      );
    } else {
      // Assistant messages frequently contain markdown (**bold**, bullet
      // lists, headings, etc.). Render via `flutter_markdown` so the
      // formatting actually shows; wrap in `SelectionArea` so the user
      // can still copy the advice — MarkdownBody does not have
      // selectable-text behaviour on its own.
      content = SelectionArea(
        child: MarkdownBody(
          data: message.content,
          // Pull a coherent base from the active theme (handles font,
          // color-scheme-derived link color, code-block styling, etc.)
          // and then override just the paragraph + strong runs so they
          // match the rest of the bubble's typography exactly — the
          // defaults from `MarkdownStyleSheet.fromTheme` are designed
          // for a full-page reading surface and would look out of
          // place inside a chat bubble.
          styleSheet: _assistantStyleSheet(theme, foreground),
        ),
      );
    }

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
      ),
      child: content,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: align,
        child: bubble,
      ),
    );
  }

  /// Per-bubble MarkdownStyleSheet — keeps paragraph font, height and
  /// color matching the rest of the chat UI (otherwise the markdown
  /// package's defaults would clash with the bubble's own typography),
  /// bolds **strong** runs, and inherits list / heading / link
  /// styling from the theme so the rest of the chat looks consistent.
  static MarkdownStyleSheet _assistantStyleSheet(ThemeData theme, Color foreground) {
    final base = theme.textTheme.bodyMedium?.copyWith(
      color: foreground,
      height: 1.35,
    );
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: base,
      strong: base?.copyWith(fontWeight: FontWeight.w700),
      // Lists, blockquotes, code blocks keep `MarkdownStyleSheet`'s
      // default top/bottom margins — those defaults already account
      // for the (modest) inner padding of the surrounding bubble
      // Container, so they don't look cramped.
    );
  }
}

/// Three pulsing dots — shown inside the placeholder bubble while the
/// assistant's first stream chunk is in flight.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.color});

  final Color color;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _dot(double opacityOffset) {
    // Each dot pulses on a 1/3-cycle stagger so the three animate
    // sequentially rather than in unison.
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final t = (_ctrl.value + opacityOffset) % 1.0;
        final opacity = 0.35 + 0.65 * (1 - (t * 2 - 1).abs().clamp(0, 1));
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(0.0),
        _dot(1 / 3),
        _dot(2 / 3),
      ],
    );
  }
}

// =============================================================================
// Bottom input bar
// =============================================================================

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      // Lift the bar above the keyboard by exactly the keyboard's
      // bottom inset. SafeArea below takes care of the system nav bar.
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  enabled: !isSending,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Спроси о питании...',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: isSending ? null : onSend,
                tooltip: 'Отправить',
                icon: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
