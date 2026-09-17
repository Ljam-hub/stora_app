import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/order_model.dart';
import '../utils/date_utils.dart';

class CustomerReceiptService {
  CustomerReceiptService._();
  static final CustomerReceiptService instance = CustomerReceiptService._();

  /// Generates a PDF receipt for a customer order.
  Future<Uint8List> generateOrderReceiptPdf(CustomerOrder order) async {
    final pdf = pw.Document();
    final storeName = order.storeName.isNotEmpty ? order.storeName : 'STORA STORE';
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    final formattedDate = order.createdAt != null
        ? dateFormat.format(toPht(order.createdAt!))
        : 'N/A';

    // Thermal roll format: 58mm width, auto-expanding height
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
                'ORDER RECEIPT',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Order #${order.id}',
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.Text(
                formattedDate,
                style: const pw.TextStyle(fontSize: 7),
              ),
              if (order.customerName.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Customer: ${order.customerName}',
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  order.statusDisplay.toUpperCase(),
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                ),
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
              ...order.items.map((item) {
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
                              item.productName,
                              style: const pw.TextStyle(fontSize: 7),
                              maxLines: 2,
                            ),
                            pw.Text(
                              '@ PHP ${item.unitPrice.toStringAsFixed(2)}',
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
                          'PHP ${item.subtotal.toStringAsFixed(2)}',
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
                    '${order.totalQuantity}',
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
                    'PHP ${order.totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              if (order.counterPrice != null && order.counterPrice! > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('ADJUSTED PRICE:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      'PHP ${order.counterPrice!.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Delivery Info
              if (order.customerAddress.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Deliver to: ${order.customerAddress}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                ),
              ],
              if (order.customerPhone.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  'Phone: ${order.customerPhone}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                ),
              ],

              // Footer
              pw.SizedBox(height: 6),
              pw.Text(
                'Thank you for your order!',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic),
              ),
              pw.Text(
                'Powered by Stora',
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

  /// Print an order receipt.
  Future<void> printReceipt(CustomerOrder order) async {
    final pdfBytes = await generateOrderReceiptPdf(order);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Order_Receipt_${order.id}.pdf',
    );
  }

  /// Share an order receipt via Messenger, Viber, etc.
  Future<void> shareReceipt(CustomerOrder order) async {
    final pdfBytes = await generateOrderReceiptPdf(order);
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/order_receipt_${order.id}.pdf');
    await file.writeAsBytes(pdfBytes);

    final storeName = order.storeName.isNotEmpty ? order.storeName : 'Stora Store';
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Here is my order receipt from $storeName for PHP ${order.totalAmount.toStringAsFixed(2)}.',
      subject: 'Order Receipt #${order.id}',
    );
  }
}
