import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_info.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_text.dart';
import '../theme/pharmalens_theme.dart';

/// Why an AI answer is reported.
enum AnswerReportReason { harmful, wrong, offensive, other }

extension on AnswerReportReason {
  String label(AppLocalizations text) {
    switch (this) {
      case AnswerReportReason.harmful:
        return text.reportReasonHarmful;
      case AnswerReportReason.wrong:
        return text.reportReasonWrong;
      case AnswerReportReason.offensive:
        return text.reportReasonOffensive;
      case AnswerReportReason.other:
        return text.reportReasonOther;
    }
  }
}

/// Lets the user report an assistant answer (Google Play's AI-generated
/// content policy asks for this). The report opens WhatsApp to the
/// PharmaLens team with the reason and the answer only; the user's question
/// and health data are not included. Returns true when it was sent.
Future<bool> showReportAnswerSheet(BuildContext context, {required String answer, required bool isArabic}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(answer: answer, isArabic: isArabic),
  );
  return sent == true;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.answer, required this.isArabic});

  final String answer;
  final bool isArabic;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final TextEditingController _details = TextEditingController();
  AnswerReportReason _reason = AnswerReportReason.wrong;
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = appText(widget.isArabic);
    final answer = widget.answer.length > 1500 ? '${widget.answer.substring(0, 1500)}…' : widget.answer;
    final message = text.reportMessage(
      _reason.label(text),
      _details.text.trim().isEmpty ? '-' : _details.text.trim(),
      answer,
    );
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.https('wa.me', '/${AppInfo.whatsAppNumber}', <String, String>{'text': message}),
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Could not open WhatsApp for the report: $error');
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (!opened) {
      messenger?.showSnackBar(SnackBar(content: Text(text.couldNotOpenWhatsappOnThis)));
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final text = appText(widget.isArabic);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: PharmaLensColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text.reportAnAiAnswer,
                  style: TextStyle(color: palette.textPrimary, fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(text.reportAnswerBody, style: TextStyle(color: palette.textSecondary, fontSize: 12.5, height: 1.45)),
          const SizedBox(height: 12),
          RadioGroup<AnswerReportReason>(
            groupValue: _reason,
            onChanged: (value) {
              if (value != null) setState(() => _reason = value);
            },
            child: Column(
              children: [
                for (final reason in AnswerReportReason.values)
                  RadioListTile<AnswerReportReason>(
                    value: reason,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(reason.label(text), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _details,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: text.reportDetailsHint),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(backgroundColor: PharmaLensColors.danger),
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: Text(text.sendReport),
          ),
        ],
      ),
    );
  }
}
