import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/local/database_helper.dart';

class PdfExportService {
  static final PdfExportService instance = PdfExportService._internal();
  PdfExportService._internal();

  /// Generates the complete productivity report PDF bytes
  Future<Uint8List> generateProductivityReport({
    int days = 7,
    String periodName = 'Weekly',
  }) async {
    final pdf = pw.Document(
      title: 'FocusFlow Productivity Report - $periodName',
      author: 'FocusFlow Executive Engine',
    );

    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final startDateDt = now.subtract(Duration(days: days - 1));

    final dateFormat = DateFormat('yyyy-MM-dd');
    final startDateStr = dateFormat.format(startDateDt);
    final endDateStr = dateFormat.format(now);

    final readableRange = '${DateFormat('MMM d, yyyy').format(startDateDt)} - ${DateFormat('MMM d, yyyy').format(now)}';

    // 1. Fetch Heatmap & streak metrics
    final heatmapStats = await db.getHabitHeatmapStats(daysCount: days);

    // 2. Fetch top apps during this period
    final rawDb = await db.database;
    final appUsageRows = await rawDb.rawQuery('''
      SELECT appName, packageName, SUM(durationMinutes) as totalMins, isProductive
      FROM app_usage
      WHERE date BETWEEN ? AND ?
      GROUP BY packageName
      ORDER BY totalMins DESC
      LIMIT 8
    ''', [startDateStr, endDateStr]);

    // 3. Fetch top focus session tasks
    final focusRows = await rawDb.rawQuery('''
      SELECT taskName, COUNT(*) as sessionsCount, SUM(durationMinutes) as totalMins
      FROM focus_sessions
      WHERE date BETWEEN ? AND ? AND completed = 1
      GROUP BY taskName
      ORDER BY totalMins DESC
      LIMIT 6
    ''', [startDateStr, endDateStr]);

    // 4. Calculate total productive vs distracting app minutes
    int productiveAppMinutes = 0;
    int distractingAppMinutes = 0;

    for (final row in appUsageRows) {
      final mins = (row['totalMins'] as num?)?.toInt() ?? 0;
      final isProd = (row['isProductive'] as int?) == 1;
      if (isProd) {
        productiveAppMinutes += mins;
      } else {
        distractingAppMinutes += mins;
      }
    }

    // 5. Compute Grade
    final avgScore = heatmapStats.averageDailyScore.round();
    final grade = avgScore >= 90
        ? 'A+ Exceptional'
        : (avgScore >= 80
            ? 'A Dedicated'
            : (avgScore >= 70
                ? 'B Steady'
                : (avgScore >= 60 ? 'C Developing' : 'Needs Focus')));

    // Build PDF Pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(periodName, readableRange),
            pw.SizedBox(height: 18),
            _buildExecutiveSummary(avgScore, grade, heatmapStats.totalFocusMinutes, heatmapStats.currentStreak, heatmapStats.activeDaysCount, days),
            pw.SizedBox(height: 20),
            _buildDailyTable(heatmapStats.activityMap.values.toList()),
            pw.SizedBox(height: 20),
            _buildFocusAndAppBreakdown(focusRows, appUsageRows),
            pw.SizedBox(height: 20),
            _buildAiInsightsSection(avgScore, heatmapStats.totalFocusMinutes, productiveAppMinutes, distractingAppMinutes),
            pw.SizedBox(height: 24),
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Opens native print / save as PDF preview sheet
  Future<void> previewOrPrintReport(
    BuildContext context, {
    int days = 7,
    String periodName = 'Weekly',
  }) async {
    final pdfBytes = await generateProductivityReport(days: days, periodName: periodName);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'FocusFlow_${periodName}_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  /// Opens OS share sheet to share PDF file
  Future<void> shareReport({
    int days = 7,
    String periodName = 'Weekly',
  }) async {
    final pdfBytes = await generateProductivityReport(days: days, periodName: periodName);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'FocusFlow_${periodName}_Productivity_Report.pdf',
    );
  }

  pw.Widget _buildHeader(String periodName, String readableRange) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('1A1D2E'),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 14,
                    height: 14,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('06B6D4'),
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'FOCUSFLOW',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Personal Productivity & Deep Work Audit',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColor.fromHex('94A3B8'),
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('4F46E5'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  '$periodName Report'.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                readableRange,
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColor.fromHex('CBD5E1'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildExecutiveSummary(
    int avgScore,
    String grade,
    int totalFocusMinutes,
    int currentStreak,
    int activeDays,
    int totalDays,
  ) {
    final focusHours = (totalFocusMinutes / 60.0).toStringAsFixed(1);

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('E2E8F0'), width: 1),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildKpiCard('Average Score', '$avgScore%', grade, PdfColor.fromHex('4F46E5')),
          _buildDivider(),
          _buildKpiCard('Deep Focus', '${focusHours}h', 'Total Focused Time', PdfColor.fromHex('06B6D4')),
          _buildDivider(),
          _buildKpiCard('Habit Streak', '$currentStreak Days', '$activeDays of $totalDays Active', PdfColor.fromHex('10B981')),
        ],
      ),
    );
  }

  pw.Widget _buildKpiCard(String title, String mainValue, String subtitle, PdfColor accentColor) {
    return pw.Column(
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('64748B'),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          mainValue,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: accentColor,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          subtitle,
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColor.fromHex('64748B'),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildDivider() {
    return pw.Container(
      height: 36,
      width: 1,
      color: PdfColor.fromHex('E2E8F0'),
    );
  }

  pw.Widget _buildDailyTable(List activities) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Daily Activity Timeline',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1E293B')),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColor.fromHex('CBD5E1'), width: 0.5),
          children: [
            // Table Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('F1F5F9')),
              children: [
                _buildTableCell('Date', isHeader: true),
                _buildTableCell('Focus Time', isHeader: true),
                _buildTableCell('Tasks Done', isHeader: true),
                _buildTableCell('Goals', isHeader: true),
                _buildTableCell('Productivity Score', isHeader: true),
                _buildTableCell('Intensity Status', isHeader: true),
              ],
            ),
            // Table Data Rows
            ...activities.map((act) {
              final hours = (act.focusMinutes / 60.0).toStringAsFixed(1);
              final status = act.focusMinutes >= 90
                  ? 'High Focus 🚀'
                  : (act.focusMinutes >= 45
                      ? 'Moderate ⚡'
                      : (act.hasActivity ? 'Light 🌱' : 'Rest Day 😴'));

              return pw.TableRow(
                children: [
                  _buildTableCell(act.date),
                  _buildTableCell('${hours}h (${act.focusMinutes}m)'),
                  _buildTableCell('${act.completedTasks} completed'),
                  _buildTableCell('${act.completedGoals} targets'),
                  _buildTableCell('${act.productivityScore}%'),
                  _buildTableCell(status),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColor.fromHex('334155') : PdfColor.fromHex('475569'),
        ),
      ),
    );
  }

  pw.Widget _buildFocusAndAppBreakdown(List focusRows, List appUsageRows) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Focus Task Breakdown
        pw.Expanded(
          flex: 1,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Top Focus Objectives',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1E293B')),
              ),
              pw.SizedBox(height: 6),
              if (focusRows.isEmpty)
                pw.Text('No focus sessions logged during this timeframe.', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('64748B')))
              else
                ...focusRows.map((r) {
                  final name = r['taskName'] as String? ?? 'Deep Work';
                  final mins = (r['totalMins'] as num?)?.toInt() ?? 0;
                  final sessions = (r['sessionsCount'] as num?)?.toInt() ?? 1;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text('• $name ($sessions sessions)', style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('334155')), maxLines: 1),
                        ),
                        pw.Text('${mins}m', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('4F46E5'))),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        // App Screen Time
        pw.Expanded(
          flex: 1,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Top Screen Time Applications',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('1E293B')),
              ),
              pw.SizedBox(height: 6),
              if (appUsageRows.isEmpty)
                pw.Text('No app usage recorded.', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('64748B')))
              else
                ...appUsageRows.map((r) {
                  final name = r['appName'] as String? ?? 'App';
                  final mins = (r['totalMins'] as num?)?.toInt() ?? 0;
                  final isProd = (r['isProductive'] as int?) == 1;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '• $name ${isProd ? "✓" : "⚠"}',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              color: isProd ? PdfColor.fromHex('15803D') : PdfColor.fromHex('B91C1C'),
                            ),
                            maxLines: 1,
                          ),
                        ),
                        pw.Text('${mins}m', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('334155'))),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildAiInsightsSection(int avgScore, int totalFocusMinutes, int productiveMins, int distractingMins) {
    String insightText;
    if (avgScore >= 85) {
      insightText = 'Exceptional discipline detected! Your deep work ratio is high and distraction friction barriers have successfully preserved cognitive energy. Maintain your current bedtime schedule to consolidate memory gains.';
    } else if (avgScore >= 70) {
      insightText = 'Solid consistency across the period. Suggestion: Cluster your top 2 hardest tasks into the morning 8:30 AM - 11:30 AM energy peak to eliminate afternoon willpower fatigue.';
    } else {
      insightText = 'Potential for optimization: Distracting screen time exceeded productive thresholds on several days. Consider turning on Hardcore Strict Mode during scheduled study blocks to lock out social media.';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('F8FAFC'),
        border: pw.Border.all(color: PdfColor.fromHex('CBD5E1'), width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text('✨ AI PRODUCTIVITY SYNTHESIS & RECOMMENDATION', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('06B6D4'))),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            insightText,
            style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('334155'), height: 1.3),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generated offline on device via FocusFlow Engine • Confidential',
          style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('94A3B8')),
        ),
        pw.Text(
          'https://github.com/Thiva123-ab/Smart-Time-Management-MobileApp',
          style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('94A3B8')),
        ),
      ],
    );
  }
}
