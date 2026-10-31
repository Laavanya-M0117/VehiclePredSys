import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/firebase_otp_service.dart';
import 'main_navigation_shell.dart';

class DeviceRegistrationScreen extends StatefulWidget {
  final Map<String, String> device;
  const DeviceRegistrationScreen({super.key, required this.device});

  @override
  State<DeviceRegistrationScreen> createState() => _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _phoneNameCtrl = TextEditingController();
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
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _phoneNameCtrl.dispose();
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

    final phoneFormatted = rawDigits.length == 10 ? rawDigits : rawDigits.substring(rawDigits.length - 10);
    final res = await FirebaseOtpService().sendOtp(phoneFormatted);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      final demoCode = res.internalOtpForTesting;
      final isDemo = demoCode != null;
      setState(() {
        _otpSent = true;
        _verificationId = res.verificationId;
        _generatedOtp = demoCode ?? '';
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

  void _registerWithEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'Gmail and password are required.');
      return;
    }

    if (!_isValidGmail(email)) {
      setState(() => _errorMessage =
          'Invalid email address. Please enter a valid @gmail.com address (e.g. driver@gmail.com).');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final res = await provider.signUp(email, _passwordCtrl.text, displayName: _nameCtrl.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      final devId = widget.device['id'] ?? 'unknown';
      final rawDigits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
      final phone = rawDigits.length >= 10 ? '+91 ' + rawDigits.substring(rawDigits.length - 10) : '';
      provider.bindDevice(devId, email, displayName: _nameCtrl.text.trim(), email: email, phone: phone);
      provider.connectToDevice(widget.device);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );
    } else {
      setState(() => _errorMessage = res.errorMessage ?? 'Registration failed.');
    }
  }

  void _registerWithOtp() async {
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
      verificationId: _verificationId ?? 'VERIFY_REG_DEFAULT',
      smsCode: code,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (verifyRes.success) {
      final provider = Provider.of<AppStateProvider>(context, listen: false);
      final rawDigits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
      final phone = '+91 ${rawDigits.length >= 10 ? rawDigits.substring(rawDigits.length - 10) : rawDigits}';
      final name = _phoneNameCtrl.text.trim().isNotEmpty ? _phoneNameCtrl.text.trim() : 'VETRI Rider';

      provider.signInWithPhone(phone, displayName: name);
      final devId = widget.device['id'] ?? 'unknown';
      final email = _emailCtrl.text.trim();
      provider.bindDevice(devId, phone, displayName: name, email: email, phone: phone);
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
        title: const Text('Register OBD Device',
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
                  border: Border.all(color: const Color(0xFF00B894).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B894).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bluetooth_searching_rounded,
                          color: Color(0xFF00B894), size: 22),
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
                          const Text('Unclaimed Device — Create your secure master account',
                              style: TextStyle(color: Color(0xFF00B894), fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDCB6E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDCB6E).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.shield_outlined, color: Color(0xFFFDCB6E), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '1 Device = 1 Verified Account policy. This OBD hardware will bind securely to your account.',
                        style: TextStyle(color: Color(0xFFFDCB6E), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

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
                indicatorColor: const Color(0xFF00B894),
                labelColor: const Color(0xFF00B894),
                unselectedLabelColor: const Color(0xFF8E92A4),
                dividerColor: const Color(0xFF232736),
                tabs: const [
                  Tab(text: 'Gmail Registration'),
                  Tab(text: 'Mobile & SMS OTP'),
                ],
              ),
              const SizedBox(height: 18),

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
          controller: _nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Full Name (e.g. John Doe)',
            hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
            filled: true,
            fillColor: const Color(0xFF161922),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF00B894)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'user@gmail.com',
            hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
            filled: true,
            fillColor: const Color(0xFF161922),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF00B894)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Mobile Number (10 digits for SMS & Lock)',
            hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
            filled: true,
            fillColor: const Color(0xFF161922),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF00B894)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Create Password',
            hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
            filled: true,
            fillColor: const Color(0xFF161922),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF00B894)),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _registerWithEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B894),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Register & Bind Device',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneOtpTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _phoneNameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Your Name (e.g. Rahul Sharma)',
            hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
            filled: true,
            fillColor: const Color(0xFF161922),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF00B894)),
          ),
        ),
        const SizedBox(height: 12),
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
                  prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF00B894)),
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
              color: const Color(0xFF00B894),
              size: 18,
            ),
            label: Text(
              _otpSent && _timerSeconds > 0
                  ? 'Resend OTP in ${_timerSeconds}s'
                  : (_otpSent ? 'Resend SMS OTP' : 'Send Registration OTP'),
              style: const TextStyle(
                  color: Color(0xFF00B894), fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00B894)),
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
              border: Border.all(color: const Color(0xFF00B894).withValues(alpha: 0.4)),
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
                    TextButton(
                      onPressed: () {
                        setState(() => _otpCtrl.text = _generatedOtp ?? '123456');
                      },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text('Auto-Fill (${_generatedOtp ?? '123456'})',
                          style: const TextStyle(
                              color: Color(0xFF00B894),
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
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
                    onPressed: _isLoading ? null : _registerWithOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B894),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Verify & Bind Master Device',
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
