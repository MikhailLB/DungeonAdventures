import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../cartlock/progress_store.dart';
import 'ui_kit.dart';

/// A tappable player portrait. Lets the keeper set a custom photo from the
/// camera or photo library (this is the in-app feature that justifies the
/// camera + photo-library permissions). Stored locally only.
class AvatarBadge extends StatefulWidget {
  const AvatarBadge({super.key, required this.store, this.size = 44});

  final ProgressStore store;
  final double size;

  @override
  State<AvatarBadge> createState() => _AvatarBadgeState();
}

class _AvatarBadgeState extends State<AvatarBadge> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file != null) {
        await widget.store.setAvatarPath(file.path);
      }
    } catch (_) {
      // permission denied / cancelled — ignore silently
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Dungeon.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Dungeon.textDim.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'KEEPER PORTRAIT',
                style: TextStyle(
                  color: Dungeon.gold,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              _row(ctx, Icons.photo_camera_rounded, 'Take a Photo',
                  () => _pick(ImageSource.camera)),
              _row(ctx, Icons.photo_library_rounded, 'Choose from Gallery',
                  () => _pick(ImageSource.gallery)),
              if (widget.store.avatarPath != null)
                _row(ctx, Icons.delete_outline_rounded, 'Remove Portrait',
                    () => widget.store.setAvatarPath(null),
                    danger: true),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext ctx, IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final color = danger ? const Color(0xFFE57373) : Colors.white;
    return ListTile(
      leading: Icon(icon, color: danger ? color : Dungeon.azure),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      onTap: () {
        Navigator.of(ctx).pop();
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.store.avatarPath;
    final hasPhoto = path != null && File(path).existsSync();
    return GestureDetector(
      onTap: _openSheet,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.45),
          border: Border.all(color: Dungeon.gold.withValues(alpha: 0.6), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: _busy
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Dungeon.gold),
              )
            : hasPhoto
                ? Image.file(File(path), fit: BoxFit.cover)
                : Icon(Icons.person_rounded,
                    color: Dungeon.gold.withValues(alpha: 0.8),
                    size: widget.size * 0.6),
      ),
    );
  }
}
