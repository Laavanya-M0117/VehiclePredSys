import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import 'ble_pairing_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController(text: 'alex.martinez@vehicle-triage.io');
  final _passwordController = TextEditingController(text: 'Password123!');
  bool _isSignInTab = true;
  bool _isLoading = false;
  String? _errorMessage;

  void _handleAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final res = _isSignInTab
        ? await provider.signIn(email, password)
        : await provider.signUp(email, password);

    if (mounted) {
      setState(() => _isLoading = false);
      if (res.success && res.token != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BlePairingScreen()),
        );
      } else {
        setState(() {
          _errorMessage = res.errorMessage ?? 'Invalid email or password. Authentication rejected (JWT required).';
        });
      }
    }
  }

  void _fillDemoCredentials() {
    setState(() {
      _emailController.text = 'alex.martinez@vehicle-triage.io';
      _passwordController.text = 'Password123!';
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.4), width: 1.5),
                ),
                child: const Icon(
                  Icons.minor_crash_rounded,
                  size: 38,
                  color: Color(0xFF6C5CE7),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in to your account',
                style: TextStyle(
                  color: Color(0xFF8E92A4),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 24),

              // Error Banner (if auth failed)
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7675).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF7675), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFFF7675), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFFF7675), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Tab Toggle
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isSignInTab = true;
                          _errorMessage = null;
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isSignInTab ? const Color(0xFF6C5CE7) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              color: _isSignInTab ? Colors.white : const Color(0xFF8E92A4),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isSignInTab = false;
                          _errorMessage = null;
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: !_isSignInTab ? const Color(0xFF6C5CE7) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: !_isSignInTab ? Colors.white : const Color(0xFF8E92A4),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form Inputs
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Email address',
                  hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
                  filled: true,
                  fillColor: const Color(0xFF161922),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
                  filled: true,
                  fillColor: const Color(0xFF161922),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _fillDemoCredentials,
                    child: const Text(
                      'Use demo credentials',
                      style: TextStyle(color: Color(0xFF00B894), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton(
                    onPressed: _handleAuth,
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(color: Color(0xFF6C5CE7), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Primary Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          _isSignInTab ? 'Sign In' : 'Create Account',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Divider
              Row(
                children: const [
                  Expanded(child: Divider(color: Color(0xFF232736))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text('or', style: TextStyle(color: Color(0xFF5A5E73), fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: Color(0xFF232736))),
                ],
              ),
              const SizedBox(height: 20),

              // Pair OBD Device First
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BlePairingScreen()),
                  );
                },
                icon: const Icon(Icons.bluetooth_searching_rounded, color: Color(0xFF6C5CE7), size: 22),
                label: const Text('Pair OBD Device & Auto-Authenticate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Color(0xFF6C5CE7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
