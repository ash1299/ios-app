import 'package:flutter/material.dart';
import '../theme.dart';
import 'otp_screen.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../services/user_preferences.dart'; // REQUIRED IMPORT

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  // Stores the complete number with country code (e.g., +919876543210)
  String fullPhoneNumber = '';

  // 1. Made async to handle UserPreferences saving
  void _submitLogin() async {
    // 2. Validate Input
    if (_formKey.currentState!.validate()) {
      
      String name = _nameController.text.trim();

      // Check if phone number is valid
      if (fullPhoneNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a valid phone number")),
        );
        return;
      }

      // ---------------------------------------------------------
      // 3. UPDATED: Save User Data (Name AND Phone)
      // ---------------------------------------------------------
      await UserPreferences().saveUser(name, fullPhoneNumber);
      
      if (!mounted) return; // Safety check before navigating

      // 4. Navigate to OTP Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            userName: name,
            phoneNumber: fullPhoneNumber, // Passes the full code + number
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Header ---
                    const Icon(Icons.security, size: 80, color: AppTheme.primaryBlue),
                    const SizedBox(height: 20),
                    const Text(
                      "Welcome to SEVAK",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Please enter your details to continue",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 40),

                    // --- Name Field ---
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Full Name", Icons.person),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => (value == null || value.isEmpty)
                          ? "Please enter your name"
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // --- Country Code Phone Field (Default: India) ---
                    IntlPhoneField(
                      decoration: _inputDecoration("Phone Number", Icons.phone),
                      style: const TextStyle(color: Colors.white),
                      dropdownTextStyle: const TextStyle(color: Colors.white),
                      dropdownIcon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      
                      // SET DEFAULT TO INDIA
                      initialCountryCode: 'IN', 
                      
                      onChanged: (phone) {
                        // This updates the variable whenever the user types
                        fullPhoneNumber = phone.completeNumber;
                      },
                      onCountryChanged: (country) {
                        // Optional: logic if they change flags
                      },
                    ),
                    const SizedBox(height: 40),

                    // --- Continue Button ---
                    SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _submitLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 5,
                        ),
                        child: const Text(
                          "Get OTP",
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
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
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: AppTheme.primaryBlue),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
          borderRadius: BorderRadius.circular(12)),
      errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(12)),
      focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(12)),
    );
  }
}