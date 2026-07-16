import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/modules/website/models/website_content.dart';

void main() {
  group('WebsiteContent', () {
    test('incluye la navegación aprobada de Wix', () {
      expect(WebsiteContent.defaults.navigation.map((item) => item.label), [
        'About',
        'Admissions',
        'Learning',
        'News & Events',
        'Parents',
      ]);
    });

    test('migra contenido anterior a las nuevas páginas', () {
      final migrated = WebsiteContent.fromMap({
        'version': 1,
        'schoolName': 'Liceo',
        'sections': [
          {
            'id': 'legacy',
            'title': 'Contenido anterior',
            'body': 'Se conserva durante la migración.',
          },
        ],
      });

      expect(
        migrated.sections.any((section) => section.id == 'legacy'),
        isTrue,
      );
      for (final page in ['admissions', 'learning', 'news', 'parents']) {
        expect(
          migrated.sections.any((section) => section.pageId == page),
          isTrue,
        );
      }
    });

    test('conserva opciones avanzadas al serializar', () {
      const section = WebsiteSection(
        id: 'custom',
        title: 'Título',
        body: 'Contenido',
        pageId: 'learning',
        textAlignment: 'right',
        imagePosition: 'background',
        imageFit: 'contain',
        contentWidth: 'narrow',
        backgroundColor: '#112233',
        textColor: '#FFFFFF',
      );

      final decoded = WebsiteSection.fromMap(section.toMap());
      expect(decoded.pageId, 'learning');
      expect(decoded.textAlignment, 'right');
      expect(decoded.imagePosition, 'background');
      expect(decoded.imageFit, 'contain');
      expect(decoded.contentWidth, 'narrow');
      expect(decoded.backgroundColor, '#112233');
      expect(decoded.textColor, '#FFFFFF');
    });
  });
}
