import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:voxa/core/services/auth_service.dart';
import 'package:voxa/screens/auth/otp_screen.dart';
import 'package:voxa/widgets/auth/auth_gradient_header.dart';
import 'package:voxa/widgets/auth/loading_indicator.dart';

class _PakistanLengthLimitingFormatter extends TextInputFormatter {
  final String Function() getCountryCode;

  _PakistanLengthLimitingFormatter(this.getCountryCode);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (getCountryCode() == '+92') {
      final text = newValue.text;
      int maxLen = 10;
      if (text.startsWith('0')) {
        maxLen = 11;
      }
      if (text.length > maxLen) {
        return oldValue;
      }
    }
    return newValue;
  }
}

class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  String _countryCode = "+92";
  bool _isLoading = false;
  String? _errorMessage;
  bool _isValid = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _validatePhoneNumber() {
    final raw = _phoneController.text.trim();

    if (raw.isEmpty) {
      setState(() {
        _errorMessage = null;
        _isValid = false;
      });
      return;
    }

    if (_countryCode == '+92') {
      String cleaned = raw;
      if (cleaned.startsWith('0')) {
        cleaned = cleaned.substring(1);
      }

      if (cleaned.isEmpty) {
        setState(() {
          _errorMessage = 'Enter a valid mobile number';
          _isValid = false;
        });
        return;
      }

      final firstChar = cleaned.substring(0, 1);
      if (firstChar != '3') {
        setState(() {
          _errorMessage = 'Mobile number must start with 3';
          _isValid = false;
        });
        return;
      }

      if (cleaned.length < 10) {
        setState(() {
          _errorMessage = 'Enter a valid mobile number';
          _isValid = false;
        });
        return;
      }

      if (cleaned.length == 10) {
        setState(() {
          _errorMessage = null;
          _isValid = true;
        });
        return;
      }

      if (cleaned.length > 10) {
        setState(() {
          _errorMessage = 'Enter a valid mobile number';
          _isValid = false;
        });
        return;
      }
    } else {
      if (raw.length >= 7 && raw.length <= 15) {
        setState(() {
          _errorMessage = null;
          _isValid = true;
        });
        return;
      } else {
        setState(() {
          _errorMessage = 'Enter a valid phone number';
          _isValid = false;
        });
        return;
      }
    }
  }

  void _verifyPhoneNumber() async {
    _validatePhoneNumber();
    if (!_isValid) {
      if (_phoneController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Enter a valid mobile number';
        });
      }
      return;
    }

    String cleanNumber = _phoneController.text.trim();
    if (_countryCode == '+92') {
      if (cleanNumber.startsWith('0')) {
        cleanNumber = cleanNumber.substring(1);
      }
    }

    setState(() {
      _isLoading = true;
    });

    await _authService.verifyPhoneNumber(
      phoneNumber: "$_countryCode$cleanNumber",
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPScreen(
              verificationId: verificationId,
              phoneNumber: "$_countryCode$cleanNumber",
            ),
          ),
        );
      },
      onFailed: (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Authentication failed.")),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthGradientHeader(
              title: "Voxa",
              subtitle: "Verify your phone number",
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    "Voxa will need to verify your phone number.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFF128C7E),
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: CountryCodePicker(
                      onChanged: (country) {
                        setState(() {
                          _countryCode = country.dialCode!;
                        });
                        _validatePhoneNumber();
                      },
                      initialSelection: 'PK',
                      favorite: const ['+92', 'PK'],
                      showOnlyCountryWhenClosed: true,
                      alignLeft: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 80,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFF128C7E),
                              width: 1.5,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _countryCode,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 18),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _PakistanLengthLimitingFormatter(() => _countryCode),
                          ],
                          onChanged: (val) {
                            _validatePhoneNumber();
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.only(bottom: 12),
                            hintText: 'phone number',
                            errorText: _errorMessage,
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Color(0xFF128C7E),
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Color(0xFF128C7E),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyPhoneNumber,
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
                        : const Text("NEXT"),
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
