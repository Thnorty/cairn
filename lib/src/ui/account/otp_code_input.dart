import 'package:flutter/material.dart'
    show InputBorder, InputDecoration, TextField;
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_text_styles.dart';

/// The 6-box OTP code entry used by the Enter Code screen (verify-email
/// and password-reset purposes alike): one text field per digit, with
/// auto-advance to the next box on entry and auto-back to the previous box
/// when a box is cleared (backspaced). Reports the assembled code (as typed
/// so far, possibly shorter than [length]) via [onChanged] on every
/// keystroke.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.autofocus = true,
  });

  final int length;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(_controllers.map((c) => c.text).join());
  }

  void _handleChanged(int index, String value) {
    if (value.length > 1) {
      // A paste of multiple characters into one box: distribute one digit
      // per remaining box rather than overflowing this one.
      final chars = value.split('');
      for (var i = 0; i < chars.length && index + i < widget.length; i++) {
        _controllers[index + i].text = chars[i];
      }
      final nextIndex = (index + chars.length).clamp(0, widget.length - 1);
      _focusNodes[nextIndex].requestFocus();
    } else if (value.isNotEmpty) {
      if (index + 1 < widget.length) {
        _focusNodes[index + 1].requestFocus();
      }
    } else if (index > 0) {
      // Backspaced this box back to empty: hop back so the next keystroke
      // lands in the previous box, matching a standard OTP input's feel.
      _focusNodes[index - 1].requestFocus();
    }
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          if (i > 0) const SizedBox(width: 9),
          _OtpBox(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            autofocus: widget.autofocus && i == 0,
            onChanged: (value) => _handleChanged(i, value),
          ),
        ],
      ],
    );
  }
}

class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.autofocus,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final ValueChanged<String> onChanged;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final active = widget.focusNode.hasFocus;
    return GestureDetector(
      onTap: () => widget.focusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppGradients.premiumBg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: active
                ? AppColors.accountSageButtonLight
                : AppColors.panelBorder,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: AppColors.accountOtpActiveRing,
                    blurRadius: 3,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTextStyles.otpDigit,
          decoration: const InputDecorationForOtp(),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

/// A borderless [InputDecoration] with no counter text (the default
/// `maxLength` counter would otherwise print a stray "0/1"/"1/1" under
/// every box) and no content padding, so a single digit centers cleanly in
/// the fixed 46x56 box.
class InputDecorationForOtp extends InputDecoration {
  const InputDecorationForOtp()
      : super(
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.zero,
          isDense: true,
        );
}
