import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

/// Login screen: Company ID + Password, with a Salesman / Admin-Manager
/// role tab, "Remember Me", and "Forgot Password?".
///
/// Every element on this screen is wired to real behavior:
/// - The tab you pick is checked against the account's actual role after
///   sign-in (an admin account can't slip in through the Salesman tab
///   and vice-versa).
/// - "Remember Me" persists the Company ID locally (via SharedPreferences)
///   and pre-fills it next time; unchecking it forgets it immediately.
/// - "Forgot Password?" sends a real Supabase password-reset email.
/// - "Sign In" authenticates via AuthService, which maps the Company ID
///   to the underlying Supabase Auth email (see auth_service.dart).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginRole { salesman, admin }

class _LoginScreenState extends State<LoginScreen> {
  static const _prefsCompanyIdKey = 'remembered_company_id';

  final _companyIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _profileService = ProfileService();

  _LoginRole _selectedRole = _LoginRole.salesman;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRememberedCompanyId();
  }

  Future<void> _loadRememberedCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsCompanyIdKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        _companyIdController.text = saved;
        _rememberMe = true;
      });
    }
  }

  Future<void> _login() async {
    final companyId = _companyIdController.text.trim();
    final password = _passwordController.text;

    if (companyId.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both Company ID and Password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signIn(companyId, password);

      // Confirm the signed-in account's actual role matches the tab
      // the user selected before we let them in.
      final profile = await _profileService.getMyProfile();
      final expectedRole =
          _selectedRole == _LoginRole.admin ? 'admin' : 'salesperson';

      if (profile.role != expectedRole) {
        await _authService.signOut();
        final actualLabel = profile.role == 'admin' ? 'Admin / Manager' : 'Salesman';
        setState(() {
          _errorMessage =
              'This Company ID is registered as $actualLabel. Please switch tabs and sign in again.';
        });
        return;
      }

      // Persist or forget the Company ID per the "Remember Me" toggle.
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString(_prefsCompanyIdKey, companyId);
      } else {
        await prefs.remove(_prefsCompanyIdKey);
      }

      // main.dart's AuthGate listens for auth state changes and will
      // automatically switch to the right dashboard once login succeeds.
    } on Object catch (_) {
      setState(() {
        _errorMessage = 'Login failed. Check your Company ID and password.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(text: _companyIdController.text.trim());
    bool sending = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your Company ID and we\'ll send a password reset link to the email on file.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Company ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 8),
                    Text(dialogError!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final id = controller.text.trim();
                          if (id.isEmpty) {
                            setDialogState(() => dialogError = 'Please enter your Company ID.');
                            return;
                          }
                          setDialogState(() {
                            sending = true;
                            dialogError = null;
                          });
                          try {
                            await _authService.resetPassword(id);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('If an account exists for that Company ID, a reset link has been sent.'),
                                ),
                              );
                            }
                          } catch (_) {
                            setDialogState(() {
                              sending = false;
                              dialogError = 'Couldn\'t send reset link. Please try again.';
                            });
                          }
                        },
                  child: sending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _companyIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildRoleTabs(),
                          const SizedBox(height: 24),
                          _buildLabel('COMPANY ID'),
                          const SizedBox(height: 8),
                          _buildCompanyIdField(),
                          const SizedBox(height: 20),
                          _buildLabel('PASSWORD'),
                          const SizedBox(height: 8),
                          _buildPasswordField(),
                          const SizedBox(height: 16),
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _buildRememberAndForgotRow(),
                          const SizedBox(height: 20),
                          _buildSignInButton(),
                          const SizedBox(height: 20),
                          const Text(
                            'Powered by SalesForce Pro v3.2.1',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D6BFF), Color(0xFF1530A6)],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.business_center, color: Color(0xFF2A4FD6), size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'SalesForce Pro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'FMCG Field Sales Management',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _roleTab('Salesman', _LoginRole.salesman)),
          Expanded(child: _roleTab('Admin / Manager', _LoginRole.admin)),
        ],
      ),
    );
  }

  Widget _roleTab(String label, _LoginRole role) {
    final selected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedRole = role;
        _errorMessage = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF2A4FD6) : Colors.grey.shade600,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _fieldDecoration({required Widget icon, Widget? suffixIcon}) {
    return InputDecoration(
      prefixIcon: icon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3D6BFF), width: 1.5),
      ),
    );
  }

  Widget _buildCompanyIdField() {
    return TextField(
      controller: _companyIdController,
      textInputAction: TextInputAction.next,
      decoration: _fieldDecoration(
        icon: const Icon(Icons.verified_user_outlined, color: Color(0xFF3D6BFF), size: 20),
      ).copyWith(hintText: 'e.g. HUL-2025'),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _login(),
      decoration: _fieldDecoration(
        icon: const Icon(Icons.lock_outline, color: Color(0xFF3D6BFF), size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  Widget _buildRememberAndForgotRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (value) => setState(() => _rememberMe = value ?? false),
                  activeColor: const Color(0xFF3D6BFF),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Remember Me', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : _showForgotPasswordDialog,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
          child: const Text(
            'Forgot Password?',
            style: TextStyle(color: Color(0xFF3D6BFF), fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3D6BFF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
