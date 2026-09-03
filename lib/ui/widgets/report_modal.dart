import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/security_model.dart';
import '../../services/report_export_service.dart';

enum ReportFormat { markdown, html }

class ReportModal extends StatefulWidget {
  final NetworkAuditResult auditResult;

  const ReportModal({super.key, required this.auditResult});

  static void show(BuildContext context, NetworkAuditResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF8F5), // Soft warm cream
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => ReportModal(auditResult: result),
    );
  }

  @override
  State<ReportModal> createState() => _ReportModalState();
}

class _ReportModalState extends State<ReportModal> {
  ReportFormat _selectedFormat = ReportFormat.markdown;
  bool _copied = false;

  static const primaryWarm = Color(0xFF6D4C41); // Warm Mocha
  static const deepMocha = Color(0xFF4E342E);   // Deep Espresso
  static const softBrown = Color(0xFF8D6E63);   // Soft Caramel Brown
  static const warmCream = Color(0xFFF5EFEB);   // Soft Warm Cream

  String get _currentReportContent {
    switch (_selectedFormat) {
      case ReportFormat.markdown:
        return ReportExportService.generateMarkdownReport(widget.auditResult);
      case ReportFormat.html:
        return ReportExportService.generateHtmlReport(widget.auditResult);
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _currentReportContent));
    setState(() {
      _copied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedFormat == ReportFormat.markdown
              ? 'Markdown report copied to clipboard!'
              : 'Standalone HTML report copied to clipboard!',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: primaryWarm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _currentReportContent;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Top Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7CCC8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: warmCream,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.description_outlined,
                        color: primaryWarm, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export Security Audit Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: deepMocha,
                          ),
                        ),
                        Text(
                          'Matches Phase 1 Report Figures 4.7–4.10 format',
                          style: TextStyle(fontSize: 11.5, color: softBrown),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: softBrown),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Format Selector Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Markdown / Text', style: TextStyle(fontSize: 12)),
                    selected: _selectedFormat == ReportFormat.markdown,
                    selectedColor: primaryWarm,
                    backgroundColor: warmCream,
                    labelStyle: TextStyle(
                      color: _selectedFormat == ReportFormat.markdown
                          ? Colors.white
                          : deepMocha,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide.none,
                    onSelected: (val) {
                      if (val) setState(() => _selectedFormat = ReportFormat.markdown);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('HTML (Figures 4.7-4.10)', style: TextStyle(fontSize: 12)),
                    selected: _selectedFormat == ReportFormat.html,
                    selectedColor: primaryWarm,
                    backgroundColor: warmCream,
                    labelStyle: TextStyle(
                      color: _selectedFormat == ReportFormat.html
                          ? Colors.white
                          : deepMocha,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide.none,
                    onSelected: (val) {
                      if (val) setState(() => _selectedFormat = ReportFormat.html);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Content Preview Box
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEAE2DC)),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SelectableText(
                    content,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      color: Color(0xFF3E2723),
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _copyToClipboard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _copied ? const Color(0xFF2D6A4F) : primaryWarm,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 1,
                  ),
                  icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 18),
                  label: Text(
                    _copied
                        ? 'Copied to Clipboard!'
                        : (_selectedFormat == ReportFormat.markdown
                            ? 'Copy Markdown Report'
                            : 'Copy Standalone HTML Report'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
