import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/eco_theme.dart';
import '../widgets/eco_background.dart';
import '../widgets/eco_widgets.dart';

/// Feature 1: admin login. After a successful sign-in the AuthGate (app.dart)
/// notices the new session by itself and swaps this screen for the home screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.auth.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      // Success: nothing else to do here, AuthGate switches screens.
    } on AuthFailure catch (err) {
      if (mounted) setState(() => _error = err.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.eco;
    final headline = EcoText.pageTitle(e).copyWith(fontSize: 40, height: 1.08);
    return EcoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset('assets/icon/ecosense_logo.png', width: 48, height: 48),
                          ),
                          const SizedBox(width: 12),
                          Text('EcoSense', style: EcoText.section(e).copyWith(fontSize: 26)),
                        ],
                      ),
                      const SizedBox(height: 36),
                      Text('Your home.', style: headline),
                      Text('Understood.', style: headline.copyWith(color: e.accentDeep)),
                      Text('Under control.', style: headline),
                      const SizedBox(height: 12),
                      Text(
                        'Presence monitoring and energy saving. Sign in to continue.',
                        style: EcoText.pageSub(e),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailCtrl,
                        enabled: !_loading,
                        autocorrect: false,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: ecoFieldDecoration(
                          context,
                          label: 'Email Address',
                          prefixIcon: Icons.person_outline,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Enter your email address' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordCtrl,
                        enabled: !_loading,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: ecoFieldDecoration(
                          context,
                          label: 'Password',
                          prefixIcon: Icons.lock_outline,
                          suffix: IconButton(
                            tooltip: _hidePassword ? 'Show password' : 'Hide password',
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: e.ink2,
                            ),
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        StateBanner(
                          tone: Tone.bad,
                          icon: Icons.error_outline_rounded,
                          child: Text(_error!),
                        ),
                      ],
                      const SizedBox(height: 22),
                      EcoButton(label: 'Sign in', filled: true, loading: _loading, onPressed: _submit),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
