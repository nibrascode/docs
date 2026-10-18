import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LinkInsertDialog extends StatefulWidget {
  final String selected;

  const LinkInsertDialog({super.key, this.selected = ''});

  static Future<String?> show(BuildContext context, {String selected = ''}) {
    return showDialog<String>(
      context: context,
      builder: (_) => LinkInsertDialog(selected: selected),
    );
  }

  @override
  State<LinkInsertDialog> createState() => _LinkInsertDialogState();
}

class _LinkInsertDialogState extends State<LinkInsertDialog> {
  late final TextEditingController _text;
  late final TextEditingController _url;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.selected);
    _url = TextEditingController(text: 'https://');
  }

  @override
  void dispose() {
    _text.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Insert link',
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _text,
            decoration: const InputDecoration(
              labelText: 'Display text',
              hintText: 'Click here',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final label = _text.text.trim().isEmpty
                ? _url.text.trim()
                : _text.text.trim();
            final url = _url.text.trim();
            if (url.isEmpty || url == 'https://') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid URL')),
              );
              return;
            }
            Navigator.pop(context, '[$label]($url)');
          },
          child: const Text('Insert'),
        ),
      ],
    );
  }
}
