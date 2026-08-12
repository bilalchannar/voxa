import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firebase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/firebase_error_mapper.dart';
import '../../widgets/auth/loading_indicator.dart';

enum _Step { enterNumber, enterCode }

class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  String _countryCode = '+92';
  _Step _step = _Step.enterNumber;
  String? _verificationId;
  String _pendingNumber = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendCode() async {
    final local = _phoneController.text.trim();
    if (local.isEmpty) {
      _snack('Please enter a phone number.');
      return;
    }
    final fullNumber = '$_countryCode$local';
    setState(() => _isLoading = true);

    await _authService.verifyNewPhoneNumber(
      phoneNumber: fullNumber,
      onCodeSent: (verificationId, _) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _verificationId = verificationId;
          _pendingNumber = fullNumber;
          _step = _Step.enterCode;
        });
      },
      onFailed: (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _snack(FirebaseErrorMapper.message(e, context: 'verifyNewPhoneNumber'));
      },
    );
  }

  Future<void> _verifyAndUpdate() async {
    final code = _codeController.text.trim();
    final verificationId = _verificationId;
    if (verificationId == null) return;
    if (code.length < 6) {
      _snack('Please enter the 6-digit code.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.updatePhoneCredential(
        verificationId: verificationId,
        smsCode: code,
      );
      await _firebaseService.updatePhoneNumber(_pendingNumber);
      if (!mounted) return;
      _snack('Phone number updated.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack(FirebaseErrorMapper.message(e, context: 'updatePhoneCredential'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack(FirebaseErrorMapper.message(e, context: 'updatePhoneNumber'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentNumber = _authService.currentUser?.phoneNumber;
    return Scaffold(
      appBar: AppBar(title: const Text('Change Number')),
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.secondary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Changing your number will verify the new one by SMS and '
                      'update your Voxa account. Your current number is '
                      '${(currentNumber != null && currentNumber.isNotEmpty) ? currentNumber : "unknown"}.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (_step == _Step.enterNumber)
              _buildEnterNumber()
            else
              _buildEnterCode(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterNumber() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Country',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.secondary, width: 1.5),
            ),
          ),
          child: CountryCodePicker(
            onChanged: (c) {
              if (c.dialCode != null) {
                setState(() => _countryCode = c.dialCode!);
              }
            },
            initialSelection: 'PK',
            favorite: const ['+92', 'PK'],
            showOnlyCountryWhenClosed: true,
            alignLeft: true,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'New phone number',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 80,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.secondary, width: 1.5),
                ),
              ),
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _countryCode,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'phone number',
                  contentPadding: EdgeInsets.only(bottom: 12),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.secondary,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.secondary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        _primaryButton(
          label: 'SEND CODE',
          onPressed: _isLoading ? null : _sendCode,
        ),
      ],
    );
  }

  Widget _buildEnterCode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the 6-digit code sent to $_pendingNumber',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: const InputDecoration(
            hintText: '------',
            counterText: '',
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.secondary, width: 1.5),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.secondary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 36),
        _primaryButton(
          label: 'VERIFY & UPDATE',
          onPressed: _isLoading ? null : _verifyAndUpdate,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  _codeController.clear();
                  setState(() {
                    _step = _Step.enterNumber;
                    _verificationId = null;
                  });
                },
          child: const Text(
            'Use a different number',
            style: TextStyle(color: AppColors.secondary),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton({required String label, VoidCallback? onPressed}) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isLoading
            ? const LoadingIndicator()
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
