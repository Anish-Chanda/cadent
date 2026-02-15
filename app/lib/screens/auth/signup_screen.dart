import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/auth/server_url_widget.dart';
import '../../widgets/global/app_text_form_field.dart';
import '../../widgets/global/password_form_field.dart';
import '../../widgets/global/primary_button.dart';
import '../../widgets/global/text_link_button.dart';
import '../../utils/validators.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Welcome to Cadent!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signup failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'C',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const AuthHeader(
                          title: 'Join Cadent',
                          subtitle: 'Create your account to get started',
                        ),
                        const SizedBox(height: 48),

                        // Signup Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              AppTextFormField(
                                controller: _nameController,
                                labelText: 'Name',
                                hintText: 'Enter your name',
                                validator: Validators.name,
                              ),
                              const SizedBox(height: 16),
                              AppTextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                labelText: 'Email',
                                hintText: 'Enter your email address',
                                validator: Validators.email,
                              ),
                              const SizedBox(height: 16),
                              PasswordFormField(
                                controller: _passwordController,
                                validator: Validators.password,
                              ),
                              const SizedBox(height: 16),
                              PasswordFormField(
                                controller: _confirmPasswordController,
                                labelText: 'Confirm Password',
                                hintText: 'Re-enter your password',
                                validator: (value) => Validators.confirmPassword(value, _passwordController.text),
                              ),
                              const SizedBox(height: 24),

                              // Signup Button
                              Consumer<AuthProvider>(
                                builder: (context, auth, child) {
                                  return PrimaryButton(
                                    text: 'Create Account',
                                    onPressed: _handleSignup,
                                    isLoading: auth.isLoading,
                                    textColor: Colors.white,
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // Login link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Already have an account? '),
                                  TextLinkButton(
                                    text: 'Log in',
                                    onPressed: () {
                                      Navigator.of(context).pop();
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
