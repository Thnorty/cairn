import 'package:flutter/material.dart'
    show InputDecoration, TextField, TextInputAction;
import 'package:flutter/services.dart'
    show LengthLimitingTextInputFormatter, TextCapitalization;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../account/account_chrome.dart' show AccountFieldSurface;
import '../proof/verification_chrome.dart'
    show CloseCircleButton, percentPositionToAlignment;
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import 'onboarding_background.dart';
import 'onboarding_header.dart';

/// `Cairn Onboarding Name.dc.html`: the "Your name" step, collecting a
/// REQUIRED local display name so Home's greeting ("Good morning, Sam") and
/// its avatar initial ("S") have something real to show instead of the
/// [AppLocalizations.fallbackDisplayName] stand-in ("Friend"/"F") - see that
/// design file's own long header comment for the full rationale (local
/// `AppSettings` is the source of truth; no account field is ever added for
/// this, per `AccountService`'s own display-name carry-up/adoption logic).
///
/// ONE widget, TWO uses, per the design's own "edit variant" section rather
/// than a second screen:
///  - Onboarding (step 3 of 4, [onBack] given, [onClose] null): back-arrow +
///    4 page dots (the 3rd active), "Continue", no pre-fill, no skip
///    affordance (Continue stays disabled while the field is empty).
///  - Profile's "Your name" edit row ([onClose] given, [onBack] null):
///    close-X, no page dots, "Save", pre-filled with [initialName].
/// Exactly one of [onBack]/[onClose] must be given; that alone decides which
/// variant renders (asserted in the constructor rather than a separate
/// enum/bool flag, so there is exactly one way to make this ambiguous: give
/// neither or both, and the assert catches it immediately).
///
/// The live avatar preview - [AppGradients.accountAvatar], the same 150deg
/// gradient the account-status avatar circles elsewhere in this app already
/// use - is the point of the screen, not decoration: it updates on every
/// keystroke, showing the muted placeholder person glyph while the field is
/// empty and the typed name's first character (uppercased) once there is
/// one.
class OnboardingNameScreen extends ConsumerStatefulWidget {
  const OnboardingNameScreen({
    super.key,
    this.onBack,
    this.onClose,
    required this.onSubmit,
    this.initialName,
  }) : assert(
          (onBack == null) != (onClose == null),
          'OnboardingNameScreen needs exactly one of onBack (onboarding '
          'step, back-arrow + dots) or onClose (Profile edit variant, '
          'close-X, no dots) - never both, never neither.',
        );

  /// Onboarding variant: pops the onboarding flow's nested Navigator back to
  /// the How It Works screen (step 2).
  final VoidCallback? onBack;

  /// Profile edit variant: pops this screen without saving.
  final VoidCallback? onClose;

  /// Called after the trimmed name has been persisted to local settings (and,
  /// when signed in, best-effort pushed to the account's metadata - see
  /// `_handleSubmit`). The onboarding variant advances to Verification (step
  /// 4); the Profile edit variant pops the screen.
  final VoidCallback onSubmit;

  /// Pre-fills the field in the Profile edit variant; left empty (null) for
  /// onboarding, which never has an existing name to prefill.
  final String? initialName;

  /// Whether this is the Profile edit variant (close-X, no dots, "Save")
  /// rather than the onboarding step (back-arrow, 4 dots, "Continue").
  bool get isEditVariant => onClose != null;

  @override
  ConsumerState<OnboardingNameScreen> createState() =>
      _OnboardingNameScreenState();
}

class _OnboardingNameScreenState extends ConsumerState<OnboardingNameScreen> {
  late final _controller = TextEditingController(text: widget.initialName ?? '');
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _trimmedName => _controller.text.trim();

