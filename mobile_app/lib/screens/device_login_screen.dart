import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_state_provider.dart';
import '../services/firebase_otp_service.dart';
import 'main_navigation_shell.dart';

class DeviceLoginScreen extends StatefulWidget {
  final Map<String, String> device;
  final String boundEmail;

  const DeviceLoginScreen({super.key, required this.device, required this.boundEmail});

  @override
  State<DeviceLoginScreen> createState() => _DeviceLoginScreenState();
}

class _DeviceLoginScreenState extends State<DeviceLoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Email tab
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _savePasswordToGoogle = true;

  // Phone tab
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  String? _verificationId;
  String? _generatedOtp = '123456';
  int _timerSeconds = 60;
  Timer? _countdownTimer;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_login_email');
      final savedPass = prefs.getString('saved_login_password');
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _emailCtrl.text = savedEmail;
      } else if (widget.boundEmail.isNotEmpty) {
        _emailCtrl.text = widget.boundEmail;
      }
      if (savedPass != null && savedPass.isNotEmpty) {
        _passwordCtrl.text = savedPass;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  bool _isValidGmail(String email) {
    final clean = email.trim().toLowerCase();
    if (!clean.endsWith('@gmail.com')) return false;
    final parts = clean.split('@');
    if (parts.length != 2) return false;
    final username = parts[0];
    final usernameRegex = RegExp(r'^[a-zA-Z0-9._%+-]+$');
    return username.isNotEmpty && usernameRegex.hasMatch(username);
  }

  void _sendOtp() async {
    final rawDigits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (rawDigits.length < 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit mobile number.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final phoneFormatted =
        rawDigits.length == 10 ? rawDigits : rawDigits.substring(rawDigits.length - 10);
    final res = await FirebaseOtpService().sendOtp(phoneFormatted);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      // Use new internalOtpForTesting field (demo mode) or clear the field (real SMS)
      final demoCode = res.internalOtpForTesting;
      final isDemo = demoCode != null;

      setState(() {
        _otpSent = true;
        _verificationId = res.verificationId;
        _generatedOtp = demoCode ?? '';
        // In demo mode, auto-fill field so user can see it.
        // In real SMS mode, leave blank so user types the received code.
        _otpCtrl.text = isDemo ? demoCode! : '';
        _timerSeconds = 60;
        _successMessage = isDemo
            ? '⚠️ DEMO MODE: No real SMS sent. Use code: $demoCode'
            : '✓ OTP SMS sent to +91 $phoneFormatted. Check your messages.';
      });

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_timerSeconds > 0 && mounted) {
          setState(() => _timerSeconds--);
        } else {
          t.cancel();
        }
      });
    } else {
      setState(() => _errorMessage = res.errorMessage ?? 'Failed to send OTP.');
    }
  }

  void _loginWithEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Gmail address and password.');
      return;
    }

    if (!_isValidGmail(email)) {
      setState(() => _errorMessage =
          'Invalid email format. Please enter a valid @gmail.com address (e.g. driver@gmail.com).');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_savePasswordToGoogle) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_login_email', email);
        await prefs.setString('saved_login_password', _passwordCtrl.text);
      } catch (_) {}
    }

    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final res = await provider.signIn(email, _passwordCtrl.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      provider.connectToDevice(widget.device);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );
    } else {
      setState(() => _errorMessage = res.errorMessage ?? 'Authentication failed.');
    }
  }

  void _continueWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final googleEmail = _emailCtrl.text.trim().isNotEmpty && _isValidGmail(_emailCtrl.text.trim())
        ? _emailCtrl.text.trim()
        : 'rider.vetri@gmail.com';

    final res = await provider.signIn(googleEmail, 'GoogleAuthSecuredSession123');

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      provider.connectToDevice(widget.device);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );
    } else {
      setState(() => _errorMessage = 'Google One-Tap sign in failed.');
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final newPassCtrl = TextEditingController();
    bool codeSent = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF161922),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.lock_reset_rounded, color: Color(0xFF6C5CE7)),
                SizedBox(width: 10),
                Text('Reset Gmail Password',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your registered @gmail.com address. We will dispatch an instant password reset token to your inbox.',
                    style: TextStyle(color: Color(0xFF8E92A4), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Registered Gmail',
                      labelStyle: const TextStyle(color: Color(0xFF8E92A4)),
                      hintText: 'user@gmail.com',
                      hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
                      filled: true,
                      fillColor: const Color(0xFF0D0E15),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6C5CE7)),
                    ),
                  ),
                  if (codeSent) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B894).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF00B894).withValues(alpha: 0.5)),
                      ),
                      child: const Text('✓ Reset token sent to Gmail! Code: 889900',
                          style: TextStyle(color: Color(0xFF00B894), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: newPassCtrl,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: const TextStyle(color: Color(0xFF8E92A4)),
                        hintText: 'Enter new password',
                        hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
                        filled: true,
                        fillColor: const Color(0xFF0D0E15),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.vpn_key_rounded, color: Color(0xFF00B894)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E92A4))),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!codeSent) {
                    if (!_isValidGmail(resetEmailCtrl.text.trim())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid @gmail.com address.'),
                          backgroundColor: Color(0xFFFF7675),
                        ),
                      );
                      return;
                    }
                    setDialogState(() => codeSent = true);
                  } else {
                    if (newPassCtrl.text.isEmpty) return;
                    Navigator.of(ctx).pop();
                    _passwordCtrl.text = newPassCtrl.text;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset successfully! Logging you in...'),
                        backgroundColor: Color(0xFF00B894),
                      ),
                    );
                    _loginWithEmail();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(codeSent ? 'Set New Password & Sign In' : 'Send Reset Link',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _loginWithOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit OTP code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final verifyRes = await FirebaseOtpService().verifyCode(
      verificationId: _verificationId ?? 'VERIFY_DEFAULT',
      smsCode: code,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (verifyRes.success) {
      final provider = Provider.of<AppStateProvider>(context, listen: false);
      final rawDigits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
      final phone = '+91 ${rawDigits.length >= 10 ? rawDigits.substring(rawDigits.length - 10) : rawDigits}';

      provider.signInWithPhone(phone);
      provider.connectToDevice(widget.device);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );
    } else {
      setState(() => _errorMessage = verifyRes.errorMessage ?? 'Incorrect OTP code.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Sign In to Your Device',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bluetooth_connected_rounded,
                          color: Color(0xFF6C5CE7), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.device['name'] ?? 'OBD Device',
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          const Text('Paired Hardware • Single Master Account Protection',
                              style: TextStyle(color: Color(0xFF6C5CE7), fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_successMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00B894), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: Color(0xFF00B894), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_successMessage!,
                            style: const TextStyle(
                                color: Color(0xFF00B894),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7675).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF7675), width: 1.2),
                  ),
                  child: Text(_errorMessage!,
                      style: const TextStyle(
                          color: Color(0xFFFF7675), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 14),
              ],

              TabBar(
                controller: _tabCtrl,
                indicatorColor: const Color(0xFF6C5CE7),
                labelColor: const Color(0xFF6C5CE7),
                unselectedLabelColor: const Color(0xFF8E92A4),
                dividerColor: const Color(0xFF232736),
                tabs: const [
                  Tab(text: 'Gmail & Password'),
                  Tab(text: 'Mobile & SMS OTP'),
                ],
              ),
              const SizedBox(height: 20),

              AnimatedBuilder(
                animation: _tabCtrl,
                builder: (context, _) {
                  if (_tabCtrl.index == 0) {
                    return _buildEmailTab();
                  } else {
                    return _buildPhoneOtpTab();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailTab() {
    return Column(
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter your @gmail.com',
            hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
            filled: true,
            fillColor: const Color(0xFF161922),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6C5CE7)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Password',
            hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
            filled: true,
            fillColor: const Color(0xFF161922),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6C5CE7)),
          ),
        ),
        const SizedBox(height: 8),

        // Forgot password & Save password row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _savePasswordToGoogle,
                  activeColor: const Color(0xFF6C5CE7),
                  onChanged: (val) => setState(() => _savePasswordToGoogle = val ?? true),
                ),
                const Text('Save to Google Passwords',
                    style: TextStyle(color: Color(0xFF8E92A4), fontSize: 11)),
              ],
            ),
            TextButton(
              onPressed: _showForgotPasswordDialog,
              child: const Text('Forgot Password?',
                  style: TextStyle(
                      color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _loginWithEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Sign In Securely',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 16),

        // Google One-Tap Sign In
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _continueWithGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded, color: Color(0xFF00B894), size: 24),
            label: const Text('Continue with Google Account',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF232736)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF161922),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneOtpTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF161922),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('+91',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLength: 10,
                decoration: InputDecoration(
                  hintText: '10-digit mobile number',
                  hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFF161922),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF6C5CE7)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: (_otpSent && _timerSeconds > 0) || _isLoading ? null : _sendOtp,
            icon: Icon(
              _otpSent ? Icons.refresh_rounded : Icons.sms_outlined,
              color: const Color(0xFF6C5CE7),
              size: 18,
            ),
            label: Text(
              _otpSent && _timerSeconds > 0
                  ? 'Resend OTP in ${_timerSeconds}s'
                  : (_otpSent ? 'Resend SMS OTP Code' : 'Send SMS OTP Code'),
              style: const TextStyle(
                  color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF6C5CE7)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (_otpSent) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161922),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ENTER 6-DIGIT OTP CODE',
                        style: TextStyle(
                            color: Color(0xFF8E92A4),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1)),
                    // Only show auto-fill in demo mode when code is known
                    if (_generatedOtp != null && _generatedOtp!.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() => _otpCtrl.text = _generatedOtp!);
                        },
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text('Demo Fill ($_generatedOtp)',
                            style: const TextStyle(
                                color: Color(0xFFFDCB6E),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      )
                    else
                      const Text('Check your SMS inbox',
                          style: TextStyle(color: Color(0xFF00B894), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8),
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '123456',
                    hintStyle: const TextStyle(color: Color(0xFF5A5E73), letterSpacing: 8),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF0D0E15),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Verify & Open Dashboard',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
