import re

file_path = r'd:\Personal\naturebiotic\lib\features\reports\screens\create_report_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace Stepper start
stepper_start_regex = re.compile(r'Expanded\(\s*child:\s*Stepper\(\s*type:\s*StepperType\.vertical,.*?(?=steps:\s*\[)', re.DOTALL)

top_bar = """Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStepTitle(_currentStep),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: List.generate(6, (index) {
                        return Expanded(
                          child: Container(
                            height: 6,
                            margin: EdgeInsets.only(right: index == 5 ? 0 : 6),
                            decoration: BoxDecoration(
                              color: _currentStep >= index ? AppColors.primary : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentStep = index);
                  },
                  children: [
"""

content = stepper_start_regex.sub(top_bar, content)

# 2. Replace Step( with SingleChildScrollView(
# This needs to be careful. We will replace `steps: [` with `children: [` and then use regex for Step items.
content = content.replace('steps: [', '') # it was already consumed in stepper_start_regex, wait.
# The regex consumed up to `steps: [` (exclusive). Let's fix that.
content = content.replace('steps: [', '')

# Replace Step wrappers
step_regex = re.compile(r'Step\(\s*title:\s*const\s*Text\(\'.*?\'\),.*?content:\s*', re.DOTALL)
# wait, Step has subtitle, isActive.
# Let's match each Step exactly.

def replace_step(m):
    return "SingleChildScrollView(\n                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),\n                child: "

content = re.sub(r'Step\(\s*title:.*?(?=content:\s*(?:Column|_buildPreviewStep))content:\s*', replace_step, content, flags=re.DOTALL)


# 3. Add bottom controls at the end of PageView
end_regex = re.compile(r'(\s*)\],\s*\),\s*\),(\s*)\],\s*\),\s*\),(\s*)\],\s*\),')

bottom_controls = r"""\1],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentStep == 3) ...[
                        OutlinedButton.icon(
                          onPressed: () async {
                            if (_selectedCropId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select a crop first')),
                              );
                              return;
                            }
                            
                            final data = await _collectCurrentCropData();
                            setState(() {
                              _multiCropsData.add(data);
                              _currentStep = 0;
                            });
                            _resetCropStepData();
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Crop added! Now select the next crop to continue.'),
                                  backgroundColor: AppColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text('Add Another Crop to this Report'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 45),
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          if (_currentStep > 0) ...[
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: _onStepCancel,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 50),
                                  side: const BorderSide(color: AppColors.primary),
                                ),
                                child: const Text('Back', style: TextStyle(color: AppColors.primary)),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: (_currentStep == 1 && !_isProblemIdentificationFinished) ? null : _onStepContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 50),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(_currentStep == 5 ? 'Generate Report' : 'Next Step', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),\2],\3],\3],"""

content = end_regex.sub(bottom_controls, content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
