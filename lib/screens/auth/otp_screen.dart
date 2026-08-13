import 'dart:async';
import 'package:flutter/material.dart';
import 'package:voxa/core/services/auth_service.dart';
import 'package:voxa/screens/home/home_screen.dart';
import 'package:voxa/widgets/auth/auth_gradient_header.dart';
import 'package:voxa/widgets/auth/loading_indicator.dart';

class OTPScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  const OTPScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  late String _currentVerificationId;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startTimer();
  }

  void _startTimer() {
    setState(() => _resendTimer = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        if (mounted) setState(() => _resendTimer--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _verifyOTP() async {
    String smsCode = _otpController.text.trim();
    if (smsCode.length < 6) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithOTP(_currentVerificationId, smsCode);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invalid OTP code")));
      }
    }
  }

  Future<void> _resendCode() async {
    if (_resendTimer > 0 || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _currentVerificationId = verificationId;
            _isLoading = false;
          });
          _startTimer();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("New OTP code sent.")));
        },
        onFailed: (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? "Resend failed.")),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to resend code.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthGradientHeader(title: "Voxa", subtitle: "Enter OTP Code"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text(
                    "We have sent an SMS with a code to ${widget.phoneNumber}.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    maxLength: 6,
                    decoration: const InputDecoration(
                      hintText: "------",
                      counterText: "",
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Color(0xFF128C7E),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Color(0xFF128C7E),
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      if (val.length == 6) _verifyOTP();
                    },
                  ),
                  const SizedBox(height: 40),
                  if (_resendTimer > 0)
                    Text(
                      "Resend code in $_resendTimer seconds",
                      style: const TextStyle(color: Colors.grey),
                    )
                  else
                    TextButton(
                      onPressed: _isLoading ? null : _resendCode,
                      child: const Text(
                        "RESEND CODE",
                        style: TextStyle(
                          color: Color(0xFF128C7E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const LoadingIndicator()
                        : const Text("VERIFY"),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
