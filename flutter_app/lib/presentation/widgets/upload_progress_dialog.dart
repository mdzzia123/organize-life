import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 显示上传进度对话框，任务完成后自动关闭。
Future<T?> showUploadProgress<T>({
  required BuildContext context,
  required Future<T> Function(void Function(double progress, String label) report) task,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _UploadProgressDialog<T>(task: task),
  );
}

class _UploadProgressDialog<T> extends StatefulWidget {
  const _UploadProgressDialog({required this.task});

  final Future<T> Function(void Function(double progress, String label) report) task;

  @override
  State<_UploadProgressDialog<T>> createState() => _UploadProgressDialogState<T>();
}

class _UploadProgressDialogState<T> extends State<_UploadProgressDialog<T>> {
  double _progress = 0;
  String _label = '';
  bool _failed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final result = await widget.task((progress, label) {
        if (mounted) {
          setState(() {
            _progress = progress.clamp(0.0, 1.0);
            _label = label;
          });
        }
      });
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _failed = true;
          _error = e.toString();
          _label = l10n.uploadFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = _label.isEmpty ? l10n.uploadPreparing : _label;

    return AlertDialog(
      title: Text(l10n.syncToCloud),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: _failed ? null : (_progress > 0 ? _progress : null)),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          if (!_failed && _progress > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${(_progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          if (_failed && _error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
      actions: [
        if (_failed)
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
      ],
    );
  }
}
