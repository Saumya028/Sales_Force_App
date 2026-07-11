import 'package:flutter/material.dart';
import '../../services/admin_user_service.dart';

/// Lets an Admin create a brand-new salesperson account. On success, pops
/// back with `true` so the caller can refresh the roster.
class AddSalesmanScreen extends StatefulWidget {
  const AddSalesmanScreen({super.key});

  @override
  State<AddSalesmanScreen> createState() => _AddSalesmanScreenState();
}

class _AddSalesmanScreenState extends State<AddSalesmanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminUserService = AdminUserService();

  final _nameController = TextEditingController();
  final _companyIdController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _companyIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await _adminUserService.createSalesman(
        companyId: _companyIdController.text,
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorText = 'Could not create account: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Salesman')),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Creates a new salesperson login. Share the Company ID and '
                'temporary password with them so they can sign in and set '
                'up their own account from there.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Full name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _companyIdController,
                decoration: const InputDecoration(
                  labelText: 'Company ID *',
                  hintText: 'e.g. HUL-2031',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Company ID is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Temporary Password *',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.length < 6)
                    ? 'Password must be at least 6 characters'
                    : null,
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Text(_errorText!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Creating...' : 'Create Salesman'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  onPressed: _isSaving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
