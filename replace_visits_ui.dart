import 'dart:io';

void main() {
  final file = File('d:/Personal/naturebiotic/lib/features/dashboard/screens/dashboard_screen.dart');
  String content = file.readAsStringSync();
  content = content.replaceAll('\r\n', '\n');

  final startStr = '              return Container(\n                width:';
  final endStr = '              );\n            },\n          ),\n        ),\n      ],\n    );\n  }';

  final startIndex = content.indexOf(startStr);
  final endIndex = content.indexOf(endStr);

  if (startIndex == -1 || endIndex == -1) {
    print("Could not find start or end bounds.");
    print("startIndex: \$startIndex, endIndex: \$endIndex");
    return;
  }

  // Preserve the exact onPressed block from the original code
  final buttonStartStr = 'ElevatedButton(\n                                    onPressed: () {';
  final buttonEndStr = 'style: ElevatedButton.styleFrom(';
  
  final buttonStartIdx = content.indexOf(buttonStartStr, startIndex);
  final buttonEndIdx = content.indexOf(buttonEndStr, buttonStartIdx);

  if (buttonStartIdx == -1 || buttonEndIdx == -1) {
    print("Could not find button logic bounds.");
    return;
  }

  final onPressedLogic = content.substring(buttonStartIdx + 'ElevatedButton(\n'.length, buttonEndIdx);

  final newContainer = '''              return Container(
                width: MediaQuery.sizeOf(context).width * 0.72,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)], // Vibrant Green
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Watermark / Pattern
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        mainIcon,
                        size: 150,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isManager
                                          ? Icons.pending_actions_rounded
                                          : Icons.history_toggle_off_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isManager
                                          ? reminder['reminder_type']
                                              .toString()
                                              .toUpperCase()
                                          : _getReminderLabel(date),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  DateFormat('dd MMM').format(date),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                _isManager
                                    ? Icons.info_outline_rounded
                                    : Icons.eco_outlined,
                                color: Colors.white.withValues(alpha: 0.7),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Compact Action Row
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ElevatedButton(
${onPressedLogic}                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      _isManager
                                          ? 'Review & Verify'
                                          : 'View Details',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.directions_outlined,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),''';

  content = content.replaceRange(startIndex, endIndex, newContainer);
  
  // Re-add Windows line endings before saving
  content = content.replaceAll('\n', '\r\n');
  file.writeAsStringSync(content);
  print("Successfully replaced UI!");
}
