// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../domain/entities/comment.dart';
import '../providers/comment_provider.dart';
import 'comment_input_bar.dart';
import 'comment_tile.dart';

/// Opened via showModalBottomSheet from the feed's comment icon. Spec
/// §11's "Comments (850)" header count reads from the live video state
/// in the feed rather than a separate query, so it stays in sync with
/// likes/shares/etc shown elsewhere on the same video.
class CommentBottomSheet extends ConsumerStatefulWidget {
  const CommentBottomSheet({super.key, required this.videoId, required this.initialCount});

  final String videoId;
  final int initialCount;

  @override
  ConsumerState<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends ConsumerState<CommentBottomSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final Set<String> _expandedReplies = {};
  Comment? _replyingTo;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(commentsProvider(widget.videoId).notifier).loadMore(widget.videoId);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await ref.read(commentActionsProvider).addComment(
            videoId: widget.videoId,
            content: text,
            parentId: _replyingTo?.id,
          );
      _controller.clear();
      if (_replyingTo != null) {
        _expandedReplies.add(_replyingTo!.id);
      }
      setState(() => _replyingTo = null);
    } catch (e) {
      if (mounted) context.showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleLike(Comment comment) async {
    try {
      await ref.read(commentActionsProvider).setLiked(comment, !comment.isLikedByMe);
    } catch (e) {
      if (mounted) context.showSnack('$e', isError: true);
    }
  }

  Future<void> _delete(Comment comment) async {
    try {
      await ref.read(commentActionsProvider).deleteComment(comment);
    } catch (e) {
      if (mounted) context.showSnack('$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.videoId));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, sheetScrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Comments (${widget.initialCount})',
                  style: context.textTheme.titleMedium),
            ),
            const Divider(height: 1),
            Expanded(
              child: commentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('$err', style: context.textTheme.bodyMedium),
                  ),
                ),
                data: (state) {
                  if (state.items.isEmpty) {
                    return Center(
                      child: Text('No comments yet — say something!',
                          style: context.textTheme.bodyMedium),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      final comment = state.items[index];
                      final expanded = _expandedReplies.contains(comment.id);
                      return Column(
                        key: ValueKey(comment.id),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CommentTile(
                            comment: comment,
                            onLikeTap: () => _toggleLike(comment),
                            onReplyTap: () => setState(() => _replyingTo = comment),
                            onDeleteTap: comment.isMine ? () => _delete(comment) : null,
                            repliesExpanded: expanded,
                            onToggleReplies: () => setState(() {
                              expanded
                                  ? _expandedReplies.remove(comment.id)
                                  : _expandedReplies.add(comment.id);
                            }),
                          ),
                          if (expanded)
                            _RepliesList(
                              parentId: comment.id,
                              onReply: (reply) => setState(() => _replyingTo = comment),
                              onLike: _toggleLike,
                              onDelete: _delete,
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            CommentInputBar(
              controller: _controller,
              onSend: _send,
              isSending: _isSending,
              replyingToUsername: _replyingTo?.username,
              onCancelReply: () => setState(() => _replyingTo = null),
            ),
          ],
        );
      },
    );
  }
}

class _RepliesList extends ConsumerWidget {
  const _RepliesList({
    required this.parentId,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
  });

  final String parentId;
  final void Function(Comment) onReply;
  final void Function(Comment) onLike;
  final void Function(Comment) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repliesAsync = ref.watch(repliesProvider(parentId));

    return repliesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(left: 44, top: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (state) {
        return Column(
          children: [
            for (final reply in state.items)
              CommentTile(
                comment: reply,
                isIndented: true,
                onLikeTap: () => onLike(reply),
                onReplyTap: () => onReply(reply),
                onDeleteTap: reply.isMine ? () => onDelete(reply) : null,
              ),
            if (state.hasMore)
              Padding(
                padding: const EdgeInsets.only(left: 44, top: 6),
                child: TextButton(
                  onPressed: () =>
                      ref.read(repliesProvider(parentId).notifier).loadMore(parentId),
                  child: const Text('Load more replies'),
                ),
              ),
          ],
        );
      },
    );
  }
}
