import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';

class CommentInputBar extends StatelessWidget {
  const CommentInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.replyingToUsername,
    this.onCancelReply,
    this.isSending = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String? replyingToUsername;
  final VoidCallback? onCancelReply;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: context.theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: context.colors.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyingToUsername != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Row(
                  children: [
                    Text(
                      'Replying to @$replyingToUsername',
                      style: context.textTheme.labelSmall,
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onCancelReply,
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: context.colors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                isSending
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          Icons.send_rounded,
                          color: context.colors.primary,
                        ),
                        onPressed: onSend,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
