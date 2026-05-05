import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';

class FieldVisitScreen extends StatefulWidget {
  const FieldVisitScreen({super.key});

  @override
  State<FieldVisitScreen> createState() => _FieldVisitScreenState();
}

class _FieldVisitScreenState extends State<FieldVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final String _selectedFarmer = 'Ramesh Kumar';
  final String _selectedProblem = 'Pest Attack';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Field Visit')),
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
                  const Text(
                    'Visit Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedFarmer,
                          decoration: const InputDecoration(
                            labelText: 'Select Farmer',
                            fillColor: Colors.white,
                          ),
                          items:
                              [
                                'Ramesh Kumar',
                                'Suresh Singh',
                                'Madu Patil',
                              ].map((String farmer) {
                                return DropdownMenuItem(
                                  value: farmer,
                                  child: Text(farmer),
                                );
                              }).toList(),
                          onChanged: (String? value) {},
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedProblem,
                          decoration: const InputDecoration(
                            labelText: 'Identify Problem',
                            fillColor: Colors.white,
                          ),
                          items:
                              [
                                'Pest Attack',
                                'Water Scarcity',
                                'Nutrient Deficiency',
                                'None',
                              ].map((String problem) {
                                return DropdownMenuItem(
                                  value: problem,
                                  child: Text(problem),
                                );
                              }).toList(),
                          onChanged: (String? value) {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Observations & Media',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Visit Notes',
                            hintText: 'Describe the field condition',
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.camera_alt_rounded,
                                color: AppColors.primary,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Click to Capture Image',
                                style: TextStyle(
                                  color: AppColors.primary.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Save Field Visit'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
