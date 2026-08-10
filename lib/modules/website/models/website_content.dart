class WebsiteAsset {
  final String url;
  final String storagePath;

  const WebsiteAsset({this.url = '', this.storagePath = ''});

  factory WebsiteAsset.fromMap(Map<String, dynamic>? map) => WebsiteAsset(
    url: (map?['url'] ?? '').toString(),
    storagePath: (map?['storagePath'] ?? '').toString(),
  );

  Map<String, dynamic> toMap() => {
    'url': url.trim(),
    'storagePath': storagePath.trim(),
  };

  bool get isManaged => storagePath.startsWith('website/');
}

class WebsiteSocialLink {
  final String platform;
  final String url;
  final bool enabled;

  const WebsiteSocialLink({
    required this.platform,
    this.url = '',
    this.enabled = true,
  });

  factory WebsiteSocialLink.fromMap(Map<String, dynamic> map) =>
      WebsiteSocialLink(
        platform: (map['platform'] ?? '').toString(),
        url: (map['url'] ?? '').toString(),
        enabled: map['enabled'] != false,
      );

  Map<String, dynamic> toMap() => {
    'platform': platform,
    'url': url.trim(),
    'enabled': enabled,
  };

  WebsiteSocialLink copyWith({String? url, bool? enabled}) => WebsiteSocialLink(
    platform: platform,
    url: url ?? this.url,
    enabled: enabled ?? this.enabled,
  );
}

class WebsiteNavigationItem {
  final String id;
  final String label;
  final String slug;
  final bool enabled;

  const WebsiteNavigationItem({
    required this.id,
    required this.label,
    required this.slug,
    this.enabled = true,
  });

  factory WebsiteNavigationItem.fromMap(Map<String, dynamic> map) =>
      WebsiteNavigationItem(
        id: (map['id'] ?? '').toString(),
        label: (map['label'] ?? '').toString(),
        slug: (map['slug'] ?? '').toString(),
        enabled: map['enabled'] != false,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label.trim(),
    'slug': slug.trim(),
    'enabled': enabled,
  };

  WebsiteNavigationItem copyWith({
    String? label,
    String? slug,
    bool? enabled,
  }) => WebsiteNavigationItem(
    id: id,
    label: label ?? this.label,
    slug: slug ?? this.slug,
    enabled: enabled ?? this.enabled,
  );
}

class WebsiteComponentItem {
  final String id;
  final String title;
  final String text;
  final String url;
  final String icon;
  final WebsiteAsset image;

  const WebsiteComponentItem({
    required this.id,
    this.title = '',
    this.text = '',
    this.url = '',
    this.icon = 'star',
    this.image = const WebsiteAsset(),
  });

  factory WebsiteComponentItem.fromMap(Map<String, dynamic> map, int index) =>
      WebsiteComponentItem(
        id: (map['id'] ?? 'item_$index').toString(),
        title: (map['title'] ?? '').toString(),
        text: (map['text'] ?? '').toString(),
        url: (map['url'] ?? '').toString(),
        icon: (map['icon'] ?? 'star').toString(),
        image: WebsiteAsset.fromMap(_map(map['image'])),
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title.trim(),
    'text': text.trim(),
    'url': url.trim(),
    'icon': icon,
    'image': image.toMap(),
  };

  WebsiteComponentItem copyWith({
    String? title,
    String? text,
    String? url,
    String? icon,
    WebsiteAsset? image,
  }) => WebsiteComponentItem(
    id: id,
    title: title ?? this.title,
    text: text ?? this.text,
    url: url ?? this.url,
    icon: icon ?? this.icon,
    image: image ?? this.image,
  );
}

/// A reusable content unit. Type-specific data lives in [items], while visual
/// fields are shared so the editor stays predictable for non-technical users.
class WebsiteComponent {
  final String id;
  final String type;
  final String title;
  final String body;
  final String url;
  final String buttonLabel;
  final WebsiteAsset image;
  final List<WebsiteComponentItem> items;
  final bool enabled;
  final int widthPercent;
  final String componentAlignment;
  final String alignment;
  final String imageFit;
  final String backgroundColor;
  final String textColor;
  final String accentColor;
  final int titleSize;
  final int bodySize;
  final int padding;
  final bool autoplay;
  final int intervalSeconds;

