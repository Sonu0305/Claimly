import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../products/models/product_model.dart';
import '../models/claim_attachment_model.dart';
import '../models/claim_model.dart';
import '../models/claim_timeline_model.dart';

class ClaimReportData {
  final String reportId;
  final DateTime generatedAt;
  final ClaimModel claim;
  final ProductModel product;
  final String customerName;
  final String customerEmail;
  final String? customerPhone;
  final List<ClaimTimelineModel> timeline;
  final List<ClaimAttachmentModel> attachments;
  final String verificationCode;
  final String verificationUrl;

  const ClaimReportData({
    required this.reportId,
    required this.generatedAt,
    required this.claim,
    required this.product,
    required this.customerName,
    required this.customerEmail,
    this.customerPhone,
    required this.timeline,
    required this.attachments,
    required this.verificationCode,
    required this.verificationUrl,
  });
}

class ClaimPdfService {
  static Future<Uint8List> generateClaimPdf(ClaimReportData data) async {
    final doc = pw.Document();

    final indigoColor = PdfColor.fromHex('#1E40AF');
    final grayColor = PdfColor.fromHex('#475569');
    final lightGray = PdfColor.fromHex('#F1F5F9');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Branded Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: indigoColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CLAIMLY: AUTOMATED WARRANTY & REFUND ASSISTANT',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'OFFICIAL CLAIM REPORT',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Report ID: ${data.reportId}',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                      ),
                      pw.Text(
                        'Generated: ${DateFormatter.formatDisplayDate(data.generatedAt)}',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Claim & Status Summary Card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightGray,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Claim Number: ${data.claim.claimNumber}',
                        style: pw.TextStyle(
                          font: pw.Font.courier(),
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Claim Type: ${data.claim.type.toUpperCase()}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Status: ${data.claim.status.toUpperCase()}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: indigoColor,
                          fontSize: 12,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Priority Score: ${data.claim.priority}/100',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Two-Column Section: Customer Info & Product Info
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Customer Information
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CUSTOMER INFORMATION',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: grayColor,
                          ),
                        ),
                        pw.Divider(height: 12),
                        pw.Text('Customer: ${data.customerName}', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 3),
                        pw.Text('Email: ${data.customerEmail}', style: const pw.TextStyle(fontSize: 10)),
                        if (data.customerPhone != null && data.customerPhone!.isNotEmpty) ...[
                          pw.SizedBox(height: 3),
                          pw.Text('Phone: ${data.customerPhone}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),

                // Product Information
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PRODUCT DETAILS',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: grayColor,
                          ),
                        ),
                        pw.Divider(height: 12),
                        pw.Text('Product: ${data.product.name}', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 3),
                        pw.Text('Category: ${data.product.category}', style: const pw.TextStyle(fontSize: 10)),
                        if (data.product.brand != null) ...[
                          pw.SizedBox(height: 3),
                          pw.Text('Brand: ${data.product.brand}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                        if (data.product.serialNumber != null) ...[
                          pw.SizedBox(height: 3),
                          pw.Text('Serial: ${data.product.serialNumber}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Warranty Expiry: ${DateFormatter.formatDisplayDate(data.product.warrantyExpiryDate)}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Issue Statement
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ISSUE STATEMENT',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: grayColor,
                    ),
                  ),
                  pw.Divider(height: 12),
                  pw.Text(
                    'Title: ${data.claim.title}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  if (data.claim.incidentDate != null)
                    pw.Text(
                      'Incident Date: ${DateFormatter.formatDisplayDate(data.claim.incidentDate!)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Description: ${data.claim.description}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  if (data.claim.resolutionNotes != null && data.claim.resolutionNotes!.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Resolution: ${data.claim.resolutionNotes}',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Timeline Audit Trail Table
            pw.Text(
              'TIMELINE AUDIT TRAIL',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: grayColor,
              ),
            ),
            pw.SizedBox(height: 6),
            if (data.timeline.isNotEmpty)
              pw.TableHelper.fromTextArray(
                headers: ['Date & Time', 'Status', 'Notes'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellStyle: const pw.TextStyle(fontSize: 8),
                data: data.timeline.map((item) {
                  return [
                    DateFormatter.formatDisplayDate(item.createdAt),
                    item.toStatus.toUpperCase(),
                    item.notes ?? '—',
                  ];
                }).toList(),
              )
            else
              pw.Text('No timeline events recorded.', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 20),

            // Proof Attachments List
            pw.Text(
              'PROOF ATTACHMENTS (${data.attachments.length})',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: grayColor,
              ),
            ),
            pw.SizedBox(height: 6),
            if (data.attachments.isNotEmpty)
              pw.TableHelper.fromTextArray(
                headers: ['File Name', 'Format', 'Size'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellStyle: const pw.TextStyle(fontSize: 8),
                data: data.attachments.map((a) {
                  return [
                    a.fileName,
                    a.fileType ?? 'N/A',
                    a.formattedSize,
                  ];
                }).toList(),
              )
            else
              pw.Text('No files attached.', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 24),

            // Anti-Fraud Verification Footer with QR Code
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: indigoColor, width: 1.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.BarcodeWidget(
                    data: data.verificationUrl,
                    barcode: pw.Barcode.qrCode(),
                    width: 60,
                    height: 60,
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'QR Verification Hash: SHA256-${data.claim.claimNumber}',
                          style: pw.TextStyle(
                            font: pw.Font.courier(),
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Verification Code: ${data.verificationCode}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Verify Authenticity: ${data.verificationUrl}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue800),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Confidential document generated by Claimly Automated Warranty & Refund Assistant.',
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static Future<void> previewOrPrintPdf(
    BuildContext context,
    ClaimReportData data,
  ) async {
    final pdfBytes = await generateClaimPdf(data);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'ClaimReport_${data.claim.claimNumber}.pdf',
    );
  }

  static Future<void> sharePdf(ClaimReportData data) async {
    final pdfBytes = await generateClaimPdf(data);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'ClaimReport_${data.claim.claimNumber}.pdf',
    );
  }
}
