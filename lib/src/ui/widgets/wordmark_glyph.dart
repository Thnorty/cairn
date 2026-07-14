import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

/// The tiny stacked-blob brand mark that always sits beside the "Cairn"
/// wordmark text: three rounded, tapering blobs in ink tones (not the
/// tan-stone [CairnStack] illustration used for task progress elsewhere).
///
/// Shared between [AppShell]'s interim placeholder-tab header and each real
/// screen's own header (Home's brand row is the first; Trail/Stats/Profile
/// use a different header layout entirely per their own design files, so
/// this glyph - not a whole header widget - is what's actually common
/// between them).
class WordmarkGlyph extends StatelessWidget {
  const WordmarkGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 38,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _blob(11, 8, AppColors.inkDimmed),
          const SizedBox(height: 1),
          _blob(17, 9, AppColors.iconMuted),
          const SizedBox(height: 1),
          _blob(24, 10, AppColors.inkStrong),
        ],
      ),
    );
  }

  Widget _blob(double width, double height, Color color) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height),
      ),
    );
  }
}