  const WebsiteComponent({
    required this.id,
    required this.type,
    this.title = '',
    this.body = '',
    this.url = '',
    this.buttonLabel = '',
    this.image = const WebsiteAsset(),
    this.items = const [],
    this.enabled = true,
    this.widthPercent = 100,
    this.componentAlignment = 'left',
    this.alignment = 'left',
    this.imageFit = 'cover',
    this.backgroundColor = '#FFFFFF',
    this.textColor = '#292323',
    this.accentColor = '#A63D40',
    this.titleSize = 34,
    this.bodySize = 16,
    this.padding = 20,
    this.autoplay = true,
    this.intervalSeconds = 5,
  });

  factory WebsiteComponent.fromMap(Map<String, dynamic> map, int index) =>
      WebsiteComponent(
        id: (map['id'] ?? 'component_$index').toString(),
        type: (map['type'] ?? 'text').toString(),
        title: (map['title'] ?? '').toString(),
        body: (map['body'] ?? '').toString(),
        url: (map['url'] ?? '').toString(),
        buttonLabel: (map['buttonLabel'] ?? '').toString(),
        image: WebsiteAsset.fromMap(_map(map['image'])),
        items: _list(map['items'])
            .asMap()
            .entries
            .map(
              (entry) => WebsiteComponentItem.fromMap(entry.value, entry.key),
            )
            .toList(),
        enabled: map['enabled'] != false,
        widthPercent: _int(map['widthPercent'], 100).clamp(25, 100),
        componentAlignment: (map['componentAlignment'] ?? 'left').toString(),
        alignment: (map['alignment'] ?? 'left').toString(),
        imageFit: (map['imageFit'] ?? 'cover').toString(),
        backgroundColor: (map['backgroundColor'] ?? '#FFFFFF').toString(),
        textColor: (map['textColor'] ?? '#292323').toString(),
        accentColor: (map['accentColor'] ?? '#A63D40').toString(),
        titleSize: _int(map['titleSize'], 34),
        bodySize: _int(map['bodySize'], 16),
        padding: _int(map['padding'], 20),
        autoplay: map['autoplay'] != false,
        intervalSeconds: _int(map['intervalSeconds'], 5).clamp(2, 15),
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'title': title.trim(),
    'body': body.trim(),
    'url': url.trim(),
    'buttonLabel': buttonLabel.trim(),
    'image': image.toMap(),
    'items': items.map((item) => item.toMap()).toList(),
    'enabled': enabled,
    'widthPercent': widthPercent,
    'componentAlignment': componentAlignment,
    'alignment': alignment,
    'imageFit': imageFit,
    'backgroundColor': backgroundColor,
    'textColor': textColor,
    'accentColor': accentColor,
    'titleSize': titleSize,
    'bodySize': bodySize,
    'padding': padding,
    'autoplay': autoplay,
    'intervalSeconds': intervalSeconds,
  };

  WebsiteComponent copyWith({
    String? title,
    String? body,
    String? url,
    String? buttonLabel,
    WebsiteAsset? image,
    List<WebsiteComponentItem>? items,
    bool? enabled,
    int? widthPercent,
    String? componentAlignment,
    String? alignment,
    String? imageFit,
    String? backgroundColor,
    String? textColor,
    String? accentColor,
    int? titleSize,
    int? bodySize,
    int? padding,
    bool? autoplay,
    int? intervalSeconds,
  }) => WebsiteComponent(
    id: id,
    type: type,
    title: title ?? this.title,
    body: body ?? this.body,
    url: url ?? this.url,
    buttonLabel: buttonLabel ?? this.buttonLabel,
    image: image ?? this.image,
    items: items ?? this.items,
    enabled: enabled ?? this.enabled,
    widthPercent: widthPercent ?? this.widthPercent,
    componentAlignment: componentAlignment ?? this.componentAlignment,
    alignment: alignment ?? this.alignment,
    imageFit: imageFit ?? this.imageFit,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    textColor: textColor ?? this.textColor,
    accentColor: accentColor ?? this.accentColor,
    titleSize: titleSize ?? this.titleSize,
    bodySize: bodySize ?? this.bodySize,
    padding: padding ?? this.padding,
    autoplay: autoplay ?? this.autoplay,
    intervalSeconds: intervalSeconds ?? this.intervalSeconds,
  );
}

