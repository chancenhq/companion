import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/auth_provider.dart';
import 'backend_config_screen.dart';
import 'forgot_password_screen.dart';

// ── Reusable auth form — used by LoginScreen and OnboardingScreen ──────────

class LoginFormBody extends StatefulWidget {
  const LoginFormBody({
    super.key,
    this.branded = false,
    this.allowSignUp = false,
    this.onLogoTap,
  });

  /// When true: Chancen logo + "Sign in to your Companion" headline.
  final bool branded;

  /// When true: shows Sign In | Sign Up toggle and first/last name fields.
  final bool allowSignUp;

  /// Optional tap handler for the logo (used for hidden dev-mode unlock).
  final VoidCallback? onLogoTap;

  @override
  State<LoginFormBody> createState() => _LoginFormBodyState();
}

class _LoginFormBodyState extends State<LoginFormBody> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _isSignUp = false;

  // Issue #106, Story 2.1: Google, Apple and "Continue with email" are equal
  // first choices; the email form opens from the last one.
  bool _emailChosen = false;
  bool get _showEmailForm => !widget.branded || _emailChosen;

  static const _passwordRules =
      'At least 8 characters, with upper and lower case letters, a number and a symbol (like ! or ?).';

  /// Mirrors the server's sign-up rules so problems show before submitting.
  static String? _signUpPasswordError(String password) {
    if (password.runes.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(password) || !RegExp(r'[a-z]').hasMatch(password)) {
      return 'Use both upper and lower case letters.';
    }
    if (!RegExp(r'\d').hasMatch(password)) return 'Add at least one number.';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Add at least one symbol, like ! or ?.';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final hadOtpCode = authProvider.showMfaInput && _otpController.text.isNotEmpty;
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      otpCode: authProvider.showMfaInput ? _otpController.text.trim() : null,
    );
    if (!mounted) return;
    if (!success && hadOtpCode && authProvider.errorMessage != null) {
      _otpController.clear();
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signup(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      invitationToken: authProvider.pendingInvitationToken,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),

          // ── Header ──────────────────────────────────────────────────────
          if (widget.branded) ...[
            Center(
              child: GestureDetector(
                onTap: widget.onLogoTap,
                child: SvgPicture.asset(
                  'assets/images/companion-logo.svg',
                  width: 64,
                  height: 64,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isSignUp ? 'Create your account' : 'Sign in to your Companion',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Access your ISA info, financial tools, and personalised guidance.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],

          if (_showEmailForm) ...[
          if (widget.branded)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  context.read<AuthProvider>().clearError();
                  setState(() => _emailChosen = false);
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Other ways to sign in'),
              ),
            ),

          // ── Sign In | Sign Up toggle ─────────────────────────────────
          if (widget.allowSignUp) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _isSignUp ? () => setState(() => _isSignUp = false) : null,
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      fontWeight: _isSignUp ? FontWeight.normal : FontWeight.bold,
                      color: _isSignUp ? colorScheme.onSurfaceVariant : colorScheme.primary,
                    ),
                  ),
                ),
                Text('|', style: TextStyle(color: colorScheme.outlineVariant)),
                TextButton(
                  onPressed: _isSignUp ? null : () => setState(() => _isSignUp = true),
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      fontWeight: _isSignUp ? FontWeight.bold : FontWeight.normal,
                      color: _isSignUp ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // ── Error banner ─────────────────────────────────────────────
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              if (authProvider.errorMessage == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        authProvider.errorMessage!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => authProvider.clearError(),
                      iconSize: 20,
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Fields ───────────────────────────────────────────────────
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final showOtp = authProvider.showMfaInput;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sign-up name fields
                  if (widget.allowSignUp && _isSignUp) ...[
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter your first name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter your last name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Email
                  TextFormField(
                    controller: _emailController,
                    focusNode: widget.branded ? null : _emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      helperText: 'Use the email address you gave Chancen.',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter your email';
                      if (!v.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    focusNode: widget.branded ? null : _passwordFocus,
                    obscureText: _obscurePassword,
                    textInputAction:
                        showOtp ? TextInputAction.next : TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter your password';
                      return _isSignUp ? _signUpPasswordError(v) : null;
                    },
                    onFieldSubmitted: showOtp
                        ? null
                        : (_) => _isSignUp ? _handleSignUp() : _handleLogin(),
                  ),

                  if (_isSignUp) ...[
                    const SizedBox(height: 8),
                    Text(
                      _passwordRules,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],

                  // Forgot password — sign-in only
                  if (!_isSignUp) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  ],

                  // MFA / OTP
                  if (showOtp) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.security, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Two-factor authentication is enabled. Enter your code.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Authentication Code',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                      validator: (v) => (showOtp && (v == null || v.isEmpty))
                          ? 'Please enter your authentication code'
                          : null,
                      onFieldSubmitted: (_) => _handleLogin(),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Submit
                  ElevatedButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () => _isSignUp ? _handleSignUp() : _handleLogin(),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isSignUp ? 'Create Account' : 'Sign In'),
                  ),
                ],
              );
            },
          ),

          ],

          // ── Sign-in choices: Google, Apple, email ────────────────────
          if (!_showEmailForm) ...[
          const SizedBox(height: 8),
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return OutlinedButton.icon(
                onPressed: authProvider.isLoading
                    ? null
                    : () => authProvider.startSsoLogin('google_oauth2'),
                icon: SvgPicture.asset(
                  'assets/images/google_g_logo.svg',
                  width: 18,
                  height: 18,
                ),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),

          // ── Apple Sign-In (iOS only — Apple requires it when other SSO is offered) ──
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
            const SizedBox(height: 12),
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                return SignInWithAppleButton(
                  onPressed: authProvider.isLoading
                      ? () {}
                      : () => authProvider.signInWithApple(),
                  style: Theme.of(context).brightness == Brightness.dark
                      ? SignInWithAppleButtonStyle.white
                      : SignInWithAppleButtonStyle.black,
                  height: 50,
                  borderRadius: BorderRadius.circular(12),
                );
              },
            ),
          ],

          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('continue-with-email'),
            onPressed: () {
              context.read<AuthProvider>().clearError();
              setState(() => _emailChosen = true);
            },
            icon: const Icon(Icons.mail_outline, size: 20),
            label: const Text('Continue with email'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the email address you gave Chancen.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Standalone login screen for returning users ─────────────────────────────

class LoginScreen extends StatefulWidget {
  final VoidCallback? onGoToSettings;

  const LoginScreen({super.key, this.onGoToSettings});

  void _openSettings(BuildContext context) {
    if (onGoToSettings != null) {
      onGoToSettings!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => BackendConfigScreen(
          onConfigSaved: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _logoTapCount = 0;
  DateTime? _firstLogoTapAt;
  bool _devUnlocked = false;

  void _handleLogoTap() {
    final now = DateTime.now();
    if (_firstLogoTapAt == null ||
        now.difference(_firstLogoTapAt!) > const Duration(seconds: 5)) {
      _firstLogoTapAt = now;
      _logoTapCount = 1;
    } else {
      _logoTapCount++;
      if (_logoTapCount >= 7 && !_devUnlocked) {
        setState(() => _devUnlocked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Developer options enabled'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showApiKeyDialog() {
    final apiKeyController = TextEditingController();
    final outerContext = context;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return AlertDialog(
              title: const Text('API Key Login'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter your API key to sign in.',
                    style: Theme.of(outerContext).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(outerContext).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                    obscureText: true,
                    maxLines: 1,
                    enabled: !isLoading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          apiKeyController.dispose();
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final apiKey = apiKeyController.text.trim();
                          if (apiKey.isEmpty) return;
                          setDialogState(() => isLoading = true);
                          final authProvider = Provider.of<AuthProvider>(
                            outerContext,
                            listen: false,
                          );
                          final success = await authProvider.loginWithApiKey(
                            apiKey: apiKey,
                          );
                          if (!dialogContext.mounted) return;
                          final errorMsg = authProvider.errorMessage;
                          apiKeyController.dispose();
                          Navigator.of(dialogContext).pop();
                          if (!success && mounted) {
                            ScaffoldMessenger.of(outerContext).showSnackBar(
                              SnackBar(
                                content: Text(errorMsg ?? 'Invalid API key'),
                                backgroundColor:
                                    Theme.of(outerContext).colorScheme.error,
                              ),
                            );
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LoginFormBody(
                    branded: true,
                    allowSignUp: true,
                    onLogoTap: _handleLogoTap,
                  ),

                  if (_devUnlocked) ...[
                    const SizedBox(height: 12),

                    // API Key Login Button
                    TextButton.icon(
                      onPressed: _showApiKeyDialog,
                      icon: const Icon(Icons.vpn_key_outlined, size: 18),
                      label: const Text('API-Key Login'),
                    ),
                  ],
                ],
              ),
            ),

            if (_devUnlocked)
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Backend Settings',
                  onPressed: () => widget._openSettings(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
