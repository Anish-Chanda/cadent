import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/auth/auth_logo.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/auth/server_url_widget.dart';
import '../../widgets/global/app_text_form_field.dart';
import '../../widgets/global/password_form_field.dart';
import '../../widgets/global/primary_button.dart';
import '../../widgets/global/text_link_button.dart';
import '../../utils/validators.dart';
import '../../utils/app_spacing.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: \${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Logo/Title
                        const AuthLogo(),
                        AppSpacing.gapXL,
                        const AuthHeader(title: 'Welcome!'),
                        const SizedBox(height: 56),

                        // Login Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              AppTextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                labelText: 'Email',
                                hintText: 'Enter your email address',
                                validator: Validators.email,
                              ),
                              AppSpacing.gapMD,
                              PasswordFormField(
                                controller: _passwordController,
                                validator: Validators.password,
                              ),
                              AppSpacing.gapXL,

                              // Login Button
                              Consumer<AuthProvider>(
                                builder: (context, auth, child) {
                                  return PrimaryButton(
                                    text: 'Login',
                                    onPressed: _handleLogin,
                                    isLoading: auth.isLoading,
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // Sign up link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Don't have an account? "),
                                  TextLinkButton(
                                    text: 'Sign up',
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const SignupScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Server URL Widget
              const ServerUrlWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
