import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import 'profile_providers.dart';

/// Asks for a new name and saves it. Used from Home (avatar) and Settings.
Future<void> showEditNameDialog(BuildContext context, WidgetRef ref, String current) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => _EditNameDialog(initial: current),
  );
  if (result != null && result.trim().isNotEmpty) {
    await ref.read(userProfileProvider.notifier).setName(result);
  }
}

/// Owns its text controller, so the controller is only disposed after the
/// dialog's closing animation has finished (disposing it earlier crashes
/// with "_dependents.isEmpty is not true").
class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial});

  final String initial;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: l10n.nameHint, counterText: ''),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