class WebsiteColumn {
  final String id;
  final int span;
  final String backgroundColor;
  final int padding;
  final List<WebsiteComponent> components;

  const WebsiteColumn({
    required this.id,
    this.span = 1,
    this.backgroundColor = '#FFFFFF',
    this.padding = 8,
    this.components = const [],
  });

  factory WebsiteColumn.fromMap(Map<String, dynamic> map, int index) =>
      WebsiteColumn(
        id: (map['id'] ?? 'column_$index').toString(),
        span: _int(map['span'], 1).clamp(1, 4),
        backgroundColor: (map['backgroundColor'] ?? '#FFFFFF').toString(),
        padding: _int(map['padding'], 8),
        components: _list(map['components'])
            .asMap()
            .entries
            .map((entry) => WebsiteComponent.fromMap(entry.value, entry.key))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'span': span,
    'backgroundColor': backgroundColor,
    'padding': padding,
    'components': components.map((item) => item.toMap()).toList(),
  };

  WebsiteColumn copyWith({
    int? span,
    String? backgroundColor,
    int? padding,
    List<WebsiteComponent>? components,
  }) => WebsiteColumn(
    id: id,
    span: span ?? this.span,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    padding: padding ?? this.padding,
    components: components ?? this.components,
  );
}

class WebsiteRow {
  final String id;
  final bool enabled;
  final String backgroundColor;
  final int padding;
  final int gap;
  final int maxWidth;
  final bool stackOnMobile;
  final List<WebsiteColumn> columns;

  const WebsiteRow({
    required this.id,
    this.enabled = true,
    this.backgroundColor = '#FFFFFF',
    this.padding = 24,
    this.gap = 20,
    this.maxWidth = 1280,
    this.stackOnMobile = true,
    this.columns = const [],
  });

  factory WebsiteRow.fromMap(Map<String, dynamic> map, int index) => WebsiteRow(
    id: (map['id'] ?? 'row_$index').toString(),
    enabled: map['enabled'] != false,
    backgroundColor: (map['backgroundColor'] ?? '#FFFFFF').toString(),
    padding: _int(map['padding'], 24),
    gap: _int(map['gap'], 20),
    maxWidth: _int(map['maxWidth'], 1280),
    stackOnMobile: map['stackOnMobile'] != false,
    columns: _list(map['columns'])
        .asMap()
        .entries
        .map((entry) => WebsiteColumn.fromMap(entry.value, entry.key))
        .toList(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'enabled': enabled,
    'backgroundColor': backgroundColor,
    'padding': padding,
    'gap': gap,
    'maxWidth': maxWidth,
    'stackOnMobile': stackOnMobile,
    'columns': columns.map((item) => item.toMap()).toList(),
  };

  WebsiteRow copyWith({
    bool? enabled,
    String? backgroundColor,
    int? padding,
    int? gap,
    int? maxWidth,
    bool? stackOnMobile,
    List<WebsiteColumn>? columns,
  }) => WebsiteRow(
    id: id,
    enabled: enabled ?? this.enabled,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    padding: padding ?? this.padding,
    gap: gap ?? this.gap,
    maxWidth: maxWidth ?? this.maxWidth,
    stackOnMobile: stackOnMobile ?? this.stackOnMobile,
    columns: columns ?? this.columns,
  );
}

class WebsiteHeaderConfig {
  final bool enabled;
  final bool sticky;
  final List<WebsiteRow> rows;

  const WebsiteHeaderConfig({
    this.enabled = true,
    this.sticky = true,
    this.rows = const [],
  });

  factory WebsiteHeaderConfig.fromMap(Map<String, dynamic>? map) =>
      WebsiteHeaderConfig(
        enabled: map?['enabled'] != false,
        sticky: map?['sticky'] != false,
        rows: _rows(map?['rows']),
      );

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'sticky': sticky,
    'rows': rows.map((row) => row.toMap()).toList(),
  };

