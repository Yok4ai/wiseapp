import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  
  // Multi-step flow
  int _currentStep = 1; // 1: Email, 2: OTP, 3: New Password
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  
  // BASE_URL sourced from Lorerocca.postman_collection.json
  static const String baseUrl = 'https://fondify.ai/api';

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    
    final url = Uri.parse('$baseUrl/auth/send-otp/');
    try {
      print('Sending OTP to: ${_emailController.text.trim()}');
      print('URL: $url');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );
      
      print('Send OTP response: ${response.statusCode} ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _currentStep = 2; // Move to OTP verification step
          _successMessage = 'OTP sent to ${_emailController.text.trim()}';
        });
      } else {
        try {
          final data = jsonDecode(response.body);
          setState(() {
            _errorMessage = _extractErrorMessage(data) ?? 'Failed to send OTP. Status: ${response.statusCode}';
          });
        } catch (e) {
          setState(() {
            _errorMessage = 'Failed to send OTP. Status: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      print('Send OTP error: $e');
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final url = Uri.parse('$baseUrl/auth/verify-otp/');
    try {
      print('Verifying OTP for: ${_emailController.text.trim()}');
      print('OTP: ${_otpController.text.trim()}');
      print('URL: $url');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'otp': _otpController.text.trim(),
        }),
      );

      print('Verify OTP response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _currentStep = 3; // Move to password reset step
          _successMessage = 'OTP verified! Now set your new password.';
        });
      } else {
        try {
          final data = jsonDecode(response.body);
          setState(() {
            _errorMessage = _extractErrorMessage(data) ?? 'Invalid OTP. Status: ${response.statusCode}';
          });
        } catch (e) {
          setState(() {
            _errorMessage = 'Invalid OTP. Status: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      print('Verify OTP error: $e');
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a new password';
      });
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    if (_newPasswordController.text.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters long';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final url = Uri.parse('$baseUrl/auth/reset-password/');
    try {
      print('Resetting password for: ${_emailController.text.trim()}');
      print('URL: $url');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _newPasswordController.text,
        }),
      );

      print('Reset password response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Password reset successful
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successful! You can now sign in with your new password.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(); // Go back to sign in page
      } else {
        try {
          final data = jsonDecode(response.body);
          setState(() {
            _errorMessage = _extractErrorMessage(data) ?? 'Failed to reset password. Status: ${response.statusCode}';
          });
        } catch (e) {
          setState(() {
            _errorMessage = 'Failed to reset password. Status: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      print('Reset password error: $e');
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _goBack() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
        _successMessage = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  String? _extractErrorMessage(dynamic data) {
    try {
      if (data == null) return null;
      
      // Handle different error response formats
      if (data is Map<String, dynamic>) {
        // Try common error fields
        if (data['detail'] != null) {
          if (data['detail'] is String) {
            return data['detail'];
          } else if (data['detail'] is List) {
            return (data['detail'] as List).join('\n');
          } else if (data['detail'] is Map) {
            // Handle nested error objects
            return data['detail'].toString();
          }
        }
        
        if (data['message'] != null) {
          return data['message'].toString();
        }
        
        if (data['error'] != null) {
          if (data['error'] is String) {
            return data['error'];
          } else if (data['error'] is Map) {
            return data['error'].toString();
          }
        }
        
        // If it's a validation error with field-specific errors
        if (data['errors'] != null) {
          if (data['errors'] is Map) {
            final errors = data['errors'] as Map<String, dynamic>;
            final errorMessages = <String>[];
            errors.forEach((field, messages) {
              if (messages is List) {
                errorMessages.addAll(messages.map((e) => '$field: $e'));
              } else {
                errorMessages.add('$field: $messages');
              }
            });
            return errorMessages.join('\n');
          }
        }
      }
      
      // If it's a string, return it directly
      if (data is String) {
        return data;
      }
      
      // Fallback: convert to string
      return data.toString();
    } catch (e) {
      print('Error extracting message: $e');
      return null;
    }
  }

  String _getHeaderTitle() {
    switch (_currentStep) {
      case 1:
        return 'Forgot Password';
      case 2:
        return 'Verify OTP';
      case 3:
        return 'Reset Password';
      default:
        return 'Forgot Password';
    }
  }

  String _getHeaderSubtitle() {
    switch (_currentStep) {
      case 1:
        return 'Enter your email to reset your password';
      case 2:
        return 'Enter the OTP sent to your email';
      case 3:
        return 'Create a new secure password';
      default:
        return 'Enter your email to reset your password';
    }
  }

  String _getButtonText() {
    switch (_currentStep) {
      case 1:
        return 'SEND OTP';
      case 2:
        return 'VERIFY OTP';
      case 3:
        return 'RESET PASSWORD';
      default:
        return 'NEXT';
    }
  }

  VoidCallback? _getButtonAction() {
    switch (_currentStep) {
      case 1:
        return _sendOtp;
      case 2:
        return _verifyOtp;
      case 3:
        return _resetPassword;
      default:
        return null;
    }
  }

  List<Widget> _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildEmailStep();
      case 2:
        return _buildOtpStep();
      case 3:
        return _buildPasswordStep();
      default:
        return _buildEmailStep();
    }
  }

  List<Widget> _buildEmailStep() {
    return [
      const Text(
        'Email',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 16,
          color: Colors.black,
        ),
      ),
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: Color(0xFF888888),
        ),
        decoration: const InputDecoration(
          hintText: 'john@email.com',
          hintStyle: TextStyle(color: Color(0xFF888888)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(top: 8, bottom: 4),
        ),
      ),
      Container(
        height: 1,
        color: const Color(0xFFC1C1C1).withOpacity(0.87),
      ),
    ];
  }

  List<Widget> _buildOtpStep() {
    return [
      Text(
        'Verification Code sent to ${_emailController.text.trim()}',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: Color(0xFF666666),
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Enter Code',
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
      const SizedBox(height: 16),
      Center(
        child: TextButton(
          onPressed: _isLoading ? null : () async {
            setState(() {
              _currentStep = 1; // Go back to email step to resend
              _otpController.clear();
              _errorMessage = null;
              _successMessage = null;
            });
          },
          child: const Text(
            'Resend OTP',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF3A2313),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildPasswordStep() {
    return [
      const Text(
        'New Password',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 16,
          color: Colors.black,
        ),
      ),
      TextField(
        controller: _newPasswordController,
        obscureText: _obscureNewPassword,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: Color(0xFF888888),
        ),
        decoration: InputDecoration(
          hintText: '••••••••',
          hintStyle: const TextStyle(color: Color(0xFF888888)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(top: 8, bottom: 4),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _obscureNewPassword = !_obscureNewPassword;
              });
            },
          ),
        ),
      ),
      Container(
        height: 1,
        color: const Color(0xFFC1C1C1).withOpacity(0.87),
      ),
      const SizedBox(height: 24),
      const Text(
        'Confirm Password',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 16,
          color: Colors.black,
        ),
      ),
      TextField(
        controller: _confirmPasswordController,
        obscureText: _obscureConfirmPassword,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: Color(0xFF888888),
        ),
        decoration: InputDecoration(
          hintText: '••••••••',
          hintStyle: const TextStyle(color: Color(0xFF888888)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(top: 8, bottom: 4),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
        ),
      ),
      Container(
        height: 1,
        color: const Color(0xFFC1C1C1).withOpacity(0.87),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final double headerHeight = MediaQuery.of(context).size.height * 0.32;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Gradient header with Star background
          Container(
            height: headerHeight,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3A2313), Color(0xFF9E8264)],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset('assets/Star.png', fit: BoxFit.cover),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        _getHeaderTitle(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 32,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getHeaderSubtitle(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // White card with form
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              transform: Matrix4.translationValues(
                0,
                -56,
                0,
              ), // ← ADDED (moved up 56px)
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Step content based on current step
                    ..._buildStepContent(),
                    const SizedBox(height: 32),
                    // Action Button
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
                        onPressed: _isLoading ? null : _getButtonAction(),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _getButtonText(),
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                    // Messages
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
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
                    ],
                    if (_successMessage != null) ...[
                      const SizedBox(height: 12),
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
                    ],
                    const SizedBox(height: 24),
                    // Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _goBack,
                          child: Text(
                            _currentStep > 1 ? 'Back' : 'Back to Sign In',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Color(0xFF3A2313),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
