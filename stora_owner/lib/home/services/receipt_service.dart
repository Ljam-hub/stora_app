import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/sale.dart';

class ReceiptService {
  ReceiptService._();
  static final ReceiptService instance = ReceiptService._();

  /// Generates standard 58mm/80mm thermal receipt bytes.
  Future<Uint8List> generateReceiptPdf(Sale sale, {String? businessName}) async {
    final pdf = pw.Document();
    final storeName = (businessName != null && businessName.trim().isNotEmpty)
        ? businessName.trim()
        : 'STORA STORE';
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    final formattedDate = dateFormat.format(sale.date);

    // Thermal roll format: 58mm width (approx 164 points), auto-expanding height
    final pageFormat = PdfPageFormat(
      58 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 3 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Header
              pw.Text(
                storeName.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'OFFICIAL RECEIPT',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Rcpt #: ${sale.id}',
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.Text(
                formattedDate,
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Items Table Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('Item', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Items List
              ...sale.items.map((item) {
                final lineTotal = item.product.price * item.quantity;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              item.product.name,
                              style: const pw.TextStyle(fontSize: 7),
                              maxLines: 2,
                            ),
                            pw.Text(
                              '@ PHP ${item.product.price.toStringAsFixed(2)}',
                              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          '${item.quantity}',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'PHP ${lineTotal.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Items:', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text(
                    '${sale.items.fold<int>(0, (sum, i) => sum + i.quantity)}',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL AMOUNT:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    'PHP ${sale.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Footer
              pw.SizedBox(height: 6),
              pw.Text(
                'Thank you for your purchase!',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic),
              ),
              pw.Text(
                'Powered by Stora POS',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Sends receipt to Bluetooth or system thermal printer
  Future<void> printReceipt(Sale sale, {String? businessName}) async {
    final pdfBytes = await generateReceiptPdf(sale, businessName: businessName);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Receipt_${sale.id}.pdf',
    );
  }

  /// Shares receipt PDF directly to Messenger, Viber, WhatsApp, etc.
  Future<void> shareReceipt(Sale sale, {String? businessName}) async {
    final pdfBytes = await generateReceiptPdf(sale, businessName: businessName);
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/receipt_${sale.id}.pdf');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Here is your receipt from ${businessName ?? "Stora Store"} for PHP ${sale.total.toStringAsFixed(2)}.',
      subject: 'Receipt #${sale.id}',
    );
  }

  /// Generates official Subscription Receipt PDF.
  Future<Uint8List> generateSubscriptionReceiptPdf({
    required String businessName,
    required String email,
    required String planName,
    required double amount,
    required String referenceNumber,
    required DateTime date,
    required DateTime? expiresAt,
    String paymentMethod = 'GCash',
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    final formattedDate = dateFormat.format(date);
    final formattedExpiry = expiresAt != null ? DateFormat('MMM dd, yyyy').format(expiresAt) : '30 Days from approval';

    final pageFormat = PdfPageFormat.a4;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'STORA.',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.deepPurple700,
                          ),
                        ),
                        pw.Text(
                          'OFFICIAL SUBSCRIPTION RECEIPT',
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.green100,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'PAID / ACTIVE',
                        style: pw.TextStyle(
                          color: PdfColors.green800,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 16),

                // Subscriber Details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SUBSCRIBER DETAILS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(businessName.isNotEmpty ? businessName : 'Store Owner', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text(email, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('RECEIPT INFORMATION', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text('Ref #: $referenceNumber', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text('Payment via: $paymentMethod', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 24),

                // Table of Subscription Items
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('DESCRIPTION', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('VALIDITY', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('AMOUNT', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(planName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                              pw.Text('Full access to Stora POS, inventory, multi-channel sales & customer orders.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Until $formattedExpiry', style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('PHP ${amount.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 16),
                // Total Summary
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 220,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text('PHP ${amount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Tax / Fees:', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text('PHP 0.00', style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL PAID:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            pw.Text('PHP ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                pw.Spacer(),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Stora Philippines - Digital Commerce & POS Solutions', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    pw.Text('Generated electronically - Valid without signature', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print or export subscription receipt PDF
  Future<void> printSubscriptionReceipt({
    required String businessName,
    required String email,
    required String planName,
    required double amount,
    required String referenceNumber,
    required DateTime date,
    required DateTime? expiresAt,
  }) async {
    final pdfBytes = await generateSubscriptionReceiptPdf(
      businessName: businessName,
      email: email,
      planName: planName,
      amount: amount,
      referenceNumber: referenceNumber,
      date: date,
      expiresAt: expiresAt,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Stora_Subscription_Receipt_${referenceNumber.isNotEmpty ? referenceNumber : "Active"}.pdf',
    );
  }

  /// Share subscription receipt PDF
  Future<void> shareSubscriptionReceipt({
    required String businessName,
    required String email,
    required String planName,
    required double amount,
    required String referenceNumber,
    required DateTime date,
    required DateTime? expiresAt,
  }) async {
    final pdfBytes = await generateSubscriptionReceiptPdf(
      businessName: businessName,
      email: email,
      planName: planName,
      amount: amount,
      referenceNumber: referenceNumber,
      date: date,
      expiresAt: expiresAt,
    );
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/stora_subscription_receipt.pdf');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Official Subscription Receipt from Stora for $businessName.',
      subject: 'Stora Subscription Receipt',
    );
  }

  /// Save subscription receipt to local file
  Future<File> saveSubscriptionReceiptToFile({
    required String businessName,
    required String email,
    required String planName,
    required double amount,
    required String referenceNumber,
    required DateTime date,
    required DateTime? expiresAt,
  }) async {
    final pdfBytes = await generateSubscriptionReceiptPdf(
      businessName: businessName,
      email: email,
      planName: planName,
      amount: amount,
      referenceNumber: referenceNumber,
      date: date,
      expiresAt: expiresAt,
    );
    Directory? dir;
    try {
      dir = await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = await getTemporaryDirectory();
    }
    final file = File('${dir.path}/stora_subscription_receipt_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(pdfBytes);
    return file;
  }
}