  WebsiteHeaderConfig copyWith({
    bool? enabled,
    bool? sticky,
    List<WebsiteRow>? rows,
  }) => WebsiteHeaderConfig(
    enabled: enabled ?? this.enabled,
    sticky: sticky ?? this.sticky,
    rows: rows ?? this.rows,
  );
}

class WebsiteFooterConfig {
  final bool enabled;
  final String copyrightText;
  final List<WebsiteRow> rows;

  const WebsiteFooterConfig({
    this.enabled = true,
    this.copyrightText = '',
    this.rows = const [],
  });

  factory WebsiteFooterConfig.fromMap(Map<String, dynamic>? map) =>
      WebsiteFooterConfig(
        enabled: map?['enabled'] != false,
        copyrightText: (map?['copyrightText'] ?? '').toString(),
        rows: _rows(map?['rows']),
      );

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'copyrightText': copyrightText.trim(),
    'rows': rows.map((row) => row.toMap()).toList(),
  };

  WebsiteFooterConfig copyWith({
    bool? enabled,
    String? copyrightText,
    List<WebsiteRow>? rows,
  }) => WebsiteFooterConfig(
    enabled: enabled ?? this.enabled,
    copyrightText: copyrightText ?? this.copyrightText,
    rows: rows ?? this.rows,
  );
}

class WebsitePage {
  final String id;
  final String label;
  final String slug;
  final bool enabled;
  final bool showInNavigation;
  final int sortOrder;
  final List<WebsiteRow> rows;

  const WebsitePage({
    required this.id,
    required this.label,
    required this.slug,
    this.enabled = true,
    this.showInNavigation = true,
    this.sortOrder = 0,
    this.rows = const [],
  });

  factory WebsitePage.fromMap(String id, Map<String, dynamic> map) =>
      WebsitePage(
        id: id,
        label: (map['label'] ?? id).toString(),
        slug: (map['slug'] ?? id).toString(),
        enabled: map['enabled'] != false,
        showInNavigation: map['showInNavigation'] != false,
        sortOrder: _int(map['sortOrder'], 0),
        rows: _rows(map['rows']),
      );

  Map<String, dynamic> toMap() => {
    'label': label.trim(),
    'slug': slug.trim(),
    'enabled': enabled,
    'showInNavigation': showInNavigation,
    'sortOrder': sortOrder,
    'rows': rows.map((row) => row.toMap()).toList(),
  };

  WebsitePage copyWith({
    String? label,
    String? slug,
    bool? enabled,
    bool? showInNavigation,
    int? sortOrder,
    List<WebsiteRow>? rows,
  }) => WebsitePage(
    id: id,
    label: label ?? this.label,
    slug: slug ?? this.slug,
    enabled: enabled ?? this.enabled,
    showInNavigation: showInNavigation ?? this.showInNavigation,
    sortOrder: sortOrder ?? this.sortOrder,
    rows: rows ?? this.rows,
  );
}

class WebsiteSiteConfig {
  static const schemaVersion = 5;

  final String schoolName;
  final String tagline;
  final WebsiteAsset logo;
  final String phone;
  final String email;
  final String address;
  final String primaryColor;
  final String fontFamily;
  final List<WebsiteNavigationItem> navigation;
  final List<WebsiteSocialLink> socialLinks;
  final WebsiteHeaderConfig header;
  final WebsiteFooterConfig footer;

  const WebsiteSiteConfig({
    required this.schoolName,
    required this.tagline,
    this.logo = const WebsiteAsset(),
    this.phone = '',
    this.email = '',
    this.address = '',
    this.primaryColor = '#A63D40',
    this.fontFamily = 'Montserrat',
    this.navigation = const [],
    this.socialLinks = const [],
    this.header = const WebsiteHeaderConfig(),
    this.footer = const WebsiteFooterConfig(),
  });

