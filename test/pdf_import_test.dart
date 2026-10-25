import 'package:docspro/services/doc_import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('PDF import extracts text as paragraphs across pages', () async {
    final doc = pw.Document();
    doc.addPage(pw.Page(build: (_) => pw.Column(children: [
          pw.Text('First chapter.'),
          pw.Text('Hello world, this is a test.'),
        ])));
    doc.addPage(pw.Page(build: (_) => pw.Text('Second page text.')));
    final bytes = await doc.save();
    final out = DocImportService.pdfToText(bytes);
    expect(out, contains('First chapter.'));
    expect(out, contains('Hello world, this is a test.'));
    expect(out, contains('Second page text.'));
    expect(out.indexOf('First'), lessThan(out.indexOf('Second')));
    expect(out, contains('\n\n'));
  });
}
