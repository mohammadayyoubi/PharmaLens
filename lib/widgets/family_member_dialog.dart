import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../services/health_profile_service.dart';

/// Asks for a family member's name and adds them (they become the selected
/// person). Returns the new profile, or null when cancelled.
Future<HealthProfile?> showAddFamilyMemberDialog(BuildContext context, {required bool isArabic}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(isArabic: isArabic),
  );
  if (name == null || name.trim().isEmpty) return null;
  return HealthProfileService().addProfile(name);
}

/// The dialog owns its text field: a controller disposed by the caller
/// right after `showDialog` returns is still in use while the dialog fades
/// out, which crashed the app.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.isArabic});

  final bool isArabic;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final text = appText(widget.isArabic);
    return AlertDialog(
      title: Text(text.addAFamilyMember),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: text.nameEGMom),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(text.cancel)),
        FilledButton(onPressed: _controller.text.trim().isEmpty ? null : _submit, child: Text(text.add)),
      ],
    );
  }
}

/// Asks for a health condition that is not in the list ("Other…").
Future<String?> showOtherConditionDialog(BuildContext context, {required bool isArabic}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ConditionDialog(isArabic: isArabic),
  );
}

class _ConditionDialog extends StatefulWidget {
  const _ConditionDialog({required this.isArabic});

  final bool isArabic;

  @override
  State<_ConditionDialog> createState() => _ConditionDialogState();
}

class _ConditionDialogState extends State<_ConditionDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final text = appText(widget.isArabic);
    return AlertDialog(
      title: Text(text.addAHealthCondition),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: text.conditionNameHint),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(text.cancel)),
        FilledButton(onPressed: _controller.text.trim().isEmpty ? null : _submit, child: Text(text.add)),
      ],
    );
  }
}