  factory WebsiteSiteConfig.fromMap(Map<String, dynamic> map) {
    if (_int(map['version'], 0) != schemaVersion) {
      throw const FormatException(
        'El contenido del sitio requiere ejecutar la migración a la versión 5.',
      );
    }
    return WebsiteSiteConfig(
      schoolName: (map['schoolName'] ?? '').toString(),
      tagline: (map['tagline'] ?? '').toString(),
      logo: WebsiteAsset.fromMap(_map(map['logo'])),
      phone: (map['phone'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      primaryColor: (map['primaryColor'] ?? '#A63D40').toString(),
      fontFamily: (map['fontFamily'] ?? 'Montserrat').toString(),
      navigation: _list(
        map['navigation'],
      ).map(WebsiteNavigationItem.fromMap).toList(),
      socialLinks: _list(
        map['socialLinks'],
      ).map(WebsiteSocialLink.fromMap).toList(),
      header: WebsiteHeaderConfig.fromMap(_map(map['header'])),
      footer: WebsiteFooterConfig.fromMap(_map(map['footer'])),
    );
  }

  Map<String, dynamic> toMap() => {
    'version': schemaVersion,
    'schoolName': schoolName.trim(),
    'tagline': tagline.trim(),
    'logo': logo.toMap(),
    'phone': phone.trim(),
    'email': email.trim(),
    'address': address.trim(),
    'primaryColor': primaryColor,
    'fontFamily': fontFamily,
    'navigation': navigation.map((item) => item.toMap()).toList(),
    'socialLinks': socialLinks.map((item) => item.toMap()).toList(),
    'header': header.toMap(),
    'footer': footer.toMap(),
  };

  WebsiteSiteConfig copyWith({
    String? schoolName,
    String? tagline,
    WebsiteAsset? logo,
    String? phone,
    String? email,
    String? address,
    String? primaryColor,
    String? fontFamily,
    List<WebsiteNavigationItem>? navigation,
    List<WebsiteSocialLink>? socialLinks,
    WebsiteHeaderConfig? header,
    WebsiteFooterConfig? footer,
  }) => WebsiteSiteConfig(
    schoolName: schoolName ?? this.schoolName,
    tagline: tagline ?? this.tagline,
    logo: logo ?? this.logo,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    address: address ?? this.address,
    primaryColor: primaryColor ?? this.primaryColor,
    fontFamily: fontFamily ?? this.fontFamily,
    navigation: navigation ?? this.navigation,
    socialLinks: socialLinks ?? this.socialLinks,
    header: header ?? this.header,
    footer: footer ?? this.footer,
  );
}

class WebsiteBundle {
  final WebsiteSiteConfig config;
  final List<WebsitePage> pages;

  const WebsiteBundle({required this.config, required this.pages});

  WebsitePage? pageById(String id) {
    for (final page in pages) {
      if (page.id == id) return page;
    }
    return null;
  }

  Set<String> get managedAssetPaths => {
    if (config.logo.isManaged) config.logo.storagePath,
    for (final row in [
      ...config.header.rows,
      ...config.footer.rows,
      for (final page in pages) ...page.rows,
    ])
      for (final column in row.columns)
        for (final component in column.components) ...[
          if (component.image.isManaged) component.image.storagePath,
          for (final item in component.items)
            if (item.image.isManaged) item.image.storagePath,
        ],
  };

  static final defaults = _defaultBundle();
}

WebsiteBundle _defaultBundle() {
  const navigation = [
    WebsiteNavigationItem(id: 'about', label: 'Nosotros', slug: 'nosotros'),
    WebsiteNavigationItem(
      id: 'admissions',
      label: 'Admisiones',
      slug: 'admisiones',
    ),
    WebsiteNavigationItem(
      id: 'learning',
      label: 'Propuesta académica',
      slug: 'propuesta-academica',
    ),
    WebsiteNavigationItem(id: 'news', label: 'Noticias', slug: 'noticias'),
  ];
  final header = WebsiteHeaderConfig(
    rows: [
      WebsiteRow(
        id: 'header_main',
        padding: 12,
        columns: [
          WebsiteColumn(
            id: 'header_brand',
            components: [
              WebsiteComponent(id: 'site_identity', type: 'siteIdentity'),
            ],
          ),
          WebsiteColumn(
            id: 'header_navigation',
            span: 2,
            components: [
              WebsiteComponent(
                id: 'site_navigation',
                type: 'navigation',
                alignment: 'right',
              ),
            ],
          ),
        ],
      ),
    ],
  );
  final footer = WebsiteFooterConfig(
    rows: [
      WebsiteRow(
        id: 'footer_main',
        backgroundColor: '#2B1718',
        padding: 34,
        columns: [
          WebsiteColumn(
            id: 'footer_identity',
            backgroundColor: '#2B1718',
            components: [
              WebsiteComponent(
                id: 'footer_brand',
                type: 'siteIdentity',
                backgroundColor: '#2B1718',
                textColor: '#FFFFFF',
              ),
              WebsiteComponent(
                id: 'footer_social',
                type: 'socialLinks',
                backgroundColor: '#2B1718',
                textColor: '#FFFFFF',
              ),
            ],
          ),
          WebsiteColumn(
            id: 'footer_contact',
            backgroundColor: '#2B1718',
            components: [
              WebsiteComponent(
                id: 'footer_contact_component',
                type: 'contactInfo',
                title: 'Contáctanos',
                backgroundColor: '#2B1718',
                textColor: '#FFFFFF',
              ),
            ],
          ),
          WebsiteColumn(
            id: 'footer_links',
            backgroundColor: '#2B1718',
            components: [
              WebsiteComponent(
                id: 'footer_navigation',
                type: 'navigation',
                title: 'Enlaces',
                backgroundColor: '#2B1718',
                textColor: '#FFFFFF',
              ),
            ],
          ),
        ],
      ),
    ],
  );
  const hero = WebsiteComponent(
    id: 'home_hero',
    type: 'hero',
    title: 'Formamos estudiantes con valores y pasión por aprender',
    body: 'Educación bilingüe integral en un ambiente seguro e inclusivo.',
    image: WebsiteAsset(
      url:
          'asset:assets/pagina_inicio/WhatsApp Image 2026-06-26 at 12.16.23 PM.jpeg',
    ),
    textColor: '#FFFFFF',
    backgroundColor: '#2B1718',
    accentColor: '#A63D40',
    titleSize: 56,
    padding: 48,
  );
  final pages = [
    const WebsitePage(
      id: 'home',
      label: 'Inicio',
      slug: 'home',
      showInNavigation: false,
      sortOrder: -1,
      rows: [
        WebsiteRow(
          id: 'home_row',
          padding: 0,
          maxWidth: 1920,
          columns: [
            WebsiteColumn(id: 'home_column', padding: 0, components: [hero]),
          ],
        ),
      ],
    ),
    for (var i = 0; i < navigation.length; i++)
      WebsitePage(
        id: navigation[i].id,
        label: navigation[i].label,
        slug: navigation[i].slug,
        sortOrder: i,
        rows: [
          WebsiteRow(
            id: '${navigation[i].id}_row',
            columns: [
              WebsiteColumn(
                id: '${navigation[i].id}_column',
                components: [
                  WebsiteComponent(
                    id: '${navigation[i].id}_intro',
                    type: 'text',
                    title: navigation[i].label,
                    body:
                        'Edita este contenido desde el constructor del sitio.',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
  ];
  return WebsiteBundle(
    config: WebsiteSiteConfig(
      schoolName: 'Liceo Bilingüe Rodolfo Llinás',
      tagline: 'Educamos hoy para liderar mañana',
      logo: const WebsiteAsset(url: 'asset:assets/logo_fondo.png'),
      navigation: navigation,
      socialLinks: const [
        WebsiteSocialLink(platform: 'facebook'),
        WebsiteSocialLink(platform: 'instagram'),
        WebsiteSocialLink(platform: 'youtube'),
        WebsiteSocialLink(platform: 'tiktok'),
      ],
      header: header,
      footer: footer,
    ),
    pages: pages,
  );
}

Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : <Map<String, dynamic>>[];

List<WebsiteRow> _rows(dynamic value) => _list(value)
    .asMap()
    .entries
    .map((entry) => WebsiteRow.fromMap(entry.value, entry.key))
    .toList();

int _int(dynamic value, int fallback) =>
    value is num ? value.toInt() : fallback;
