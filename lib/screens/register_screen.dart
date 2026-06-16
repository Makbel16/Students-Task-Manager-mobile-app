import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  void _handleRegister() {
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('Please enter your email', Colors.red);
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showSnackBar('Please enter your password', Colors.red);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Registration successful! Please login', Colors.green);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.padding),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.person_add, size: 80, color: AppColors.primary),
              const SizedBox(height: 20),
              const Text(
                'Create Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              CustomTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _emailController,
                label: AppStrings.email,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                label: AppStrings.password,
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _confirmPasswordController,
                label: AppStrings.confirmPassword,
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: AppStrings.register,
                onPressed: _handleRegister,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Already have an account? Login',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}