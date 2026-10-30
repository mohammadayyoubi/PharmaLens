import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders the small Markdown subset the assistant writes: headings,
/// bullet and numbered lists, quotes, rules, simple tables, **bold**,
/// *italic*, `code` and [links](https://...). Unmatched markers such as a
/// stray "**" are removed instead of shown.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.data, {super.key, required this.style, this.accentColor});

  final String data;
  final TextStyle style;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(data);
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;

    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (i > 0) children.add(SizedBox(height: block.kind == _BlockKind.listItem && blocks[i - 1].kind == _BlockKind.listItem ? 4 : 8));
      children.add(_buildBlock(context, block, accent));
    }

    return SelectionArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildBlock(BuildContext context, _Block block, Color accent) {
    switch (block.kind) {
      case _BlockKind.heading:
        final size = (style.fontSize ?? 14) + (block.level == 1 ? 4 : block.level == 2 ? 2.5 : 1);
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text.rich(
            TextSpan(children: _inline(block.text, style.copyWith(fontSize: size, fontWeight: FontWeight.w900), accent)),
          ),
        );
      case _BlockKind.listItem:
        return Padding(
          padding: EdgeInsetsDirectional.only(start: 4.0 + block.level * 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: block.marker == null ? 14 : 22,
                child: block.marker == null
                    ? Padding(
                        padding: EdgeInsets.only(top: (style.fontSize ?? 14) * 0.55),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        ),
                      )
                    : Text(block.marker!, style: style.copyWith(fontWeight: FontWeight.w900, color: accent)),
              ),
              Expanded(child: Text.rich(TextSpan(children: _inline(block.text, style, accent)))),
            ],
          ),
        );
      case _BlockKind.quote:
        return Container(
          padding: const EdgeInsetsDirectional.only(start: 10, top: 2, bottom: 2),
          decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: accent.withValues(alpha: 0.6), width: 3))),
          child: Text.rich(TextSpan(children: _inline(block.text, style.copyWith(fontStyle: FontStyle.italic), accent))),
        );
      case _BlockKind.rule:
        return Divider(height: 8, color: style.color?.withValues(alpha: 0.2));
      case _BlockKind.table:
        return _buildTable(block.rows, accent);
      case _BlockKind.paragraph:
        return Text.rich(TextSpan(children: _inline(block.text, style, accent)));
    }
  }

  Widget _buildTable(List<List<String>> rows, Color accent) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final columns = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final small = style.copyWith(fontSize: (style.fontSize ?? 14) - 1);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: (style.color ?? Colors.grey).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
        children: [
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: r == 0 ? BoxDecoration(color: accent.withValues(alpha: 0.10)) : null,
              children: [
                for (var c = 0; c < columns; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text.rich(
                      TextSpan(
                        children: _inline(
                          c < rows[r].length ? rows[r][c] : '',
                          r == 0 ? small.copyWith(fontWeight: FontWeight.w900) : small,
                          accent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static final RegExp _inlinePattern = RegExp(
    r'(\*\*\*(.+?)\*\*\*)|(\*\*(.+?)\*\*)|(__(.+?)__)|(`([^`]+)`)|(\[([^\]]+)\]\((https?://[^)\s]+)\))|((?<![\w*])\*(?!\s)([^*\n]+?)(?<!\s)\*(?![\w*]))',
  );

  List<InlineSpan> _inline(String text, TextStyle base, Color accent) {
    final spans = <InlineSpan>[];
    var index = 0;

    void plain(String value) {
      // Markers the model left unmatched ("**", "***") are dropped.
      final cleaned = value.replaceAll(RegExp(r'\*{2,}'), '').replaceAll('__', '');
      if (cleaned.isNotEmpty) spans.add(TextSpan(text: cleaned, style: base));
    }

    for (final match in _inlinePattern.allMatches(text)) {
      if (match.start > index) plain(text.substring(index, match.start));

      if (match.group(2) != null) {
        spans.add(TextSpan(text: match.group(2), style: base.copyWith(fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)));
      } else if (match.group(4) != null) {
        spans.add(TextSpan(text: match.group(4), style: base.copyWith(fontWeight: FontWeight.w900)));
      } else if (match.group(6) != null) {
        spans.add(TextSpan(text: match.group(6), style: base.copyWith(fontWeight: FontWeight.w900)));
      } else if (match.group(8) != null) {
        spans.add(TextSpan(
          text: match.group(8),
          style: base.copyWith(fontFamily: 'monospace', backgroundColor: accent.withValues(alpha: 0.10)),
        ));
      } else if (match.group(10) != null) {
        final uri = Uri.tryParse(match.group(11)!);
        spans.add(TextSpan(
          text: match.group(10),
          style: base.copyWith(color: accent, decoration: TextDecoration.underline, decorationColor: accent),
          recognizer: uri == null
              ? null
              : (TapGestureRecognizer()..onTap = () => launchUrl(uri, mode: LaunchMode.externalApplication)),
        ));
      } else if (match.group(13) != null) {
        spans.add(TextSpan(text: match.group(13), style: base.copyWith(fontStyle: FontStyle.italic)));
      }
      index = match.end;
    }

    if (index < text.length) plain(text.substring(index));
    return spans;
  }

  static List<_Block> _parseBlocks(String source) {
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_Block>[];
    final paragraph = <String>[];

    void flush() {
      if (paragraph.isNotEmpty) {
        // Single line breaks are kept: the assistant uses them on purpose.
        blocks.add(_Block(_BlockKind.paragraph, paragraph.join('\n')));
        paragraph.clear();
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final line = raw.trimRight();
      final trimmed = line.trimLeft();
      final indent = (line.length - trimmed.length) ~/ 2;

      if (trimmed.isEmpty) {
        flush();
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        flush();
        blocks.add(_Block(_BlockKind.heading, heading.group(2)!.replaceAll(RegExp(r'#+$'), '').trim(), level: heading.group(1)!.length));
        continue;
      }

      if (RegExp(r'^([-*_])\1{2,}$').hasMatch(trimmed.replaceAll(' ', ''))) {
        flush();
        blocks.add(const _Block(_BlockKind.rule, ''));
        continue;
      }

      final bullet = RegExp(r'^[-*•+]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        flush();
        blocks.add(_Block(_BlockKind.listItem, bullet.group(1)!, level: indent.clamp(0, 3)));
        continue;
      }

      final numbered = RegExp(r'^(\d{1,3})[.)]\s+(.*)$').firstMatch(trimmed);
      if (numbered != null) {
        flush();
        blocks.add(_Block(_BlockKind.listItem, numbered.group(2)!, level: indent.clamp(0, 3), marker: '${numbered.group(1)}.'));
        continue;
      }

      if (trimmed.startsWith('>')) {
        flush();
        blocks.add(_Block(_BlockKind.quote, trimmed.replaceFirst(RegExp(r'^>\s?'), '')));
        continue;
      }

      if (trimmed.startsWith('|')) {
        flush();
        final rows = <List<String>>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          final row = lines[i].trim();
          if (!RegExp(r'^\|?\s*:?-{2,}').hasMatch(row)) {
            final cells = row.split('|').map((c) => c.trim()).toList();
            if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
            if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
            rows.add(cells);
          }
          i++;
        }
        i--;
        blocks.add(_Block(_BlockKind.table, '', rows: rows));
        continue;
      }

      paragraph.add(trimmed);
    }
    flush();
    return blocks;
  }
}

enum _BlockKind { heading, listItem, quote, rule, table, paragraph }

class _Block {
  const _Block(this.kind, this.text, {this.level = 0, this.marker, this.rows = const <List<String>>[]});

  final _BlockKind kind;
  final String text;
  final int level;
  final String? marker;
  final List<List<String>> rows;
}
