import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';

class CreateStaffScreen extends StatefulWidget {
  const CreateStaffScreen({super.key});

  @override
  State<CreateStaffScreen> createState() => _CreateStaffScreenState();
}

class _CreateStaffScreenState extends State<CreateStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  String _selectedRole = 'executive';
  bool _isLoading = false;

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_selectedRole == 'executive') {
        await SupabaseService.createExecutive(
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _fullNameController.text.trim(),
        );
      } else if (_selectedRole == 'manager') {
        await SupabaseService.createManagerAccount(
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _fullNameController.text.trim(),
        );
      } else if (_selectedRole == 'telecaller') {
        await SupabaseService.createTelecallerAccount(
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _fullNameController.text.trim(),
        );
      } else if (_selectedRole == 'data_entry') {
        await SupabaseService.createDataEntryAccount(
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _fullNameController.text.trim(),
        );
      } else {
        await SupabaseService.createStoreAccount(
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _fullNameController.text.trim(),
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedRole.toUpperCase()} Account Created Successfully'), backgroundColor: AppColors.primary),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create Staff Account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account Role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildRoleSelector(),
                  const SizedBox(height: 32),
                  const Text('Account Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(labelText: 'Full Name', fillColor: Colors.white),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(labelText: 'Username', hintText: 'e.g. mike_field', fillColor: Colors.white),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password', fillColor: Colors.white),
                          validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleCreate,
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'executive',
          label: Text('Executive'),
          icon: Icon(Icons.person_rounded),
        ),
        ButtonSegment(
          value: 'manager',
          label: Text('Manager'),
          icon: Icon(Icons.verified_user_rounded),
        ),
        ButtonSegment(
          value: 'store',
          label: Text('Store'),
          icon: Icon(Icons.inventory_2_rounded),
        ),
        ButtonSegment(
          value: 'telecaller',
          label: Text('Telecaller'),
          icon: Icon(Icons.headset_mic_rounded),
        ),
        ButtonSegment(
          value: 'data_entry',
          label: Text('Data Entry'),
          icon: Icon(Icons.edit_note_rounded),
        ),
      ],
      selected: {_selectedRole},
      onSelectionChanged: (val) => setState(() => _selectedRole = val.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
      ),
    );
  }
}