  Future<void> _handleSubmit() async {
    final trimmed = _trimmedName;
    if (trimmed.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(settingsRepositoryProvider).setDisplayName(trimmed);
      ref.invalidate(storedDisplayNameProvider);

      // Best-effort: when already signed in with a real account (primarily
      // the Profile edit path - onboarding is almost always still
      // anonymous), push the new name to the account's metadata too, so it
      // syncs to other devices. A failure here must never block saving the
      // local name, which is what the user actually asked for.
      final auth = ref.read(authServiceProvider);
      if (!auth.isAnonymous) {
        try {
          await auth.setDisplayName(trimmed);
        } catch (_) {
          // Best-effort: see above.
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (!mounted) return;
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.isEditVariant;

    return ModalScaffold(
      // The exact same double sage/clay wash the Welcome and How It Works
      // steps use (Cairn Onboarding Name.dc.html's own inner-screen CSS is
      // byte-for-byte identical to theirs).
      washes: kOnboardingWashes,
      contourOrigin: percentPositionToAlignment(50, -4),
      contourRingColor: AppColors.premiumContourRing,
      child: Column(
        children: [
          isEdit
              ? Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 10, 24, 0),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: CloseCircleButton(onTap: widget.onClose!),
                  ),
                )
              : OnboardingHeader(activeIndex: 2, onBack: widget.onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(30, 8, 30, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 38),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _AvatarPreview(name: _controller.text),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    l10n.onboardingNameTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.onboardingNameHeadline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.onboardingNameSubhead,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.emptyStateBody,
                  ),
                  const SizedBox(height: 30),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l10n.onboardingNameFieldLabel,
                      style: AppTextStyles.accountFieldLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AccountFieldSurface(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isSaving,
                      autofocus: !isEdit,
                      textCapitalization: TextCapitalization.words,
                      // A LengthLimitingTextInputFormatter (rather than
                      // TextField's own `maxLength`) caps the input without
                      // triggering Flutter's automatic "N/40" counter row,
                      // which has no place in this design.
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(kOnboardingNameMaxLength),
                      ],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _handleSubmit(),
                      style: AppTextStyles.accountFieldInput,
                      decoration: InputDecoration.collapsed(
                        hintText: l10n.onboardingNameFieldHint,
                        hintStyle: AppTextStyles.accountFieldInput.copyWith(
                          color: AppColors.accountPlaceholderText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.fromSTEB(30, 16, 30, 30),
            child: PrimaryButton(
              label: isEdit ? l10n.onboardingNameSaveButton : l10n.onboardingContinueButton,
              onPressed: (_trimmedName.isEmpty || _isSaving) ? null : _handleSubmit,
            ),
          ),
        ],
      ),
    );
  }
}

/// A reasonable input cap: long enough for any real name, short enough that
/// it can never overflow the greeting/avatar it feeds.
const int kOnboardingNameMaxLength = 40;

/// The 86px live avatar preview: [AppGradients.accountAvatar]'s gradient
/// circle showing either the muted placeholder person glyph (empty [name])
/// or the first character of [name], uppercased - the exact same "first
/// character, uppercased" rule `home_screen.dart`'s own `_AvatarCircle`
/// applies to the stored name once saved, so this preview is a faithful
/// rendering of what Home will actually show.
class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        gradient: AppGradients.accountAvatar,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x73453F35), // 0 8px 16px -8px rgba(60,50,35,.45)
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: trimmed.isEmpty
          ? const _PlaceholderPersonGlyph(key: ValueKey('onboarding-name-avatar-placeholder'))
          : Text(
              trimmed[0].toUpperCase(),
              key: const ValueKey('onboarding-name-avatar-initial'),
              style: const TextStyle(
                fontFamily: AppFontFamilies.zillaSlab,
                fontWeight: FontWeight.w600,
                fontSize: 34,
                color: AppColors.inkDimmed,
              ),
            ),
    );
  }
}

/// The muted person-glyph shown in the avatar preview while the name field
/// is empty, reproduced point-for-point from the design's own SVG
/// (`<circle cx="12" cy="8" r="3.6">`, `<path d="M5 20c0-3.8 3.1-6.4 7-6.4s7
/// 2.6 7 6.4">`).
class _PlaceholderPersonGlyph extends StatelessWidget {
  const _PlaceholderPersonGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(painter: _PlaceholderPersonGlyphPainter()),
    );
  }
}

class _PlaceholderPersonGlyphPainter extends CustomPainter {
  const _PlaceholderPersonGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 24;
    final h = size.height / 24;
    final paint = Paint()
      ..color = AppColors.onboardingNamePlaceholderGlyph
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawCircle(Offset(12 * w, 8 * h), 3.6 * w, paint);
    final shoulders = Path()
      ..moveTo(5 * w, 20 * h)
      ..cubicTo(5 * w, 16.2 * h, 8.1 * w, 13.6 * h, 12 * w, 13.6 * h)
      ..cubicTo(15.9 * w, 13.6 * h, 19 * w, 16.2 * h, 19 * w, 20 * h);
    canvas.drawPath(shoulders, paint);
  }

  @override
  bool shouldRepaint(_PlaceholderPersonGlyphPainter oldDelegate) => false;
}
