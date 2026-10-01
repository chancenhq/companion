import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'country_selection_screen.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.jumpToPage(page);
    setState(() => _currentPage = page);
  }

  // ── Screen 1: Welcome ──

  Widget _buildWelcomePage() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          SvgPicture.asset(
            'assets/images/companion-logo.svg',
            width: 80,
            height: 80,
          ),
          const SizedBox(height: 32),
          Text(
            'Meet Your Chancen Companion',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'I am here to help you navigate your finances, understand your '
            'Chancen ISA, and build smart money habits.\n\n'
            'Think of me as your personal finance buddy. I will answer your '
            'questions, help you budget like a pro, and support you on your '
            'journey to financial confidence.\n\n'
            'Everything here is for learning purposes; I am not a financial '
            'advisor, just a helpful guide.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildKeyPoint(Icons.question_answer_outlined, 'Get instant answers about your Chancen ISA'),
          const SizedBox(height: 12),
          _buildKeyPoint(Icons.account_balance_wallet_outlined, 'Learn budgeting that actually works'),
          const SizedBox(height: 12),
          _buildKeyPoint(Icons.trending_up, 'Build financial skills for life'),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _goToPage(1),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Let's Get Started"),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildKeyPoint(IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }

  // ── Screen 2: Sign In / Sign Up ──

  Widget _buildSignInPage() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isAuthenticated && _currentPage == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _goToPage(2));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: const LoginFormBody(branded: true, allowSignUp: true),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _currentPage = i),
          children: [
            _buildWelcomePage(),
            _buildSignInPage(),
            CountrySelectionScreen(
              onComplete: widget.onComplete,
              showLogo: true,
            ),
          ],
        ),
      ),
    );
  }
}
