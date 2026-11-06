import 'package:zedu/core/core.dart';

import 'doodle_stroke.dart';
import 'toolbar_button.dart';

/// The drawing area, at the same 4:3 ratio as [doodleExportSize].
const doodleCanvasSize = Size(600, 450);

const doodleStrokeWidths = [3.0, 6.0, 12.0];

/// Opens the doodle canvas. Returns the PNG bytes when the user attaches the
/// doodle, or null when they close it.
Future<Uint8List?> showDoodleDialog(BuildContext context) {
  return showDialog<Uint8List>(
    context: context,
    builder: (_) => const DoodleDialog(),
  );
}

class DoodleDialog extends StatefulWidget {
  const DoodleDialog({super.key});

  @override
  State<DoodleDialog> createState() => _DoodleDialogState();
}

class _DoodleDialogState extends State<DoodleDialog> {
  final _controller = DoodleController();
  Color? _color;
  double _width = doodleStrokeWidths[1];
  bool _isEraser = false;
  bool _exporting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _penColors(AppPalette colors) => [
    colors.textPrimary,
    colors.error,
    colors.primary,
    colors.success,
    colors.accent,
    colors.sidebar,
  ];

  void _startStroke(Offset point, AppPalette colors) {
    _controller.startStroke(
      point,
      color: _color ?? colors.textPrimary,
      width: _isEraser ? _width * 2 : _width,
      isEraser: _isEraser,
    );
  }

  Future<void> _attach() async {
    if (_controller.isEmpty || _exporting) return;
    setState(() => _exporting = true);
    final png = await exportDoodlePng(
      _controller.strokes,
      canvasSize: doodleCanvasSize,
    );
    if (mounted) Navigator.of(context).pop(png);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            _controller.undo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _controller.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _controller.redo,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: colors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Draw a doodle',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTools(colors),
                  const SizedBox(height: 12),
                  _buildCanvas(colors),
                  const SizedBox(height: 16),
                  _buildActions(colors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTools(AppPalette colors) {
    final selected = _color ?? colors.textPrimary;
    return Row(
      children: [
        for (final color in _penColors(colors))
          Tooltip(
            message: 'Pen colour',
            child: InkWell(
              key: ValueKey('doodle-color-${color.toARGB32()}'),
              onTap: () => setState(() {
                _color = color;
                _isEraser = false;
              }),
              customBorder: const CircleBorder(),
              child: Container(
                margin: const EdgeInsets.all(3),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: !_isEraser && color == selected
                        ? colors.primary
                        : colors.divider,
                    width: !_isEraser && color == selected ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(width: 12),
        for (final (index, width) in doodleStrokeWidths.indexed)
          ToolbarButton(
            icon: Icons.circle,
            tooltip: const ['Thin', 'Medium', 'Thick'][index],
            onTap: () => setState(() => _width = width),
            colors: colors,
            isActive: _width == width,
          ),
        const SizedBox(width: 12),
        ToolbarButton(
          icon: Icons.auto_fix_normal_rounded,
          tooltip: 'Eraser',
          onTap: () => setState(() => _isEraser = !_isEraser),
          colors: colors,
          isActive: _isEraser,
        ),
        const Spacer(),
        ToolbarButton(
          icon: Icons.undo_rounded,
          tooltip: 'Undo (Ctrl+Z)',
          onTap: _controller.undo,
          colors: colors,
        ),
        ToolbarButton(
          icon: Icons.redo_rounded,
          tooltip: 'Redo (Ctrl+Shift+Z)',
          onTap: _controller.redo,
          colors: colors,
        ),
        ToolbarButton(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Clear',
          onTap: _controller.clear,
          colors: colors,
        ),
      ],
    );
  }

  Widget _buildCanvas(AppPalette colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: MouseRegion(
          cursor: SystemMouseCursors.precise,
          child: Listener(
            key: const ValueKey('doodle-canvas'),
            onPointerDown: (e) => _startStroke(e.localPosition, colors),
            onPointerMove: (e) => _controller.extendStroke(e.localPosition),
            child: CustomPaint(
              size: doodleCanvasSize,
              painter: DoodlePainter(
                strokes: _controller.strokes,
                revision: _controller.revision,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(AppPalette colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: colors.textPrimary)),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.primary),
          onPressed: _controller.isEmpty || _exporting ? null : _attach,
          child: const Text('Attach to message'),
        ),
      ],
    );
  }
}
