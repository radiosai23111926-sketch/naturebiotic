import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'pdf_helper_stub.dart' if (dart.library.html) 'pdf_helper_web.dart' as helper;
import 'package:http/http.dart' as http;

class PdfService {
  static final Map<String, pw.MemoryImage> _imageCache = {};

  static Future<void> preCacheBillingConfigAndImages() async {
    try {
      final config = await SupabaseService.getBillingConfig();
      final qrUrl = config['qr_url']?.toString() ?? '';
      final signatureUrl = config['signature_url']?.toString() ?? '';
      
      final futures = <Future>[];
      if (qrUrl.isNotEmpty) {
        futures.add(_loadNetworkImageWithTimeout(qrUrl));
      }
      if (signatureUrl.isNotEmpty) {
        futures.add(_loadNetworkImageWithTimeout(signatureUrl));
      }
      futures.add(PdfGoogleFonts.robotoRegular());
      futures.add(PdfGoogleFonts.robotoBold());
      
      await Future.wait(futures);
    } catch (e) {
      debugPrint('Error in preCacheBillingConfigAndImages: $e');
    }
  }

  static Future<String> generateNextDcNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await SupabaseService.getProfile();
    String execPart = '0000';
    if (profile != null) {
      final staffNo = profile['staff_number']?.toString();
      if (staffNo != null && staffNo.isNotEmpty) {
        execPart = staffNo.padLeft(4, '0');
        if (execPart.length > 4) {
          execPart = execPart.substring(execPart.length - 4);
        }
      } else {
        final username = profile['username']?.toString() ?? '';
        final digits = username.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isNotEmpty) {
          execPart = digits.padLeft(4, '0');
          if (execPart.length > 4) {
            execPart = execPart.substring(execPart.length - 4);
          }
        } else {
          final id = profile['id']?.toString() ?? '';
          if (id.length >= 4) {
            execPart = id.substring(0, 4).toUpperCase();
          }
        }
      }
    }

    int globalCounter = prefs.getInt('global_dc_counter') ?? 1;
    await prefs.setInt('global_dc_counter', globalCounter + 1);

    final receiptPart = globalCounter.toString().padLeft(4, '0');

    final now = DateTime.now();
    int startYear = now.month < 4 ? now.year - 1 : now.year;
    final fy = '$startYear-${startYear + 1}';

    return 'SAI$execPart$receiptPart/$fy';
  }

  static Future<void> generateAndShare({
    required Map<String, dynamic> report,
    required String farmName,
    required String cropName,
    required String farmerName,
  }) async {
    final pdf = pw.Document();

    // Load fonts that support the Rupee symbol (â‚¹)
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());

    final problemWidget = await _buildProblemSection(
      report['problem'] ?? '',
      font,
      boldFont,
    );

    final historyWidget = await _buildHistoryGrid(
      report['previous_inputs'] ?? 'No data provided',
      font,
      boldFont,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build:
            (context) => [
              _buildHeader(dateStr),
              pw.SizedBox(height: 20),
              _buildInfoSection(farmName, cropName, farmerName),
              pw.SizedBox(height: 20),
              _buildSectionTitle('Problem Analysis'),
              problemWidget,
              pw.SizedBox(height: 15),
              _buildSectionTitle('Previous Inputs History'),
              historyWidget,
              pw.SizedBox(height: 20),
              _buildSectionTitle('Recommended Products & Treatments'),
              _buildRecommendationsTable(report['recommendations'] ?? ''),
              pw.SizedBox(height: 20),
              _buildSectionTitle('Product Requirements & Estimations'),
              _buildCostTable(report['estimated_cost'] ?? ''),
              pw.Spacer(),
              _buildFooter(),
            ],
      ),
    );

    await _shareOrPrintPdf(
      bytes: await pdf.save(),
      filename:
          'NatureBiotic_AnalysisReport_${farmName.replaceAll(' ', '_')}.pdf',
    );
  }

  static Future<pw.Widget> _buildHistoryGrid(
    String history,
    pw.Font font,
    pw.Font bold,
  ) async {
    if (history.isEmpty) {
      return pw.Text('No data provided', style: pw.TextStyle(fontSize: 10));
    }

    final List<pw.Widget> sections = [];
    final cropChunks = history.split('--- Crop: ');

    for (var chunk in cropChunks) {
      if (chunk.trim().isEmpty) continue;

      final parts = chunk.split(' ---\n');
      if (parts.length < 2) {
        sections.add(await _parseTextWithImages(chunk, font, bold, fontSize: 9));
        continue;
      }

      final cropName = parts[0].trim();
      final content = parts[1].trim();

      sections.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Crop: $cropName',
              style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.green900),
            ),
            pw.SizedBox(height: 4),
            await _parseTextWithImages(content, font, bold, fontSize: 9),
            pw.SizedBox(height: 12),
          ],
        ),
      );
    }

    if (sections.isNotEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: sections,
      );
    }

    return pw.Text(history, style: const pw.TextStyle(fontSize: 10));
  }

  static pw.Widget _buildHeader(String date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'NATURE BIOTIC',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green,
              ),
            ),
            pw.Text(
              'Agricultural Analysis & Recommendation Report',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildInfoSection(String farm, String crop, String farmer) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _infoItem('Farmer Name', farmer),
          _infoItem('Farm Name', farm),
          _infoItem('Crop Name', crop),
        ],
      ),
    );
  }

  static pw.Widget _infoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(color: PdfColors.green100),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.green900,
        ),
      ),
    );
  }

  static pw.Widget _buildRecommendationsTable(String recommendations) {
    final lines =
        recommendations.split('\n').where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return pw.Text('No recommendations provided.');

    return pw.TableHelper.fromTextArray(
      context: null,
      headerStyle: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      data: <List<String>>[
        ['Product', 'Application', 'Dose', 'Filler Qty'],
        ...lines.map((line) {
          // Format from app: "Product Name (Application) - Dose: X, Filler: Y"
          final parts = line.split(' - ');
          if (parts.length < 2) return [line, '', '', ''];

          final prodPart = parts[0]; // "Name (App)"
          final detailsPart = parts[1]; // "Dose: X, Filler: Y"

          final prodName =
              prodPart.contains('(') ? prodPart.split('(')[0].trim() : prodPart;
          final app =
              prodPart.contains('(')
                  ? prodPart.split('(')[1].replaceAll(')', '').trim()
                  : '';

          final detailParts = detailsPart.split(', ');
          final dose = detailParts[0].replaceAll('Dose: ', '').trim();
          final filler =
              detailParts.length > 1
                  ? detailParts[1].replaceAll('Filler: ', '').trim()
                  : '';

          return [prodName, app, dose, filler];
        }),
      ],
    );
  }

  static pw.Widget _buildCostTable(String costs) {
    final lines = costs.split('\n').where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return pw.Text('No estimation provided.');

    final tableData = <List<String>>[
      [
        'Product Name',
        'Pkg Size',
        'Qty #',
        'MRP',
        'Offer Price',
        'Total Value',
      ],
    ];

    String grandTotal = '0';
    String nextVisit = 'N/A';

    for (var line in lines) {
      if (line.startsWith('Grand Total:')) {
        grandTotal = line.split(': ')[1];
        continue;
      }
      if (line.startsWith('Next Visit:')) {
        nextVisit = line.split(': ')[1];
        continue;
      }

      // Format from app: "Product Name (Pkg: X) - Qty: Y, MRP: Z, Offer: A, Total: B"
      final parts = line.split(' - ');
      if (parts.length < 2) continue;

      final prodPart = parts[0]; // "Product Name (Pkg: X)"
      final detailsPart = parts[1]; // "Qty: Y, MRP: Z, Offer: A, Total: B"

      final prodName =
          prodPart.contains('(Pkg:')
              ? prodPart.split('(Pkg:')[0].trim()
              : prodPart;
      final pkg =
          prodPart.contains('(Pkg:')
              ? prodPart.split('(Pkg:')[1].replaceAll(')', '').trim()
              : '';

      final detailParts = detailsPart.split(', ');
      final qty =
          detailParts.isNotEmpty
              ? detailParts[0].replaceAll('Qty: ', '').trim()
              : '';
      final mrp =
          detailParts.length > 1
              ? detailParts[1].replaceAll('MRP: ', '').trim()
              : '';
      final offer =
          detailParts.length > 2
              ? detailParts[2].replaceAll('Offer: ', '').trim()
              : '';
      final total =
          detailParts.length > 3
              ? detailParts[3].replaceAll('Total: ', '').trim()
              : '';

      tableData.add([prodName, pkg, qty, mrp, offer, total]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.TableHelper.fromTextArray(
          context: null,
          headerStyle: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
          cellStyle: const pw.TextStyle(fontSize: 9),
          data: tableData,
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Next Visit Date: $nextVisit',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            pw.Text(
              'GRAND TOTAL: $grandTotal',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Future<pw.Widget> _buildProblemSection(
    String problem,
    pw.Font font,
    pw.Font bold,
  ) async {
    if (problem.isEmpty) return pw.Text('No problems identified.');

    final List<pw.Widget> cropSections = [];
    
    // Split by crop headers: "--- Crop: $name ---"
    final rawChunks = problem.split('--- Crop: ');
    
    for (var chunk in rawChunks) {
      if (chunk.trim().isEmpty) continue;

      final parts = chunk.split(' ---\n');
      String cropName = 'Report';
      String problemContent = chunk;

      if (parts.length >= 2) {
        cropName = parts[0].trim();
        problemContent = parts[1].trim();
      }

      final List<pw.Widget> problemWidgets = [];
      final problemItems = problemContent.split(', ');

      for (var item in problemItems) {
        if (item.trim().isEmpty) continue;

        if (item.contains('{img:')) {
          final itemName = item.split('{img:')[0].trim();
          final imageUrl = item.split('{img:')[1].replaceAll('}', '').trim();

          pw.Widget imageWidget;
          try {
            final image = await _loadNetworkImageWithTimeout(imageUrl);
            if (image != null) {
              imageWidget = pw.Container(
                height: 120,
                width: 180,
                child: pw.Image(image, fit: pw.BoxFit.cover),
              );
            } else {
              imageWidget = pw.Text('Image timeout / failed to load', style: const pw.TextStyle(fontSize: 7, color: PdfColors.red));
            }
          } catch (e) {
            imageWidget = pw.Text('Image failed to load', style: const pw.TextStyle(fontSize: 7, color: PdfColors.red));
          }

          problemWidgets.add(
            pw.Container(
              width: 180,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(itemName, style: pw.TextStyle(font: bold, fontSize: 9)),
                  pw.SizedBox(height: 4),
                  imageWidget,
                ],
              ),
            ),
          );
        } else {
          problemWidgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.grey200),
              ),
              child: pw.Text(item.trim(), style: const pw.TextStyle(fontSize: 9)),
            ),
          );
        }
      }

      cropSections.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (parts.length >= 2) // Only show header if it was actually a crop chunk
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8, top: 4),
                child: pw.Text(
                  'Crop: $cropName',
                  style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.green800),
                ),
              ),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: problemWidgets,
            ),
            pw.SizedBox(height: 16),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: cropSections,
    );
  }

  static Future<pw.Widget> _parseTextWithImages(
    String text,
    pw.Font font,
    pw.Font bold, {
    double fontSize = 10,
  }) async {
    final regex = RegExp(r'\{img:\s*(.*?)\}');
    final List<pw.Widget> widgets = [];

    int lastMatchEnd = 0;
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return pw.Text(text, style: pw.TextStyle(fontSize: fontSize));
    }

    for (final match in matches) {
      final beforeText = text.substring(lastMatchEnd, match.start).trim();
      if (beforeText.isNotEmpty) {
        widgets.add(
          pw.Text(beforeText, style: pw.TextStyle(fontSize: fontSize)),
        );
      }

      final url = match.group(1) ?? '';
      try {
        final image = await _loadNetworkImageWithTimeout(url);
        if (image != null) {
          widgets.add(
            pw.Container(
              height: 100,
              width: 150,
              margin: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Image(image, fit: pw.BoxFit.cover),
            ),
          );
        } else {
          widgets.add(
            pw.Text(
              'Error loading image (timeout)',
              style: pw.TextStyle(fontSize: fontSize - 2, color: PdfColors.red),
            ),
          );
        }
      } catch (e) {
        widgets.add(
          pw.Text(
            'Error loading image',
            style: pw.TextStyle(fontSize: fontSize - 2, color: PdfColors.red),
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    final afterText = text.substring(lastMatchEnd).trim();
    if (afterText.isNotEmpty) {
      widgets.add(pw.Text(afterText, style: pw.TextStyle(fontSize: fontSize)));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  static Future<void> generateCallLogReport({
    required List<Map<String, dynamic>> logs,
    required String executiveName,
    required DateTimeRange dateRange,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final dateFormat = DateFormat('dd MMM yyyy');
    final startStr = dateFormat.format(dateRange.start);
    final endStr = dateFormat.format(dateRange.end);

    int totalSeconds = 0;
    for (var log in logs) {
      totalSeconds += (log['duration_seconds'] as int? ?? 0);
    }

    String formatDuration(int seconds) {
      if (seconds < 60) return '${seconds}s';
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes}m ${remainingSeconds}s';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        header:
            (context) => pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'NATURE BIOTIC',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green,
                          ),
                        ),
                        pw.Text(
                          'Executive Performance Report - Call Logs',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Date range: $startStr - $endStr',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 10),
              ],
            ),
        build:
            (context) => [
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          'EXECUTIVE NAME',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          executiveName,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'TOTAL CALLS',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          logs.length.toString(),
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'TOTAL DURATION',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          formatDuration(totalSeconds),
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.green700,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                columnWidths: {
                  0: const pw.FixedColumnWidth(80),
                  1: const pw.FixedColumnWidth(80),
                  2: const pw.FixedColumnWidth(40),
                },
                data: <List<String>>[
                  [
                    'Date & Time',
                    'Farmer / Number',
                    'Duration',
                    'Call Summary',
                  ],
                  ...logs.map((log) {
                    final date = DateTime.parse(log['created_at']);
                    final farmerName = log['farmers']?['name'] ?? 'Direct Call';
                    final number = log['phone_number'] ?? 'N/A';
                    return [
                      DateFormat('dd MMM, hh:mm a').format(date),
                      '$farmerName\n$number',
                      formatDuration(log['duration_seconds'] ?? 0),
                      log['summary'] ?? 'No summary',
                    ];
                  }),
                ],
              ),
            ],
        footer:
            (context) => pw.Column(
              children: [
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Nature Biotic Management Report',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey500,
                      ),
                    ),
                    pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      ),
    );

    await _shareOrPrintPdf(
      bytes: await pdf.save(),
      filename:
          'CallLogReport_${executiveName.replaceAll(' ', '_')}_${startStr}_to_$endStr.pdf',
    );
  }

  static Future<Uint8List> generateStockChallanBytes({
    required List<Map<String, dynamic>> items,
    required String farmName,
    required String farmerName,
    required String cropName,
    required String transactionType,
    required DateTime date,
    String? farmerAddress,
    String? farmerContact,
    String? dcNumber,
    String? placeOfSupply,
    String? customerGstin,
  }) async {
    // Fetch logged-in user profile to check for signature
    String? signatureUrl;
    try {
      final profile = await SupabaseService.getProfile();
      signatureUrl = profile?['signature_url'];
    } catch (_) {}

    String companyGstinValue = '33EFZPS9942RIZT';
    try {
      final config = await SupabaseService.getBillingConfig();
      if (config['company_gstin'] != null && config['company_gstin'].toString().isNotEmpty) {
        companyGstinValue = config['company_gstin'].toString();
      } else if (config['gstin'] != null && config['gstin'].toString().isNotEmpty) {
        companyGstinValue = config['gstin'].toString();
      }
    } catch (_) {}

    pw.ImageProvider? signatureImage;
    if (signatureUrl != null && signatureUrl.isNotEmpty) {
      signatureImage = await _loadNetworkImageWithTimeout(signatureUrl);
    }

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    String cleanPlaceOfSupply = placeOfSupply ?? '';
    if (cleanPlaceOfSupply.contains(' | Keywords: ')) {
      cleanPlaceOfSupply = cleanPlaceOfSupply.split(' | Keywords: ').last.trim();
    } else if (cleanPlaceOfSupply.contains('Keywords: ')) {
      cleanPlaceOfSupply = cleanPlaceOfSupply.split('Keywords: ').last.trim();
    }

    final dateStr = DateFormat('dd MMM yyyy').format(date);
    double grandTotal = 0;
    for (var item in items) {
      grandTotal += (item['price'] as double? ?? 0) * (item['quantity'] as double? ?? 0);
    }

    // Load logo via rootBundle â€” the reliable way for PDF generation
    pw.MemoryImage? logo;
    try {
      final ByteData data = await rootBundle.load('assets/challan_logo.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      // Logo not available, render without it
    }

    // Helper: table cell widget
    pw.Widget cell(String text, {
      bool bold = false,
      double fontSize = 10,
      pw.Alignment align = pw.Alignment.center,
      pw.EdgeInsets? padding,
    }) {
      return pw.Container(
        padding: padding ?? const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(font: bold ? boldFont : font, fontSize: fontSize),
        ),
      );
    }

    // Helper: label-value row (e.g. "D.C No  :  value")
    // Uses Expanded so long values wrap cleanly without breaking alignment
    pw.Widget labelValue(String label, String value, {double labelW = 70}) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: labelW,
            child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
          ),
          pw.Text(':  ', style: pw.TextStyle(font: font, fontSize: 10)),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10)),
          ),
        ],
      );
    }

    final int dataRows = items.length;
    final int totalRows = dataRows < 15 ? 15 : dataRows;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [

                // â”€â”€â”€ HEADER: Logo + Company Info | Delivery Challan title â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Left side: logo + company details
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                          ),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              // Logo
                              if (logo != null)
                                pw.Container(
                                  width: 72,
                                  height: 72,
                                  margin: const pw.EdgeInsets.only(right: 12),
                                  child: pw.Image(logo),
                                ),
                              // Company text
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text('SAIRAM AGRI INPUTS',
                                      style: pw.TextStyle(font: boldFont, fontSize: 12)),
                                  pw.SizedBox(height: 3),
                                  pw.Text('644C (1), Behind PACR Statue,',
                                      style: pw.TextStyle(font: font, fontSize: 8.5)),
                                  pw.Text('Tenkasi Road, Rajapalayam - 626117.',
                                      style: pw.TextStyle(font: font, fontSize: 8.5)),
                                  pw.Text('Tamil Nadu, India',
                                      style: pw.TextStyle(font: font, fontSize: 8.5)),
                                  pw.Text('GSTIN $companyGstinValue',
                                      style: pw.TextStyle(font: font, fontSize: 8.5)),
                                  pw.Text('Contact No - 99443 25408, 96008 61226',
                                      style: pw.TextStyle(font: font, fontSize: 8.5)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Right side: Delivery Challan title (centered)
                      pw.Expanded(
                        flex: 4,
                        child: pw.Container(
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                          child: pw.Text(
                            'Delivery Challan',
                            style: pw.TextStyle(font: boldFont, fontSize: 22),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // â”€â”€â”€ DC NO / DATE  |  PLACE OF SUPPLY â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 1,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              labelValue('D.C No', dcNumber ?? ''),
                              pw.SizedBox(height: 4),
                              labelValue('D.C Date', dateStr),
                            ],
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: labelValue('Place of Supply', cleanPlaceOfSupply),
                        ),
                      ),
                    ],
                  ),
                ),

                // â”€â”€â”€ CUSTOMER INFO â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      labelValue('Customer Name', farmerName, labelW: 100),
                      pw.SizedBox(height: 3),
                      labelValue('Address', farmerAddress ?? farmName, labelW: 100),
                      pw.SizedBox(height: 3),
                      labelValue('Contact No', farmerContact ?? '', labelW: 100),
                      if (customerGstin != null && customerGstin.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        labelValue('GSTIN', customerGstin, labelW: 100),
                      ],
                    ],
                  ),
                ),

                // â”€â”€â”€ PRODUCT TABLE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                pw.Table(
                  // Only vertical lines between columns â€” no horizontal lines between rows
                  border: const pw.TableBorder(
                    left: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
                  ),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(38),
                    1: const pw.FlexColumnWidth(3.5),
                    2: const pw.FlexColumnWidth(2.0),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(2.0),
                  },
                  children: [
                    // Header row â€” has a bottom border to separate it from data
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                      ),
                      children: [
                        cell('S.No', bold: true, fontSize: 11),
                        cell('Product Name', bold: true, fontSize: 11),
                        cell('Package Size', bold: true, fontSize: 11),
                        cell('Quantity', bold: true, fontSize: 11),
                        cell('Sale Value', bold: true, fontSize: 11),
                      ],
                    ),
                    // Data rows + empty filler rows (NO lines between them)
                    ...List.generate(totalRows, (i) {
                      if (i < dataRows) {
                        final item = items[i];
                        final qty = item['quantity'] as double? ?? 0;
                        final price = item['price'] as double? ?? 0;
                        final total = qty * price;
                        return pw.TableRow(
                          children: [
                            cell('${i + 1}'),
                            cell(item['name'] ?? '', align: pw.Alignment.centerLeft),
                            cell(item['unit'] ?? ''),
                            cell(qty % 1 == 0 ? qty.toInt().toString() : qty.toString()),
                            cell(total.toStringAsFixed(2), align: pw.Alignment.centerRight),
                          ],
                        );
                      }
                      // Empty filler row
                      return pw.TableRow(
                        children: List.generate(5, (_) => cell('', padding: const pw.EdgeInsets.symmetric(vertical: 10))),
                      );
                    }),
                  ],
                ),

                // â”€â”€â”€ TOTAL ROW â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(38),
                    1: const pw.FlexColumnWidth(3.5),
                    2: const pw.FlexColumnWidth(2.0),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(2.0),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        cell(''),
                        cell('Total', bold: true, fontSize: 11),
                        cell(''),
                        cell(''),
                        cell(grandTotal.toStringAsFixed(2), bold: true, align: pw.Alignment.centerRight),
                      ],
                    ),
                  ],
                ),

                // â”€â”€â”€ FOOTER: Terms | Authorized Signature | Bank Details â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                pw.Container(
                  height: 90,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                  ),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left Column: Terms + Bank Details
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Terms and Conditions',
                              style: pw.TextStyle(font: boldFont, fontSize: 9)),
                          pw.SizedBox(height: 20),
                          pw.Text('Bank Details',
                              style: pw.TextStyle(font: boldFont, fontSize: 9)),
                        ],
                      ),
                      // Right Column: Authorized Signature Label + Signature Image Preview
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Authorized Signature',
                              style: pw.TextStyle(font: boldFont, fontSize: 11)),
                          if (signatureImage != null) ...[
                            pw.SizedBox(height: 4),
                            pw.Container(
                              height: 35,
                              width: 90,
                              child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                            ),
                          ] else ...[
                            pw.SizedBox(height: 35),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  static Future<void> generateStockChallan({
    required List<Map<String, dynamic>> items,
    required String farmName,
    required String farmerName,
    required String cropName,
    required String transactionType,
    required DateTime date,
    String? farmerAddress,
    String? farmerContact,
    String? dcNumber,
    String? placeOfSupply,
    String? customerGstin,
  }) async {
    final bytes = await generateStockChallanBytes(
      items: items,
      farmName: farmName,
      farmerName: farmerName,
      cropName: cropName,
      transactionType: transactionType,
      date: date,
      farmerAddress: farmerAddress,
      farmerContact: farmerContact,
      dcNumber: dcNumber,
      placeOfSupply: placeOfSupply,
      customerGstin: customerGstin,
    );

    final nameFormatted = farmName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    await _shareOrPrintPdf(
      bytes: bytes,
      filename: 'DeliveryChallan_${nameFormatted}_${DateFormat('ddMMMyy').format(date)}.pdf',
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1, color: PdfColors.grey),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Thank you for choosing Nature Biotic for a sustainable future.',
              style: pw.TextStyle(
                fontSize: 9,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Future<void> generateMultiFarmStockReport({
    required List<Map<String, dynamic>> farmData,
    required DateTime date,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(date);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        header:
            (context) => pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'NATURE BIOTIC',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green,
                          ),
                        ),
                        pw.Text(
                          'Consolidated Farm Stock Report',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'Generated: $dateStr',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 10),
              ],
            ),
        build:
            (context) => [
              for (var farm in farmData) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: const pw.BoxDecoration(color: PdfColors.green50),
                  child: pw.Text(
                    'FARM: ${farm['farmName'].toString().toUpperCase()}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green900,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                if ((farm['balances'] as List).isEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 8, bottom: 20),
                    child: pw.Text(
                      'No stock in hand for this farm.',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  )
                else ...[
                  pw.TableHelper.fromTextArray(
                    headerStyle: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.green700,
                    ),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1),
                    },
                    data: <List<String>>[
                      ['Item Name', 'Packet Size', 'Balance Qty'],
                      ...(farm['balances'] as List).map(
                        (b) => [
                          b['item'].toString(),
                          b['unit'].toString(),
                          b['balance'].toString().replaceAll(
                            RegExp(r'\.0$'),
                            '',
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 25),
                ],
              ],
            ],
        footer:
            (context) => pw.Column(
              children: [
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Nature Biotic Stock Management System',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey500,
                      ),
                    ),
                    pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      ),
    );

    final filename =
        'NatureBiotic_StockReport_${DateFormat('ddMMMyy').format(date)}.pdf';
    await _shareOrPrintPdf(bytes: await pdf.save(), filename: filename);
  }

  static Future<void> generateExpenseReport({
    required List<Map<String, dynamic>> history,
    required DateTimeRange dateRange,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final dateFormat = DateFormat('dd MMM yyyy');
    final startStr = dateFormat.format(dateRange.start);
    final endStr = dateFormat.format(dateRange.end);

    double totalAllotted = 0;
    double totalSpent = 0;
    List<Map<String, dynamic>> allItems = [];

    for (var h in history) {
      totalAllotted += double.tryParse(h['amount_allotted'].toString()) ?? 0.0;
      final items = List<Map<String, dynamic>>.from(h['expense_items'] ?? []);
      for (var item in items) {
        totalSpent += double.tryParse(item['amount'].toString()) ?? 0.0;
        allItems.add({
          ...item,
          'executive': h['profiles']?['full_name'] ?? 'Unknown',
          'status': h['status'],
          'return_status': h['return_status'],
        });
      }
    }

    // Sort by date descending
    allItems.sort((a, b) => 
        DateTime.parse(b['created_at'].toString()).compareTo(
        DateTime.parse(a['created_at'].toString())));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'NATURE BIOTIC',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green,
                      ),
                    ),
                    pw.Text(
                      'Master Expense & Audit Report',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Report Period: $startStr - $endStr', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Generated on: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) => [
          // Financial Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _statCol('TOTAL ALLOTTED', 'Rs. ${totalAllotted.toStringAsFixed(2)}', PdfColors.blue800),
                _statCol('TOTAL SPENT', 'Rs. ${totalSpent.toStringAsFixed(2)}', PdfColors.red800),
                _statCol('REMAINING', 'Rs. ${(totalAllotted - totalSpent).toStringAsFixed(2)}', PdfColors.green800),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Detailed Expense Items', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            columnWidths: {
              0: const pw.FixedColumnWidth(80),
              1: const pw.FixedColumnWidth(80),
              2: const pw.FixedColumnWidth(60),
              3: const pw.FixedColumnWidth(50),
              4: const pw.FixedColumnWidth(70),
            },
            data: <List<String>>[
              ['Date', 'Executive', 'Category', 'Amount', 'Status'],
              ...allItems.map((item) {
                final date = DateFormat('dd MMM yy, hh:mm a').format(DateTime.parse(item['created_at']));
                String status = item['status'] ?? 'N/A';
                if (item['return_status'] == 'PENDING') status = 'Return Pending';
                return [
                  date,
                  item['executive'],
                  item['category'],
                  'Rs. ${item['amount']}',
                  status,
                ];
              }),
            ],
          ),
        ],
        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Nature Biotic Financial Control System', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
              ],
            ),
          ],
        ),
      ),
    );

    await _shareOrPrintPdf(
      bytes: await pdf.save(),
      filename: 'ExpenseReport_${startStr.replaceAll(' ', '_')}_to_${endStr.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _statCol(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  static String numberToWords(int number) {
    if (number == 0) return 'Zero';
    final List<String> units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
    ];
    final List<String> tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String convert(int n) {
      if (n < 20) return units[n];
      if (n < 100) return tens[n ~/ 10] + (n % 10 != 0 ? ' ${units[n % 10]}' : '');
      if (n < 1000) return '${units[n ~/ 100]} Hundred' + (n % 100 != 0 ? ' and ${convert(n % 100)}' : '');
      if (n < 100000) return '${convert(n ~/ 1000)} Thousand' + (n % 1000 != 0 ? ' ${convert(n % 1000)}' : '');
      if (n < 10000000) return '${convert(n ~/ 100000)} Lakh' + (n % 100000 != 0 ? ' ${convert(n % 100000)}' : '');
      return '${convert(n ~/ 10000000)} Crore' + (n % 10000000 != 0 ? ' ${convert(n % 10000000)}' : '');
    }
    return convert(number);
  }

  static Future<Uint8List> generatePaymentReceiptBytes({
    required String receiptNo,
    required DateTime date,
    required String customerName,
    required String contactNo,
    required String customerAddress,
    required double amount,
    required String purpose,
    double accAmount = 0.0,
    double balanceDue = 0.0,
    String paymentMethod = 'Cash',
  }) async {
    String companyGstinValue = '33EFZPS9942RIZT';
    try {
      final config = await SupabaseService.getBillingConfig();
      if (config['company_gstin'] != null && config['company_gstin'].toString().isNotEmpty) {
        companyGstinValue = config['company_gstin'].toString();
      } else if (config['gstin'] != null && config['gstin'].toString().isNotEmpty) {
        companyGstinValue = config['gstin'].toString();
      }
    } catch (_) {}

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    pw.MemoryImage? logo;
    try {
      final ByteData data = await rootBundle.load('assets/challan_logo.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      try {
        final ByteData data = await rootBundle.load('assets/logo.png');
        logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {}
    }

    const pageFormat = PdfPageFormat(
      210 * PdfPageFormat.mm,
      148 * PdfPageFormat.mm,
      marginAll: 8 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return _buildReceiptWidget(
            {
              'receiptNo': receiptNo,
              'date': date,
              'customerName': customerName,
              'contactNo': contactNo,
              'customerAddress': customerAddress,
              'amount': amount,
              'purpose': purpose,
              'accAmount': accAmount,
              'balanceDue': balanceDue,
              'paymentMethod': paymentMethod,
              'companyGstin': companyGstinValue,
            },
            font,
            boldFont,
            logo,
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> generatePaymentReceipt({
    required String receiptNo,
    required DateTime date,
    required String customerName,
    required String contactNo,
    required String customerAddress,
    required double amount,
    required String purpose,
    double accAmount = 0.0,
    double balanceDue = 0.0,
    String paymentMethod = 'Cash',
  }) async {
    final bytes = await generatePaymentReceiptBytes(
      receiptNo: receiptNo,
      date: date,
      customerName: customerName,
      contactNo: contactNo,
      customerAddress: customerAddress,
      amount: amount,
      purpose: purpose,
      accAmount: accAmount,
      balanceDue: balanceDue,
      paymentMethod: paymentMethod,
    );

    final filename =
        'NatureBiotic_Receipt_${receiptNo.replaceAll('/', '_')}.pdf';
    await _shareOrPrintPdf(bytes: bytes, filename: filename);
  }

  static Future<void> generateBulkReceiptsPdf({
    required List<Map<String, dynamic>> receiptsData,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    String companyGstinValue = '33EFZPS9942RIZT';
    try {
      final config = await SupabaseService.getBillingConfig();
      if (config['company_gstin'] != null && config['company_gstin'].toString().isNotEmpty) {
        companyGstinValue = config['company_gstin'].toString();
      } else if (config['gstin'] != null && config['gstin'].toString().isNotEmpty) {
        companyGstinValue = config['gstin'].toString();
      }
    } catch (_) {}

    pw.MemoryImage? logo;
    try {
      final ByteData data = await rootBundle.load('assets/challan_logo.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      try {
        final ByteData data = await rootBundle.load('assets/logo.png');
        logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {}
    }

    // A4 Portrait: 210mm x 297mm
    // 3 receipts per page -> 99mm height each
    const double receiptHeight = 99 * PdfPageFormat.mm;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(5 * PdfPageFormat.mm),
        build: (context) {
          final List<pw.Widget> widgets = [];
          for (int i = 0; i < receiptsData.length; i++) {
            final data = receiptsData[i];
            widgets.add(
              pw.Container(
                height: receiptHeight - (10 * PdfPageFormat.mm),
                child: _buildReceiptWidget(
                  {
                    ...data,
                    'companyGstin': companyGstinValue,
                  },
                  font,
                  boldFont,
                  logo,
                  isBulk: true,
                ),
              ),
            );

            // Add dotted line between receipts on the same page
            if ((i + 1) % 3 != 0 && i != receiptsData.length - 1) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2 * PdfPageFormat.mm),
                  child: pw.Row(
                    children: List.generate(
                      40,
                      (index) => pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                          child: pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
          }
          return widgets;
        },
      ),
    );

    await _shareOrPrintPdf(
      bytes: await pdf.save(),
      filename: 'NatureBiotic_BulkReceipts_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildReceiptWidget(
    Map<String, dynamic> data,
    pw.Font font,
    pw.Font boldFont,
    pw.MemoryImage? logo, {
    bool isBulk = false,
  }) {
    final String receiptNo = data['receiptNo']?.toString() ?? 'N/A';
    final DateTime date = data['date'] ?? DateTime.now();
    final String customerName = data['customerName']?.toString() ?? 'N/A';
    final String contactNo = data['contactNo']?.toString() ?? 'N/A';
    final String customerAddress = data['customerAddress']?.toString() ?? 'N/A';
    final double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
    final String purpose = data['purpose']?.toString() ?? 'N/A';
    final double accAmount = double.tryParse(data['accAmount']?.toString() ?? '0') ?? 0.0;
    final double balanceDue = double.tryParse(data['balanceDue']?.toString() ?? '0') ?? 0.0;
    final String paymentMethod = data['paymentMethod']?.toString() ?? 'Cash';
    final String companyGstin = data['companyGstin']?.toString() ?? '33EFZPS9942RIZT';

    final dateStr = DateFormat('dd MMM yyyy').format(date);
    final amountWords = numberToWords(amount.toInt());

    // Scale fonts slightly down for bulk print to ensure fit
    final double baseSize = isBulk ? 8.0 : 9.0;
    final double titleSize = isBulk ? 18.0 : 22.0;

    pw.Widget dottedField(String text) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.only(left: 2, bottom: 1),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(style: pw.BorderStyle.dotted, color: PdfColors.grey600),
            ),
          ),
          child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: baseSize)),
        ),
      );
    }

    pw.Widget amountBox(String label, String value) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: isBulk ? 60 : 72,
            child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: baseSize - 0.5)),
          ),
          pw.Container(
            width: isBulk ? 70 : 80,
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Text('Rs. $value', style: pw.TextStyle(font: font, fontSize: baseSize - 0.5)),
          ),
        ],
      );
    }

    pw.Widget checkBox(String label, bool checked) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: baseSize - 0.5)),
          pw.Container(
            width: isBulk ? 8 : 10,
            height: isBulk ? 8 : 10,
            margin: const pw.EdgeInsets.only(left: 2, right: 5),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600)),
            child: checked
                ? pw.Center(
                    child: pw.Text('X',
                        style: pw.TextStyle(font: boldFont, fontSize: baseSize - 2)))
                : null,
          ),
        ],
      );
    }

    return pw.Stack(
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Header
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: isBulk ? 140 : 155,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(right: pw.BorderSide(color: PdfColors.grey400)),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logo != null)
                          pw.Container(width: isBulk ? 35 : 44, height: isBulk ? 35 : 44, child: pw.Image(logo)),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('SAIRAM AGRI INPUTS',
                                  style: pw.TextStyle(font: boldFont, fontSize: baseSize + 1)),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                isBulk 
                                  ? 'Tenkasi Road, Rajapalayam.\nGSTIN $companyGstin'
                                  : '644C (1), Behind PACR Statue,\nTenkasi Road, Rajapalayam - 626117.\nTamil Nadu, India\nGSTIN $companyGstin',
                                style: pw.TextStyle(font: font, fontSize: baseSize - 2, lineSpacing: 1.2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Payment Receipt',
                              style: pw.TextStyle(font: boldFont, fontSize: titleSize)),
                          pw.SizedBox(height: isBulk ? 5 : 12),
                          pw.Row(children: [
                            pw.Text('No : ', style: pw.TextStyle(font: font, fontSize: baseSize)),
                            dottedField(receiptNo),
                            pw.SizedBox(width: 8),
                            pw.Text('Date : ', style: pw.TextStyle(font: font, fontSize: baseSize)),
                            dottedField(dateStr),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Customer Details
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(children: [
                    pw.Text('Customer Name : ', style: pw.TextStyle(font: font, fontSize: baseSize)),
                    dottedField(customerName),
                    pw.SizedBox(width: 12),
                    pw.Text('Contact No : ', style: pw.TextStyle(font: font, fontSize: baseSize)),
                    dottedField(contactNo),
                  ]),
                  pw.SizedBox(height: 8),
                  pw.Row(children: [
                    pw.Text('Customer Address : ', style: pw.TextStyle(font: font, fontSize: baseSize)),
                    dottedField(customerAddress.replaceAll('\n', ' ')),
                  ]),
                ],
              ),
            ),

            // Payment Details
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('An Amount of  ', style: pw.TextStyle(font: font, fontSize: baseSize)),
                        pw.Container(
                          width: isBulk ? 75 : 88,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey500),
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                          child: pw.Text('Rs. ${amount.toInt()}',
                              style: pw.TextStyle(font: font, fontSize: baseSize)),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text('in words  ', style: pw.TextStyle(font: font, fontSize: baseSize)),
                        dottedField(amountWords + ' Rupees Only'),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(children: [
                      pw.Text('For the purpose of  ', style: pw.TextStyle(font: font, fontSize: baseSize)),
                      dottedField(purpose),
                    ]),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            amountBox('Acc. Amount', accAmount.toInt().toString()),
                            pw.SizedBox(height: 5),
                            amountBox('This Payment', amount.toInt().toString()),
                            pw.SizedBox(height: 5),
                            amountBox('Balance Due', balanceDue.toInt().toString()),
                          ],
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 14),
                            child: pw.Row(children: [
                              pw.Text('Paid by  ', style: pw.TextStyle(font: font, fontSize: baseSize - 0.5)),
                              checkBox('Cash', paymentMethod.toLowerCase() == 'cash'),
                              checkBox('Bank', paymentMethod.toLowerCase() == 'bank'),
                              checkBox('Cheque', paymentMethod.toLowerCase() == 'cheque'),
                              checkBox('UPI', paymentMethod.toLowerCase() == 'upi'),
                              checkBox(
                                'Other',
                                !['cash', 'bank', 'cheque', 'upi'].contains(
                                  paymentMethod.toLowerCase(),
                                ),
                              ),
                            ]),
                          ),
                        ),
                        pw.Container(
                          width: isBulk ? 85 : 100,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Authorized Signature',
                                  style: pw.TextStyle(font: font, fontSize: baseSize - 0.5)),
                              pw.Text('for (Sairam Agri Inputs)',
                                  style: pw.TextStyle(
                                      font: font, fontSize: baseSize - 2, color: PdfColors.grey600)),
                              pw.SizedBox(height: 15),
                              pw.Row(children: [dottedField('')]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.Positioned.fill(
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500, width: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  static Future<Uint8List> generateInvoiceBytes({
    required Map<String, dynamic> bill,
    required String farmName,
    required String farmerName,
    required String cropName,
    required DateTime date,
    String? farmerAddress,
    String? farmerContact,
    String? placeOfSupply,
  }) async {
    // Fetch dynamic billing configuration and load fonts in parallel
    final setupResults = await Future.wait([
      SupabaseService.getBillingConfig().catchError((e) {
        debugPrint('Error loading dynamic billing config: $e');
        return <String, dynamic>{};
      }),
      PdfGoogleFonts.robotoRegular(),
      PdfGoogleFonts.robotoBold(),
    ]);

    final Map<String, dynamic> billingConfig = setupResults[0] as Map<String, dynamic>;
    final pw.Font font = setupResults[1] as pw.Font;
    final pw.Font boldFont = setupResults[2] as pw.Font;

    final accountName = billingConfig['account_name'] ?? 'SAIRAM AGRO MARKETERS';
    final accountNo = billingConfig['account_no'] ?? '611505016643';
    final ifscCode = billingConfig['ifsc_code'] ?? 'ICIC0006115';
    final bankName = billingConfig['bank_name'] ?? 'ICICI Bank';
    final branch = billingConfig['branch'] ?? 'Rajapalayam';
    final companyGstin = billingConfig['company_gstin']?.toString() ?? billingConfig['gstin']?.toString() ?? '33EFZPS9942RIZT';

    final qrUrl = billingConfig['qr_url']?.toString() ?? '';
    final signatureUrl = billingConfig['signature_url']?.toString() ?? '';

    // Load QR and signature images in parallel
    final imageResults = await Future.wait([
      qrUrl.isNotEmpty
          ? _loadNetworkImageWithTimeout(qrUrl)
          : Future<pw.ImageProvider?>.value(null),
      signatureUrl.isNotEmpty
          ? _loadNetworkImageWithTimeout(signatureUrl)
          : Future<pw.ImageProvider?>.value(null),
    ]);

    final pw.ImageProvider? dynamicQrImage = imageResults[0];
    final pw.ImageProvider? dynamicSignatureImage = imageResults[1];

    final pdf = pw.Document();

    String cleanPlaceOfSupply = placeOfSupply ?? bill['place_of_supply']?.toString() ?? '';
    final String customerGstin = bill['customer_gstin']?.toString() ?? '';
    final String customCustomerName = bill['customer_name']?.toString() ?? '';
    final String displayCustomerName = customCustomerName.isNotEmpty ? customCustomerName : farmerName;
    if (cleanPlaceOfSupply.contains(' | Keywords: ')) {
      cleanPlaceOfSupply = cleanPlaceOfSupply.split(' | Keywords: ').last.trim();
    } else if (cleanPlaceOfSupply.contains('Keywords: ')) {
      cleanPlaceOfSupply = cleanPlaceOfSupply.split('Keywords: ').last.trim();
    }

    final dateStr = DateFormat('dd MMM yyyy').format(date);

    final List items = bill['items'] is String 
        ? jsonDecode(bill['items']) 
        : (bill['items'] as List? ?? []);
    final String discountType = bill['discount_type']?.toString() ?? 'none';
    final double discountValue = double.tryParse(bill['discount_value']?.toString() ?? '0') ?? 0.0;

    // Calculate totals
    double subtotal = 0.0;       // Sum of original tax-exclusive amount
    double totalDiscount = 0.0;  // Sum of tax-exclusive discount
    double totalTaxable = 0.0;   // Sum of net tax-exclusive base
    double totalTax = 0.0;
    double totalQty = 0.0;

    final Map<double, double> cgstGroup = {};
    final Map<double, double> sgstGroup = {};

    double inclusiveSubtotal = 0.0;
    for (var item in items) {
      final double qty = double.tryParse((item['qty'] ?? item['quantity'])?.toString() ?? '0') ?? 0.0;
      final double offerPrice = double.tryParse(item['offer_price']?.toString() ?? '0') ?? 0.0;
      inclusiveSubtotal += offerPrice * qty;
    }

    double totalInclusiveDiscount = 0.0;
    if (discountType == 'percentage') {
      totalInclusiveDiscount = inclusiveSubtotal * (discountValue / 100.0);
    } else if (discountType == 'flat') {
      totalInclusiveDiscount = discountValue;
    }

    final calculatedItems = [];

    for (var item in items) {
      final double qty = double.tryParse((item['qty'] ?? item['quantity'])?.toString() ?? '0') ?? 0.0;
      final double offerPrice = double.tryParse(item['offer_price']?.toString() ?? '0') ?? 0.0;
      final double taxPercentage = double.tryParse(item['tax_percentage']?.toString() ?? '0') ?? 0.0;

      final double lineOriginalTotalInclusive = offerPrice * qty;
      
      double lineInclusiveDiscount = 0.0;
      if (inclusiveSubtotal > 0) {
        lineInclusiveDiscount = totalInclusiveDiscount * (lineOriginalTotalInclusive / inclusiveSubtotal);
      }
      if (lineInclusiveDiscount > lineOriginalTotalInclusive) {
        lineInclusiveDiscount = lineOriginalTotalInclusive;
      }

      final double lineDiscountedTotalInclusive = lineOriginalTotalInclusive - lineInclusiveDiscount;

      final double originalBaseRate = offerPrice / (1.0 + taxPercentage / 100.0);
      final double originalBaseAmount = qty * originalBaseRate;

      final double netTaxableBase = lineDiscountedTotalInclusive / (1.0 + taxPercentage / 100.0);
      final double lineTaxExclusiveDiscount = originalBaseAmount - netTaxableBase;

      final double cgstRate = taxPercentage / 2.0;
      final double sgstRate = taxPercentage / 2.0;

      double cgstAmt = 0.0;
      double sgstAmt = 0.0;
      if (taxPercentage > 0) {
        cgstAmt = netTaxableBase * (cgstRate / 100.0);
        cgstAmt = double.parse(cgstAmt.toStringAsFixed(2));
        
        sgstAmt = netTaxableBase * (sgstRate / 100.0);
        sgstAmt = double.parse(sgstAmt.toStringAsFixed(2));
      }

      subtotal += originalBaseAmount;
      totalDiscount += lineTaxExclusiveDiscount;
      totalTaxable += netTaxableBase;
      totalQty += qty;

      if (cgstRate > 0) {
        cgstGroup[cgstRate] = (cgstGroup[cgstRate] ?? 0.0) + cgstAmt;
        sgstGroup[sgstRate] = (sgstGroup[sgstRate] ?? 0.0) + sgstAmt;
      }

      calculatedItems.add({
        ...item,
        'rate': originalBaseRate,
        'amount': originalBaseAmount,
        'line_original_total': lineOriginalTotalInclusive,
        'line_discount': lineInclusiveDiscount,
        'line_discounted_total': lineDiscountedTotalInclusive,
        'taxable_value': netTaxableBase,
        'cgst_percentage': cgstRate,
        'cgst_amount': cgstAmt,
        'sgst_percentage': sgstRate,
        'sgst_amount': sgstAmt,
        'tax_amount': cgstAmt + sgstAmt,
      });
    }

    subtotal = double.parse(subtotal.toStringAsFixed(2));
    totalDiscount = double.parse(totalDiscount.toStringAsFixed(2));
    totalTaxable = double.parse(totalTaxable.toStringAsFixed(2));

    double cgstSum = 0.0;
    double sgstSum = 0.0;
    cgstGroup.forEach((rate, amt) {
      cgstGroup[rate] = double.parse(amt.toStringAsFixed(2));
      cgstSum += cgstGroup[rate]!;
    });
    sgstGroup.forEach((rate, amt) {
      sgstGroup[rate] = double.parse(amt.toStringAsFixed(2));
      sgstSum += sgstGroup[rate]!;
    });

    totalTax = cgstSum + sgstSum;
    final double rawGrandTotal = totalTaxable + totalTax;
    final double grandTotalRounded = rawGrandTotal.roundToDouble();
    final double rounding = grandTotalRounded - rawGrandTotal;

    final int dataRows = items.length;

    // Load logo via rootBundle
    pw.MemoryImage? logo;
    try {
      final ByteData data = await rootBundle.load('assets/challan_logo.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      // Logo not available
    }

    pw.ImageProvider? paymentQr;
    try {
      if (dynamicQrImage != null) {
        paymentQr = dynamicQrImage;
      } else {
        final ByteData data = await rootBundle.load('assets/images/payment_qr.png');
        paymentQr = pw.MemoryImage(data.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('Error loading payment_qr: $e');
    }

    pw.ImageProvider? signatureImage;
    try {
      if (dynamicSignatureImage != null) {
        signatureImage = dynamicSignatureImage;
      } else {
        final ByteData data = await rootBundle.load('assets/images/authorised_signature.png');
        signatureImage = pw.MemoryImage(data.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('Error loading authorised_signature: $e');
    }

    // Helper: table cell widget
    pw.Widget cell(String text, {
      bool bold = false,
      double fontSize = 8,
      pw.Alignment align = pw.Alignment.center,
      pw.EdgeInsets? padding,
    }) {
      return pw.Container(
        padding: padding ?? const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(font: bold ? boldFont : font, fontSize: fontSize),
        ),
      );
    }

    // Helper: item with description cell
    pw.Widget cellWithDesc(String name, String desc, {pw.Alignment align = pw.Alignment.centerLeft}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        alignment: align,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(name, style: pw.TextStyle(font: boldFont, fontSize: 8)),
            if (desc.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(desc, style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
            ],
          ],
        ),
      );
    }

    // Helper: qty with pcs cell
    pw.Widget qtyCell(double q) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        alignment: pw.Alignment.center,
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(q.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 8)),
            pw.Text('pcs', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
          ],
        ),
      );
    }

    // Helper: header cell widget
    pw.Widget headerCell(String text, double width, double height, {bool borderRight = true, bool bold = true}) {
      return pw.Container(
        width: width,
        height: height,
        alignment: pw.Alignment.center,
        decoration: borderRight
            ? const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
              )
            : null,
        child: pw.Text(
          text,
          style: pw.TextStyle(font: bold ? boldFont : font, fontSize: 8),
        ),
      );
    }

    // Helper: split CGST/SGST header cell
    pw.Widget splitGstHeader(String title, double widthPct, double widthAmt) {
      return pw.Container(
        width: widthPct + widthAmt,
        height: 30,
        decoration: const pw.BoxDecoration(
          border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
        ),
        child: pw.Column(
          children: [
            pw.Container(
              height: 15,
              alignment: pw.Alignment.center,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
              ),
              child: pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 8)),
            ),
            pw.Row(
              children: [
                pw.Container(
                  width: widthPct,
                  height: 15,
                  alignment: pw.Alignment.center,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                  ),
                  child: pw.Text('%', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                ),
                pw.Container(
                  width: widthAmt,
                  height: 15,
                  alignment: pw.Alignment.center,
                  child: pw.Text('Amt', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Helper: label-value row
    pw.Widget labelValue(String label, String value, {double labelW = 70}) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: labelW,
            child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
          ),
          pw.Text(':  ', style: pw.TextStyle(font: font, fontSize: 10)),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10)),
          ),
        ],
      );
    }

    final int totalRows = dataRows < 15 ? 15 : dataRows;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // HEADER: Logo + Company Info | Tax Invoice title
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                          ),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              if (logo != null)
                                pw.Container(
                                  width: 72,
                                  height: 72,
                                  margin: const pw.EdgeInsets.only(right: 12),
                                  child: pw.Image(logo),
                                ),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text('SAIRAM AGRI INPUTS',
                                      style: pw.TextStyle(font: boldFont, fontSize: 12)),
                                  pw.SizedBox(height: 3),
                                  pw.Text('644C (1), Behind PACR Statue,',
                                      style: pw.TextStyle(font: font, fontSize: 8.5)),
                                  pw.Text('Tenkasi Road, Rajapalayam - 626117.',
                                      style: pw.TextStyle(font: font, fontSize: 8.5)),
                                  pw.Text('Tamil Nadu, India',
                                      style: pw.TextStyle(font: font, fontSize: 8.5)),
                                  pw.Text('GSTIN $companyGstin',
                                      style: pw.TextStyle(font: font, fontSize: 8.5)),
                                  pw.Text('Contact No - 99443 25408, 96008 61226',
                                      style: pw.TextStyle(font: font, fontSize: 8.5)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 4,
                        child: pw.Container(
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                          child: pw.Text(
                            'Tax Invoice',
                            style: pw.TextStyle(font: boldFont, fontSize: 22),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // INVOICE NO / DATE | PLACE OF SUPPLY
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 1,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              labelValue('Invoice No', bill['challan_no'] ?? ''),
                              pw.SizedBox(height: 4),
                              labelValue('Invoice Date', dateStr),
                            ],
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: labelValue('Place of Supply', cleanPlaceOfSupply),
                        ),
                      ),
                    ],
                  ),
                ),

                // CUSTOMER INFO
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      labelValue('Customer Name', displayCustomerName, labelW: 100),
                      pw.SizedBox(height: 3),
                      labelValue('Address', farmerAddress ?? farmName, labelW: 100),
                      pw.SizedBox(height: 3),
                      labelValue('Contact No', farmerContact ?? '', labelW: 100),
                      if (customerGstin.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        labelValue('GSTIN', customerGstin, labelW: 100),
                      ],
                    ],
                  ),
                ),

                // HEADER ROW WITH SPLIT TAX
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      left: pw.BorderSide(color: PdfColors.black, width: 0.8),
                      right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                      bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      headerCell('S.No', 25, 30),
                      headerCell('Item & Description', 150, 30),
                      headerCell('HSN / SAC', 50, 30),
                      headerCell('Qty', 45, 30),
                      headerCell('Rate', 55, 30),
                      splitGstHeader('CGST', 35, 45),
                      splitGstHeader('SGST', 35, 45),
                      headerCell('Amount', 70, 30, borderRight: false),
                    ],
                  ),
                ),

                // PRODUCT TABLE DATA
                pw.Table(
                  border: const pw.TableBorder(
                    left: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
                  ),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(25),
                    1: const pw.FixedColumnWidth(150),
                    2: const pw.FixedColumnWidth(50),
                    3: const pw.FixedColumnWidth(45),
                    4: const pw.FixedColumnWidth(55),
                    5: const pw.FixedColumnWidth(35),
                    6: const pw.FixedColumnWidth(45),
                    7: const pw.FixedColumnWidth(35),
                    8: const pw.FixedColumnWidth(45),
                    9: const pw.FixedColumnWidth(70),
                  },
                  children: [
                    ...List.generate(totalRows, (i) {
                      if (i < dataRows) {
                        final item = calculatedItems[i];
                        final qty = double.tryParse((item['qty'] ?? item['quantity'])?.toString() ?? '0') ?? 0.0;
                        final double rate = item['rate'] as double;
                        final double amount = item['amount'] as double;
                        final double cgstAmt = item['cgst_amount'] as double;
                        final double sgstAmt = item['sgst_amount'] as double;
                        final double taxPercentage = double.tryParse(item['tax_percentage']?.toString() ?? '0') ?? 0.0;
                        final String itemName = item['name'] ?? '';
                        final String itemUnit = item['unit'] ?? '';
                        final String displayName = itemUnit.isNotEmpty ? '$itemName $itemUnit' : itemName;

                        return pw.TableRow(
                          children: [
                            cell('${i + 1}', fontSize: 8),
                            cellWithDesc(displayName, item['description'] ?? '', align: pw.Alignment.centerLeft),
                            cell(item['hsn_code'] ?? '', fontSize: 8),
                            qtyCell(qty),
                            cell(rate.toStringAsFixed(2), align: pw.Alignment.centerRight, fontSize: 8),
                            cell('${taxPercentage / 2}%', fontSize: 8),
                            cell(cgstAmt.toStringAsFixed(2), align: pw.Alignment.centerRight, fontSize: 8),
                            cell('${taxPercentage / 2}%', fontSize: 8),
                            cell(sgstAmt.toStringAsFixed(2), align: pw.Alignment.centerRight, fontSize: 8),
                            cell(amount.toStringAsFixed(2), align: pw.Alignment.centerRight, fontSize: 8),
                          ],
                        );
                      }
                      return pw.TableRow(
                        children: [
                          cell('', fontSize: 8),
                          cell('', fontSize: 8),
                          cell('', fontSize: 8),
                          cell('', fontSize: 8),
                          cell('', fontSize: 8),
                          cell('', fontSize: 8),
                          cell('', fontSize: 8),
                          cell('', fontSize: 8),
                          cell('', fontSize: 8),
                          cell('', fontSize: 8),
                        ],
                      );
                    }),
                  ],
                ),

                // TOTAL ROW
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(25),
                    1: const pw.FixedColumnWidth(150),
                    2: const pw.FixedColumnWidth(50),
                    3: const pw.FixedColumnWidth(45),
                    4: const pw.FixedColumnWidth(55),
                    5: const pw.FixedColumnWidth(35),
                    6: const pw.FixedColumnWidth(45),
                    7: const pw.FixedColumnWidth(35),
                    8: const pw.FixedColumnWidth(45),
                    9: const pw.FixedColumnWidth(70),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        cell('', fontSize: 8),
                        cell('Total', bold: true, fontSize: 8),
                        cell('', fontSize: 8),
                        cell(totalQty % 1 == 0 ? totalQty.toInt().toString() : totalQty.toString(), bold: true, fontSize: 8),
                        cell('', fontSize: 8),
                        cell('', fontSize: 8),
                        cell(cgstSum.toStringAsFixed(2), bold: true, align: pw.Alignment.centerRight, fontSize: 8),
                        cell('', fontSize: 8),
                        cell(sgstSum.toStringAsFixed(2), bold: true, align: pw.Alignment.centerRight, fontSize: 8),
                        cell(subtotal.toStringAsFixed(2), bold: true, align: pw.Alignment.centerRight, fontSize: 8),
                      ],
                    ),
                  ],
                ),

                // FOOTER PANEL WITH BANK & CALCS
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      left: pw.BorderSide(color: PdfColors.black, width: 0.8),
                      right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                      bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // LEFT PANEL: Total in words & Bank Details
                      pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Total In Words', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Indian Rupee ' + numberToIndianWords(grandTotalRounded),
                                style: pw.TextStyle(font: boldFont, fontSize: 8.5, fontStyle: pw.FontStyle.italic),
                              ),
                              pw.SizedBox(height: 12),
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('Account Name: $accountName', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                                      pw.Text('Account No : $accountNo', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                                      pw.Text('IFSC Code : $ifscCode', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                                      pw.Text('Bank Name : $bankName', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                                      pw.Text('Branch : $branch', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                                    ],
                                  ),
                                  if (paymentQr != null) ...[
                                    pw.Spacer(),
                                    pw.Container(
                                      height: 48,
                                      width: 48,
                                      child: pw.Image(paymentQr, fit: pw.BoxFit.contain),
                                    ),
                                    pw.SizedBox(width: 8),
                                    pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      mainAxisAlignment: pw.MainAxisAlignment.center,
                                      children: [
                                        pw.Text('Scan QR Code', style: pw.TextStyle(font: boldFont, fontSize: 7.5)),
                                        pw.Text('for the payment', style: pw.TextStyle(font: font, fontSize: 7.5)),
                                      ],
                                    ),
                                    pw.SizedBox(width: 15),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // RIGHT PANEL: Calculations Card
                      pw.Expanded(
                        flex: 4,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            children: [
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Sub Total', style: pw.TextStyle(font: font, fontSize: 8)),
                                  pw.Text(subtotal.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 8)),
                                ],
                              ),
                              if (totalDiscount > 0) ...[
                                pw.SizedBox(height: 3),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Discount', style: pw.TextStyle(font: font, fontSize: 8)),
                                    pw.Text('(-) ' + totalDiscount.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 8)),
                                  ],
                                ),
                              ],
                              ...cgstGroup.entries.map((e) {
                                if (e.value <= 0) return pw.SizedBox();
                                return pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 3),
                                  child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text('CGST${e.key} (${e.key}%)', style: pw.TextStyle(font: font, fontSize: 8)),
                                      pw.Text(e.value.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 8)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              ...sgstGroup.entries.map((e) {
                                if (e.value <= 0) return pw.SizedBox();
                                return pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 3),
                                  child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text('SGST${e.key} (${e.key}%)', style: pw.TextStyle(font: font, fontSize: 8)),
                                      pw.Text(e.value.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 8)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              if (rounding.abs() > 0.001) ...[
                                pw.SizedBox(height: 3),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Rounding', style: pw.TextStyle(font: font, fontSize: 8)),
                                    pw.Text(rounding.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 8)),
                                  ],
                                ),
                              ],
                              pw.Divider(color: PdfColors.grey400, height: 10, thickness: 0.5),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Total', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                                  pw.Text('Rs.' + grandTotalRounded.toStringAsFixed(2), style: pw.TextStyle(font: boldFont, fontSize: 9)),
                                ],
                              ),
                              pw.SizedBox(height: 2),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Balance Due', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                                  pw.Text('Rs.' + grandTotalRounded.toStringAsFixed(2), style: pw.TextStyle(font: boldFont, fontSize: 9)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // SIGNATURE BLOCK
                pw.Container(
                  padding: const pw.EdgeInsets.only(top: 8, right: 15, bottom: 5),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('SUJITHRAVISHNUKUMAR', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                          pw.SizedBox(height: 3),
                          if (signatureImage != null) ...[
                            pw.Container(
                              height: 65,
                              width: 180,
                              child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                            ),
                          ] else ...[
                            pw.SizedBox(height: 65),
                          ],
                          pw.SizedBox(height: 3),
                          pw.Text('Authorized Signature', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  static String numberToIndianWords(double num) {
    if (num == 0) return 'Zero';
    final int value = num.round();
    
    final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 
                   'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    
    String convertLessThanOneThousand(int number) {
      String soFar = '';
      if (number % 100 < 20) {
        soFar = units[number % 100];
        number = (number / 100).truncate();
      } else {
        soFar = units[number % 10];
        number = (number / 10).truncate();
        soFar = tens[number % 10] + (soFar.isEmpty ? '' : ' $soFar');
        number = (number / 10).truncate();
      }
      if (number == 0) return soFar;
      return units[number] + ' Hundred' + (soFar.isEmpty ? '' : ' $soFar');
    }

    int temp = value;
    String words = '';
    
    // Crores
    final int crores = (temp / 10000000).truncate();
    temp = temp % 10000000;
    if (crores > 0) {
      words += convertLessThanOneThousand(crores) + ' Crore ';
    }
    
    // Lakhs
    final int lakhs = (temp / 100000).truncate();
    temp = temp % 100000;
    if (lakhs > 0) {
      words += convertLessThanOneThousand(lakhs) + ' Lakh ';
    }
    
    // Thousands
    final int thousands = (temp / 1000).truncate();
    temp = temp % 1000;
    if (thousands > 0) {
      words += convertLessThanOneThousand(thousands) + ' Thousand ';
    }
    
    // Hundreds & Tens & Units
    if (temp > 0) {
      words += convertLessThanOneThousand(temp);
    }
    
    return words.trim() + ' Only';
  }

  static Future<void> generateInvoice({
    required Map<String, dynamic> bill,
    required String farmName,
    required String farmerName,
    required String cropName,
    required DateTime date,
    String? farmerAddress,
    String? farmerContact,
    String? placeOfSupply,
  }) async {
    final bytes = await generateInvoiceBytes(
      bill: bill,
      farmName: farmName,
      farmerName: farmerName,
      cropName: cropName,
      date: date,
      farmerAddress: farmerAddress,
      farmerContact: farmerContact,
      placeOfSupply: placeOfSupply,
    );

    final nameFormatted = farmName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    await _shareOrPrintPdf(
      bytes: bytes,
      filename: 'Invoice_${nameFormatted}_${DateFormat('ddMMMyy').format(date)}.pdf',
    );
  }

  static Future<void> _shareOrPrintPdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      if (kIsWeb) {
        await helper.downloadFile(bytes, filename);
      } else {
        await Printing.sharePdf(
          bytes: bytes,
          filename: filename,
        );
      }
    } catch (e) {
      debugPrint('Error printing/sharing PDF: $e');
      try {
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: filename,
        );
      } catch (ex) {
        debugPrint('Fallback layoutPdf also failed: $ex');
      }
    }
  }

  static Future<pw.ImageProvider?> _loadNetworkImageWithTimeout(String url) async {
    if (_imageCache.containsKey(url)) {
      return _imageCache[url];
    }
    try {
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final img = pw.MemoryImage(response.bodyBytes);
        _imageCache[url] = img;
        return img;
      } else {
        debugPrint('Failed to load image from $url: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading image from $url with timeout: $e');
    }
    return null;
  }
}