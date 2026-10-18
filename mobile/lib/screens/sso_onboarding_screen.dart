import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';

class SsoOnboardingScreen extends StatefulWidget {
  /// When true the user is already authenticated — only the password field is
  /// shown so they can set one without going through account creation again.
  final bool passwordOnlyMode;

  const SsoOnboardingScreen({super.key, this.passwordOnlyMode = false});

  @override
  State<SsoOnboardingScreen> createState() => _SsoOnboardingScreenState();
}

class _SsoOnboardingScreenState extends State<SsoOnboardingScreen> {
  final _createFormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (!widget.passwordOnlyMode) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _firstNameController.text = authProvider.ssoFirstName ?? '';
      _lastNameController.text = authProvider.ssoLastName ?? '';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateAccount() async {
    if (!_createFormKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final password = _passwordController.text.trim();
    await authProvider.ssoCreateAccount(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      password: password,
    );
  }

  Future<void> _handleSetPassword() async {
    if (!_createFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getValidAccessToken();
      if (token == null) {
        setState(() => _errorMessage = 'Session expired. Please sign in again.');
        return;
      }

      final result = await UserService().updatePassword(
        accessToken: token,
        newPassword: _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        await authProvider.refreshUser();
      } else {
        setState(() => _errorMessage = result['error'] as String? ?? 'Failed to set password.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.passwordOnlyMode) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Set Up a Password'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outlined, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Add a password so you can always sign in, even if you lose access to Google or Apple.',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Container(
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
                              _errorMessage!,
                              style: TextStyle(color: colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Form(
                    key: _createFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPasswordField(),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleSetPassword,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Set Password'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Provider.of<AuthProvider>(
              context,
              listen: false,
            ).cancelSsoOnboarding();
          },
        ),
        title: const Text('Create Your Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  SvgPicture.asset(
                    'assets/images/google_g_logo.svg',
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authProvider.ssoEmail != null
                        ? 'Signed in as ${authProvider.ssoEmail}'
                        : 'Google account verified',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Error message
                  if (authProvider.errorMessage != null)
                    Container(
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
                              style: TextStyle(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => authProvider.clearError(),
                            iconSize: 20,
                          ),
                        ],
                      ),
                    ),

                  _buildCreateForm(authProvider, colorScheme),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Create a Password',
        hintText: 'Used to sign in without Google or Apple',
        prefixIcon: const Icon(Icons.lock_outlined),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Password is required';
        if (value.trim().length < 8) return 'Use at least 8 characters';
        return null;
      },
      onFieldSubmitted: (_) => widget.passwordOnlyMode
          ? _handleSetPassword()
          : _handleCreateAccount(),
    );
  }

  Widget _buildCreateForm(AuthProvider authProvider, ColorScheme colorScheme) {
    final hasPendingInvitation = authProvider.ssoHasPendingInvitation;
    return Form(
      key: _createFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  hasPendingInvitation ? Icons.mail_outline : Icons.person_add,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasPendingInvitation
                        ? 'You have a pending invitation. Accept it to join an existing household.'
                        : 'Create a new account using your Google identity.',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'First Name',
              prefixIcon: Icon(Icons.person_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your first name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Last Name',
              prefixIcon: Icon(Icons.person_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your last name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildPasswordField(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: authProvider.isLoading ? null : _handleCreateAccount,
            child: authProvider.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    hasPendingInvitation
                        ? 'Accept Invitation'
                        : 'Create Account',
                  ),
          ),
        ],
      ),
    );
  }
}
