import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/backend.dart';
import '../core/theme.dart';
import 'shell.dart';

/// Mobile + OTP login. The dev OTP service accepts 9999999999 / 123456,
/// exactly as the spec describes.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobile = TextEditingController(text: '9999999999');
  final _otp = TextEditingController();
  bool _otpStage = false;
  bool _busy = false;
  String? _error;

  Future<void> _sendOtp() async {
    final m = _mobile.text.trim();
    if (m.length != 10) {
      setState(() => _error = 'Enter a 10-digit mobile number');
      return;
    }
    setState(() { _busy = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() { _busy = false; _otpStage = true; });
  }

  Future<void> _verify() async {
    setState(() { _busy = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    if (_otp.text.trim() != '123456') {
      setState(() { _busy = false; _error = 'Incorrect OTP. Use 123456 in the demo.'; });
      return;
    }
    DemoBackend.instance.bootstrap(_mobile.text.trim());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: const AppShell()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF151B3B), C.bg, Color(0xFF0E1830)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: C.playGrad,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: C.primary.withValues(alpha: .4), blurRadius: 30)],
                        ),
                        child: const Center(child: Text('🎯', style: TextStyle(fontSize: 38))),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text('SkillArena',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -.6)),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text('Quiz duels. Pure skill.',
                          style: TextStyle(color: C.muted, fontSize: 14.5, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 34),
                    Panel(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(_otpStage ? 'Enter the code' : 'Sign in',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            _otpStage
                                ? 'We sent a 6-digit code to +91 ${_mobile.text}'
                                : 'We will text you a one-time code',
                            style: const TextStyle(color: C.muted, fontSize: 13),
                          ),
                          const SizedBox(height: 18),
                          if (!_otpStage)
                            TextField(
                              controller: _mobile,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                              decoration: _dec('Mobile number', prefix: '+91  '),
                            )
                          else
                            TextField(
                              controller: _otp,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              autofocus: true,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
                              textAlign: TextAlign.center,
                              decoration: _dec('6-digit code'),
                            ),
                          if (_error != null) ...[
                            const SizedBox(height: 4),
                            Text(_error!, style: const TextStyle(color: C.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ],
                          const SizedBox(height: 10),
                          _busy
                              ? const SizedBox(height: 54, child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
                              : PrimaryButton(
                                  label: _otpStage ? 'Verify & play' : 'Send OTP',
                                  onTap: _otpStage ? _verify : _sendOtp,
                                ),
                          if (_otpStage) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton(
                                onPressed: () => setState(() { _otpStage = false; _otp.clear(); _error = null; }),
                                child: const Text('Change number', style: TextStyle(color: C.muted)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: C.accent.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: C.accent.withValues(alpha: .25)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Demo build', style: TextStyle(color: C.accent, fontWeight: FontWeight.w800, fontSize: 13)),
                          SizedBox(height: 4),
                          Text(
                            'Mobile 9999999999 · OTP 123456\n'
                            'Plays with demo coins only. No real money, deposits or payouts.',
                            style: TextStyle(color: C.muted, fontSize: 12, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, {String? prefix}) => InputDecoration(
        hintText: hint,
        counterText: '',
        prefixText: prefix,
        prefixStyle: const TextStyle(color: C.muted, fontSize: 16, fontWeight: FontWeight.w700),
        hintStyle: const TextStyle(color: C.muted, fontWeight: FontWeight.w500, letterSpacing: 0),
        filled: true,
        fillColor: C.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: C.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: C.primary, width: 1.6),
        ),
      );
}
