import 'package:flutter/material.dart';

/// Modal bottom sheet for composing a new post.
///
/// Calls [onPublish] with the post content when the user taps "Post".
/// The caller is responsible for the optimistic update, server mutation,
/// and rollback logic (see [FeedScreen._publish]).
class ComposeSheet extends StatefulWidget {
  final Future<void> Function(String content) onPublish;

  const ComposeSheet({super.key, required this.onPublish});

  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<ComposeSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field when the sheet opens.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isPublishing) return;

    setState(() => _isPublishing = true);

    // Close the sheet immediately — the optimistic update shows the post
    // in the feed before the server responds.
    if (mounted) Navigator.of(context).pop();

    await widget.onPublish(content);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'New Post',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: 4,
              maxLength: 280,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _controller.text.trim().isEmpty ? null : _submit,
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}
