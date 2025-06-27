import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OTPVerificationPage extends StatefulWidget {
  final String email;
  final String password;
  final VoidCallback? onVerified;

  const OTPVerificationPage({
    super.key,
    required this.email,
    required this.password,
    this.onVerified,
  });

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;

  static const String baseUrl = 'https://fondify.ai/api';

  @override
  void initState() {
    super.initState();
    // Automatically send OTP when page loads
    _sendOTP();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final url = Uri.parse('$baseUrl/auth/send-otp/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _successMessage = 'OTP sent to ${widget.email}';
        });
      } else {
        try {
          final data = jsonDecode(response.body);
          setState(() {
            _errorMessage =
                data['detail']?.toString() ??
                data['message']?.toString() ??
                'Failed to send OTP';
          });
        } catch (e) {
          setState(() {
            _errorMessage =
                'Failed to send OTP. Status: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please try again.';
      });
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = Uri.parse('$baseUrl/auth/verify-otp/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'otp': _otpController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email verified successfully! You can now try signing in.',
            ),
            duration: Duration(seconds: 3),
          ),
        );

        if (widget.onVerified != null) {
          widget.onVerified!();
        } else {
          Navigator.of(context).pop(); // Go back to sign in
        }
      } else {
        try {
          final data = jsonDecode(response.body);
          setState(() {
            _errorMessage =
                data['detail']?.toString() ??
                data['message']?.toString() ??
                'Invalid OTP';
          });
        } catch (e) {
          setState(() {
            _errorMessage = 'Invalid OTP. Status: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3A2313)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verify Your Email',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 28,
                color: Color(0xFF3A2313),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'We sent a verification code to ${widget.email}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 40),

            // OTP Field
            const Text(
              'Verification Code',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Color(0xFF3A2313),
                letterSpacing: 2,
              ),
              decoration: const InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(color: Color(0xFF888888)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(top: 8, bottom: 4),
                counterText: '',
              ),
            ),
            Container(
              height: 2,
              color: const Color(0xFF3A2313).withOpacity(0.3),
            ),
            const SizedBox(height: 24),

            // Success/Error Messages
            if (_successMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _successMessage!,
                  style: const TextStyle(color: Colors.green),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Verify Button
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A2313),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: _isLoading ? null : _verifyOTP,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'VERIFY',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Resend OTP
            Center(
              child: TextButton(
                onPressed: _isResending ? null : _sendOTP,
                child: _isResending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Color(0xFF3A2313),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Resend Code',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF3A2313),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
