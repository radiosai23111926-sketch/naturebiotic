import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

class PdfService {
  static Future<void> generateAndShare({
    required Map<String, dynamic> report,
    required String farmName,
    required String cropName,
    required String farmerName,
  }) async {
    final pdf = pw.Document();

    // Load fonts that support the Rupee symbol (₹)
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

    await Printing.sharePdf(
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
            final image = await networkImage(imageUrl);
            imageWidget = pw.Container(
              height: 120,
              width: 180,
              child: pw.Image(image, fit: pw.BoxFit.cover),
            );
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
        final image = await networkImage(url);
        widgets.add(
          pw.Container(
            height: 100,
            width: 150,
            margin: const pw.EdgeInsets.symmetric(vertical: 5),
            child: pw.Image(image, fit: pw.BoxFit.cover),
          ),
        );
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

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'CallLogReport_${executiveName.replaceAll(' ', '_')}_${startStr}_to_$endStr.pdf',
    );
  }

  static Future<void> generateStockChallan({
    required List<Map<String, dynamic>> items,
    required String farmName,
    required String farmerName,
    required String cropName,
    required String transactionType,
    required DateTime date,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    double grandTotal = 0;
    for (var item in items) {
      grandTotal +=
          (item['price'] as double? ?? 0) * (item['quantity'] as double? ?? 0);
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
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green,
                          ),
                        ),
                        pw.Text(
                          'Delivery Challan',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Date: $dateStr',
                          style: const pw.TextStyle(fontSize: 9),
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
              pw.Row(
                children: [
                      pw.Row(
                        children: [
                          _infoItem('FARMER NAME', farmerName),
                          pw.SizedBox(width: 32),
                          _infoItem('FARM NAME', farmName),
                          pw.SizedBox(width: 32),
                          _infoItem('CROP NAME', cropName),
                        ],
                      ),
                ],
              ),
              pw.SizedBox(height: 20),
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
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1),
                },
                data: <List<String>>[
                  ['S.No', 'Item Name', 'Size', 'Qty', 'Rate', 'Amount'],
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final item = entry.value;
                    final qty = item['quantity'] as double? ?? 0;
                    final price = item['price'] as double? ?? 0;
                    return [
                      idx.toString(),
                      item['name'] ?? 'Unknown',
                      item['unit'] ?? 'N/A',
                      qty.toString(),
                      'Rs.${price.toStringAsFixed(2)}',
                      'Rs.${(qty * price).toStringAsFixed(2)}',
                    ];
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TOTAL VALUE:',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        'Rs.${grandTotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(
                  'Declaration: This is a computer generated document. It confirms that the above mentioned items have been ${transactionType.toLowerCase()} by the farm representative.',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
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
                      'Nature Biotic Stock Management System',
                      style: pw.TextStyle(
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

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'NatureBiotic_Challan_${farmName.replaceAll(' ', '_')}_${DateFormat('ddMMMyy').format(date)}.pdf',
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
    await Printing.sharePdf(bytes: await pdf.save(), filename: filename);
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

    await Printing.sharePdf(
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
}
