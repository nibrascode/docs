import 'package:docspro/services/template_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('templates: unique ids, titles and non-empty content', () {
    final all = TemplateService.all;
    expect(all, isNotEmpty);
    expect(all.map((t) => t.id).toSet().length, all.length);
    for (final t in all) {
      expect(t.title.trim(), isNotEmpty, reason: t.id);
      if (t.id != 'blank') expect(t.content.trim(), isNotEmpty, reason: t.id);
    }
  });
}
