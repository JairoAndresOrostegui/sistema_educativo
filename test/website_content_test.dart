import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/config/app_palette.dart';
import 'package:sistema_educativo/modules/website/models/website_content.dart';
import 'package:sistema_educativo/modules/website/screens/public_website_screen.dart';

void main() {
  group('Website CMS v5', () {
    test('defaults use rows, columns and components', () {
      final bundle = WebsiteBundle.defaults;
      expect(bundle.config.header.rows, isNotEmpty);
      expect(bundle.config.footer.rows, isNotEmpty);
      expect(
        bundle.pages.first.rows.first.columns.first.components,
        isNotEmpty,
      );
      expect(bundle.config.toMap()['version'], WebsiteSiteConfig.schemaVersion);
    });

    test('serializes and restores the complete layout', () {
      const component = WebsiteComponent(
        id: 'carousel_1',
        type: 'carousel',
        title: 'Vida escolar',
        autoplay: false,
        intervalSeconds: 8,
        items: [
          WebsiteComponentItem(
            id: 'slide_1',
            title: 'Ciencia',
            image: WebsiteAsset(
              url: 'https://example.com/ciencia.jpg',
              storagePath: 'website/ciencia.jpg',
            ),
          ),
        ],
      );
      const page = WebsitePage(
        id: 'home',
        label: 'Inicio',
        slug: 'home',
        rows: [
          WebsiteRow(
            id: 'row_1',
            columns: [
              WebsiteColumn(id: 'column_1', components: [component]),
            ],
          ),
        ],
      );
      final restored = WebsitePage.fromMap(page.id, page.toMap());
      final restoredComponent =
          restored.rows.first.columns.first.components.first;
      expect(restoredComponent.type, 'carousel');
      expect(restoredComponent.autoplay, isFalse);
      expect(restoredComponent.intervalSeconds, 8);
      expect(restoredComponent.items.single.title, 'Ciencia');
      expect(restoredComponent.items.single.image.isManaged, isTrue);
    });

    test('header and footer are independent layout areas', () {
      final original = WebsiteBundle.defaults.config;
      final restored = WebsiteSiteConfig.fromMap(original.toMap());
      expect(restored.header.rows.first.id, 'header_main');
      expect(restored.footer.rows.first.id, 'footer_main');
      expect(restored.header.rows.first.columns.length, 2);
      expect(restored.footer.rows.first.columns.length, 3);
    });

    test('rejects old schemas instead of keeping compatibility code', () {
      expect(
        () =>
            WebsiteSiteConfig.fromMap({'version': 4, 'schoolName': 'Colegio'}),
        throwsFormatException,
      );
    });

    test('managed assets include nested item images', () {
      const bundle = WebsiteBundle(
        config: WebsiteSiteConfig(
          schoolName: 'Colegio',
          tagline: '',
          logo: WebsiteAsset(storagePath: 'website/logo.png'),
        ),
        pages: [
          WebsitePage(
            id: 'home',
            label: 'Inicio',
            slug: 'home',
            rows: [
              WebsiteRow(
                id: 'row',
                columns: [
                  WebsiteColumn(
                    id: 'column',
                    components: [
                      WebsiteComponent(
                        id: 'gallery',
                        type: 'gallery',
                        items: [
                          WebsiteComponentItem(
                            id: 'image',
                            image: WebsiteAsset(
                              storagePath: 'website/gallery.jpg',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      expect(bundle.managedAssetPaths, {
        'website/logo.png',
        'website/gallery.jpg',
      });
    });

    testWidgets('renders the responsive public layout', (tester) async {
      final bundle = WebsiteBundle.defaults;
      await tester.pumpWidget(
        MaterialApp(
          home: WebsitePreviewCanvas(
            config: bundle.config,
            page: bundle.pages.first,
            previewMobile: true,
            editorMode: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text(bundle.config.schoolName), findsWidgets);
      expect(
        find.text('Formamos estudiantes con valores y pasión por aprender'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('preview keeps social icons visually enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WebsiteSocialLinks(
              links: [
                WebsiteSocialLink(
                  platform: 'facebook',
                  url: 'https://facebook.com/colegio',
                ),
              ],
              color: Colors.white,
              preview: true,
            ),
          ),
        ),
      );

      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('editor outlines the grid and highlights the selection', (
      tester,
    ) async {
      final bundle = WebsiteBundle.defaults;
      await tester.pumpWidget(
        MaterialApp(
          home: WebsitePreviewCanvas(
            config: bundle.config,
            page: bundle.pages.first,
            previewMobile: false,
            editorMode: true,
            selectedId: 'home_row',
          ),
        ),
      );
      await tester.pump();

      final borderColors = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.border)
          .whereType<Border>()
          .map((border) => border.top.color)
          .toList();
      expect(borderColors, contains(AppPalette.info));
      expect(borderColors, contains(AppPalette.error.withValues(alpha: .82)));
      expect(find.text('Fila 1'), findsWidgets);
      expect(find.text('Columna 1'), findsWidgets);
    });

    testWidgets('footer navigation does not add the login button', (
      tester,
    ) async {
      final config = WebsiteBundle.defaults.config;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WebsiteComponentView(
              config: config,
              pageId: 'footer',
              component: const WebsiteComponent(
                id: 'footer_navigation',
                type: 'navigation',
                title: 'Enlaces',
              ),
              mobile: false,
              preview: true,
            ),
          ),
        ),
      );

      expect(find.text('Enlaces'), findsOneWidget);
      expect(find.text('Ingresar'), findsNothing);
    });

    test('selects readable contrast for footer backgrounds', () {
      expect(websiteContrastColor('#FFFFFF'), Colors.black);
      expect(websiteContrastColor('#2B1718'), Colors.white);
    });
  });
}
