import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart';
import 'package:frontend/features/conversation/presentation/bloc/conversation_cubit.dart';
import 'package:frontend/features/conversation/presentation/widgets/connection_status_indicator.dart';
import 'package:frontend/features/conversation/presentation/widgets/message_bubble.dart';
import 'package:frontend/features/conversation/presentation/widgets/speaker_toggle.dart';
import 'package:frontend/injection_container.dart';

/// Main conversation screen for real-time voice translation between
/// two speakers.
///
/// Layout:
/// - AppBar with title + connection status chip
/// - Scrollable list of message bubbles
/// - Bottom control bar: language selector, speaker toggle, mic button,
///   start/stop controls
///
/// State management: [ConversationCubit] provided via [BlocProvider].
/// WriteCubit — scoped locally per this screen (not global).
class ConversationPage extends StatelessWidget {
  const ConversationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConversationCubit>(
      create: (_) => sl<ConversationCubit>(),
      child: const _ConversationView(),
    );
  }
}

class _ConversationView extends StatefulWidget {
  const _ConversationView();

  @override
  State<_ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<_ConversationView> {
  final _scrollController = ScrollController();

  // Language configuration — default Vietnamese ↔ English.
  String _srcLang = 'vi';
  String _tgtLang = 'en';

  // Available language options.
  static const _languages = <String, String>{
    'vi': 'Tiếng Việt',
    'en': 'English',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: BlocConsumer<ConversationCubit, ConversationState>(
        listener: (context, state) {
          // Scroll to bottom when new messages arrive.
          if (state is ConversationConnected && state.messages.isNotEmpty) {
            _scrollToBottom();
          }
          // Show error snackbar.
          if (state is ConversationFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              // Disconnection banner
              if (state is ConversationDisconnected)
                _buildDisconnectBanner(context, state),

              // Message list
              Expanded(child: _buildMessageList(context, state)),

              // Bottom control bar
              _buildBottomBar(context, state),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        'Phiên dịch hội thoại',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      actions: [
        // Connection status indicator
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: BlocSelector<ConversationCubit, ConversationState,
              WebSocketConnectionStatus>(
            selector: (state) => state.connectionStatus,
            builder: (context, status) {
              return ConnectionStatusIndicator(status: status);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDisconnectBanner(
    BuildContext context,
    ConversationDisconnected state,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.reason,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => context.read<ConversationCubit>().connect(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Thử lại'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, ConversationState state) {
    final messages = state.messages;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (messages.isEmpty) {
      return _buildEmptyState(context, state, isDark);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: messages.length + (state is ConversationProcessing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && state is ConversationProcessing) {
          return _buildProcessingBubble(context);
        }
        return MessageBubble(
          message: messages[index],
          index: index,
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ConversationState state,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final isConnected = state is ConversationConnected;
    final isInitial = state is ConversationInitial;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF1565C0),
                            const Color(0xFF00695C),
                          ]
                        : [
                            const Color(0xFF42A5F5),
                            const Color(0xFF26A69A),
                          ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.translate_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              isConnected
                  ? 'Sẵn sàng phiên dịch'
                  : 'Phiên dịch hội thoại',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              isConnected
                  ? 'Nhấn nút mic để bắt đầu nói.\n'
                      'Cuộc hội thoại sẽ được dịch real-time.'
                  : 'Kết nối để bắt đầu phiên dịch\n'
                      'hội thoại real-time giữa hai người.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),

            if (isInitial) ...[
              const SizedBox(height: 28),
              _buildConnectButton(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingBubble(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 48, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Đang xử lý...',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ConversationState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isConnected = state is ConversationConnected ||
        state is ConversationRecording ||
        state is ConversationProcessing;
    final isRecording = state is ConversationRecording;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Language selector row
          if (isConnected || state is ConversationInitial)
            _buildLanguageRow(context, state),
          const SizedBox(height: 12),

          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Speaker toggle (only when connected)
              if (isConnected)
                SpeakerToggle(
                  currentSpeaker: state.currentSpeaker,
                  onToggle: () =>
                      context.read<ConversationCubit>().switchSpeaker(),
                  enabled: !isRecording,
                ),

              if (isConnected) const SizedBox(width: 16),

              // Mic button
              if (isConnected) _buildMicButton(context, state, isRecording),

              if (isConnected) const SizedBox(width: 16),

              // End session button
              if (isConnected)
                _buildEndButton(context),

              // Connect button (when not connected)
              if (state is ConversationInitial)
                _buildConnectButton(context),
            ],
          ),

          // Recording indicator
          if (isRecording) ...[
            const SizedBox(height: 10),
            _buildRecordingIndicator(context),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageRow(BuildContext context, ConversationState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Source language dropdown
        _buildLanguageChip(
          context,
          value: _srcLang,
          isDark: isDark,
          onChanged: (lang) {
            setState(() => _srcLang = lang);
          },
        ),

        // Swap button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: IconButton(
            onPressed: () {
              setState(() {
                final temp = _srcLang;
                _srcLang = _tgtLang;
                _tgtLang = temp;
              });
            },
            icon: Icon(
              Icons.swap_horiz_rounded,
              color: theme.colorScheme.primary,
            ),
            style: IconButton.styleFrom(
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        // Target language dropdown
        _buildLanguageChip(
          context,
          value: _tgtLang,
          isDark: isDark,
          onChanged: (lang) {
            setState(() => _tgtLang = lang);
          },
        ),
      ],
    );
  }

  Widget _buildLanguageChip(
    BuildContext context, {
    required String value,
    required bool isDark,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          borderRadius: BorderRadius.circular(12),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
          items: _languages.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _buildMicButton(
    BuildContext context,
    ConversationState state,
    bool isRecording,
  ) {
    return GestureDetector(
      onTap: () {
        final cubit = context.read<ConversationCubit>();
        if (isRecording) {
          cubit.stopListening();
        } else {
          // Start session if not yet started, then begin listening.
          if (state is ConversationConnected && state.sessionId == null) {
            cubit.startSession(
              sourceLanguage: _srcLang,
              targetLanguage: _tgtLang,
            );
          }
          cubit.startListening();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isRecording ? 72 : 60,
        height: isRecording ? 72 : 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isRecording
                ? [const Color(0xFFF44336), const Color(0xFFD32F2F)]
                : [const Color(0xFF1976D2), const Color(0xFF0D47A1)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isRecording
                      ? const Color(0xFFF44336)
                      : const Color(0xFF1976D2))
                  .withValues(alpha: 0.4),
              blurRadius: isRecording ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isRecording ? Icons.stop_rounded : Icons.mic_rounded,
          color: Colors.white,
          size: isRecording ? 32 : 28,
        ),
      ),
    );
  }

  Widget _buildEndButton(BuildContext context) {
    return IconButton(
      onPressed: () {
        _showEndSessionDialog(context);
      },
      icon: const Icon(Icons.call_end_rounded),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFF44336).withValues(alpha: 0.1),
        foregroundColor: const Color(0xFFF44336),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildConnectButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: () {
        context.read<ConversationCubit>().connect();
      },
      icon: const Icon(Icons.wifi_rounded, size: 20),
      label: const Text('Bắt đầu kết nối'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing red dot
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                builder: (context, dotOpacity, _) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF44336)
                          .withValues(alpha: dotOpacity),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Đang nghe...',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFF44336),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEndSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Kết thúc cuộc hội thoại?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Cuộc hội thoại sẽ được kết thúc và bạn sẽ ngắt kết nối.',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<ConversationCubit>().endSession();
                context.read<ConversationCubit>().disconnect();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF44336),
              ),
              child: const Text('Kết thúc'),
            ),
          ],
        );
      },
    );
  }
}
