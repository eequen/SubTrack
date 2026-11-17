import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:subtrack/app/theme.dart';
import 'package:subtrack/shared/chips.dart';
import 'package:subtrack/shared/ui_components.dart';

/// The value returned by [showFinishVersionSheet] when the student slides up.
const finishVersionSubmitted = 'submitted';

/// The value returned by [showFinishVersionSheet] when the student slides down.
const finishVersionFinal = 'final';

/// Key for the draggable knob, used by widget tests.
const finishVersionKnobKey = Key('finish-version-knob');

/// Opens the "save this version" sheet.
///
/// The version is already committed, so this only chooses the activity's
/// outcome: slide up to save and submit, slide down to save as final.
Future<String?> showFinishVersionSheet(
  BuildContext context, {
  required int versionNo,
  required String fileName,
  required String currentStatus,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    // The knob owns the vertical drag. Letting the sheet drag too would make
    // a downward slide dismiss the sheet instead of choosing "final".
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => FinishVersionSheet(
      versionNo: versionNo,
      fileName: fileName,
      currentStatus: currentStatus,
    ),
  );
}

class FinishVersionSheet extends StatefulWidget {
  const FinishVersionSheet({
    required this.versionNo,
    required this.fileName,
    required this.currentStatus,
    super.key,
  });

  final int versionNo;
  final String fileName;
  final String currentStatus;

  @override
  State<FinishVersionSheet> createState() => _FinishVersionSheetState();
}

class _FinishVersionSheetState extends State<FinishVersionSheet> {
  static const _maxDrag = 48.0;
  static const _threshold = 26.0;

  double _drag = 0;
  bool _dragging = false;

  bool get _towardsSubmit => _drag <= -_threshold;
  bool get _towardsFinal => _drag >= _threshold;

  void _finish(String status) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(status);
  }

  void _onDragStart(DragStartDetails details) {
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _drag = (_drag + details.delta.dy).clamp(-_maxDrag, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final submit = _drag <= -_threshold || velocity < -650;
    final finalVersion = _drag >= _threshold || velocity > 650;
    if (submit) {
      _finish(finishVersionSubmitted);
    } else if (finalVersion) {
      _finish(finishVersionFinal);
    } else {
      setState(() {
        _dragging = false;
        _drag = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (submitText, submitBg) = statusColors('submitted', palette);
    final (finalText, finalBg) = statusColors('final', palette);

    return SheetScaffold(
      title: 'Save v${widget.versionNo}',
      trailing: IconButton(
        tooltip: 'Close',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close),
      ),
      child: Flexible(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Your version is already saved. Choose how to close this work.',
                style: TextStyle(color: palette.mutedText, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Now: ',
                    style: TextStyle(color: palette.mutedText, fontSize: 13),
                  ),
                  StatusChip(status: widget.currentStatus),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: _onDragStart,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 2,
                        height: 168,
                        decoration: BoxDecoration(
                          color: palette.cardBorder,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: _FinishTarget(
                          label: 'Save & submit',
                          caption: 'Slide up',
                          icon: Icons.upload_rounded,
                          foreground: submitText,
                          background: submitBg,
                          active: _towardsSubmit,
                          onTap: () => _finish(finishVersionSubmitted),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _FinishTarget(
                          label: 'Save as final',
                          caption: 'Slide down',
                          icon: Icons.download_rounded,
                          foreground: finalText,
                          background: finalBg,
                          active: _towardsFinal,
                          onTap: () => _finish(finishVersionFinal),
                        ),
                      ),
                      AnimatedContainer(
                        duration: _dragging
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        transform: Matrix4.translationValues(0, _drag, 0),
                        child: Container(
                          key: finishVersionKnobKey,
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: _towardsSubmit
                                ? submitBg
                                : _towardsFinal
                                ? finalBg
                                : palette.card,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _towardsSubmit
                                  ? submitText
                                  : _towardsFinal
                                  ? finalText
                                  : palette.accent,
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.cardShadow,
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                color: _towardsSubmit
                                    ? submitText
                                    : _towardsFinal
                                    ? finalText
                                    : palette.accentText,
                                size: 26,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'v${widget.versionNo}',
                                style: TextStyle(
                                  color: _towardsSubmit
                                      ? submitText
                                      : _towardsFinal
                                      ? finalText
                                      : palette.text,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'Slide the version up to submit, or down to keep it final.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.mutedText, fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinishTarget extends StatelessWidget {
  const _FinishTarget({
    required this.label,
    required this.caption,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String caption;
  final IconData icon;
  final Color foreground;
  final Color background;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: active ? background : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              border: Border.all(
                color: active ? foreground : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      caption,
                      style: TextStyle(
                        color: context.palette.mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
