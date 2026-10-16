import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_validation.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/liner_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static final _usernameFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9_]')),
    LengthLimitingTextInputFormatter(AuthValidation.maxUsernameLength),
    TextInputFormatter.withFunction(
      (oldValue, newValue) =>
          newValue.copyWith(text: newValue.text.toLowerCase()),
    ),
  ];

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _username = TextEditingController();
  final _displayName = TextEditingController();

  bool _isRegister = false;
  bool _isBusy = false;
  bool _obscurePasswords = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isBusy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final auth = ref.read(authProvider.notifier);
    try {
      if (_isRegister) {
        await auth.register(
          email: _email.text,
          password: _password.text,
          username: _username.text,
          displayName: _displayName.text,
        );
      } else {
        await auth.signIn(_email.text, _password.text);
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _error = error.message;
      });
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegister = !_isRegister;
      _error = null;
      _confirmPassword.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: LinerLogoTile(size: 72)),
                      const SizedBox(height: 24),
                      Text(
                        _isRegister
                            ? 'Create your Liner account'
                            : 'Sign in to Liner',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          letterSpacing: -0.4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your library, synced lyrics and recommendations.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (_error case final error?) ...[
                        _ErrorBanner(message: error),
                        const SizedBox(height: 16),
                      ],
                      if (_isRegister) ...[
                        _field(
                          controller: _displayName,
                          label: 'Display name',
                          validator: AuthValidation.displayName,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _username,
                          label: 'Username',
                          helper: '3-30 letters, numbers or underscores',
                          validator: AuthValidation.username,
                          inputFormatters: _usernameFormatters,
                          autofillHints: const [AutofillHints.newUsername],
                        ),
                        const SizedBox(height: 14),
                      ],
                      _field(
                        controller: _email,
                        label: 'Email',
                        validator: AuthValidation.email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 14),
                      _field(
                        controller: _password,
                        label: 'Password',
                        helper: _isRegister ? 'At least 8 characters' : null,
                        validator: AuthValidation.password,
                        obscureText: _obscurePasswords,
                        autofillHints: [
                          _isRegister
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: _isRegister
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: _isRegister ? null : _submit,
                        suffix: _visibilityToggle(),
                      ),
                      if (_isRegister) ...[
                        const SizedBox(height: 14),
                        _field(
                          controller: _confirmPassword,
                          label: 'Confirm password',
                          validator: (value) => AuthValidation.confirmPassword(
                            _password.text,
                            value,
                          ),
                          obscureText: _obscurePasswords,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onSubmitted: _submit,
                          suffix: _visibilityToggle(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LinerColors.accentPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isBusy ? null : _submit,
                          child: _isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isRegister ? 'Create account' : 'Sign in',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isBusy ? null : _toggleMode,
                        child: Text(
                          _isRegister
                              ? 'Already have an account? Sign in'
                              : "Don't have an account? Create one",
                          style: const TextStyle(
                            color: LinerColors.accentSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
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

  Widget _visibilityToggle() => IconButton(
    tooltip: _obscurePasswords ? 'Show passwords' : 'Hide passwords',
    icon: Icon(
      _obscurePasswords
          ? Icons.visibility_rounded
          : Icons.visibility_off_rounded,
      color: Colors.white54,
      size: 20,
    ),
    onPressed: () => setState(() => _obscurePasswords = !_obscurePasswords),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    String? helper,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    Iterable<String>? autofillHints,
    bool obscureText = false,
    TextInputAction textInputAction = TextInputAction.next,
    VoidCallback? onSubmitted,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions:
          !obscureText && keyboardType != TextInputType.emailAddress,
      enabled: !_isBusy,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Colors.white60),
        suffixIcon: suffix,
        filled: true,
        fillColor: LinerColors.darkElevated,
        border: border(LinerColors.darkBorderSecondary),
        enabledBorder: border(LinerColors.darkBorderSecondary),
        focusedBorder: border(LinerColors.accentPrimary),
        errorBorder: border(Colors.redAccent),
        focusedErrorBorder: border(Colors.redAccent),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      message,
      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
    ),
  );
}
