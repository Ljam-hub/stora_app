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
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
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
                              '@ ₱${item.product.price.toStringAsFixed(2)}',
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
                          '₱${lineTotal.toStringAsFixed(2)}',
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
                    '₱${sale.total.toStringAsFixed(2)}',
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
      text: 'Here is your receipt from ${businessName ?? "Stora Store"} for ₱${sale.total.toStringAsFixed(2)}.',
      subject: 'Receipt #${sale.id}',
    );
  }
}
