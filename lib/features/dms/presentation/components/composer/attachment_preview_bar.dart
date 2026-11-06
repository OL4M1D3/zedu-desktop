import 'dart:io' show File;

import 'package:zedu/core/core.dart';

const _imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

/// The file picker sets `mimeType` to the bare extension, so the name is the
/// reliable signal; a real image MIME type only exists on pasted files.
bool isImageAttachment(XFile file) {
  final name = file.name.isNotEmpty ? file.name : file.path;
  final dot = name.lastIndexOf('.');
  final ext = dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  return _imageExtensions.contains(ext) ||
      (file.mimeType?.startsWith('image/') ?? false);
}

class AttachmentPreviewBar extends StatelessWidget {
  final List<XFile> files;
  final ValueChanged<int> onRemove;
  final AppPalette colors;

  const AttachmentPreviewBar({
    super.key,
    required this.files,
    required this.onRemove,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];
          // The inset keeps the remove button inside the Stack and the list:
          // anything outside them is clipped and cannot be clicked.
          return Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, right: 8),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: _AttachmentThumbnail(
                  key: ObjectKey(file),
                  file: file,
                  colors: colors,
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Tooltip(
                  message: 'Remove attachment',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onRemove(index),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shows a picked, pasted or drawn image as a thumbnail, and anything else
/// (or an image that fails to decode) as the document icon and name.
class _AttachmentThumbnail extends StatefulWidget {
  final XFile file;
  final AppPalette colors;

  const _AttachmentThumbnail({
    super.key,
    required this.file,
    required this.colors,
  });

  @override
  State<_AttachmentThumbnail> createState() => _AttachmentThumbnailState();
}

class _AttachmentThumbnailState extends State<_AttachmentThumbnail> {
  // Path-less files (pasted or drawn) are read once and kept for the tile.
  Future<Uint8List>? _bytes;

  bool get _isImage => isImageAttachment(widget.file);

  @override
  void initState() {
    super.initState();
    if (_isImage && widget.file.path.isEmpty) {
      _bytes = widget.file.readAsBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isImage) return _document();
    final name = widget.file.name;
    if (name.isEmpty) return _image();
    return Stack(
      fit: StackFit.expand,
      children: [
        _image(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: widget.colors.textPrimary.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              name,
              style: TextStyle(color: widget.colors.onPrimary, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _image() {
    if (widget.file.path.isNotEmpty) {
      return Image.file(
        File(widget.file.path),
        fit: BoxFit.cover,
        cacheWidth: 144,
        errorBuilder: (_, _, _) => _document(),
      );
    }
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return snapshot.hasError ? _document() : const SizedBox.shrink();
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: 144,
          errorBuilder: (_, _, _) => _document(),
        );
      },
    );
  }

  Widget _document() {
    final colors = widget.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.insert_drive_file_rounded, color: colors.primary, size: 24),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            widget.file.name,
            style: TextStyle(color: colors.textPrimary, fontSize: 9),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
