class WebsiteAsset {
  final String url;
  final String storagePath;

  const WebsiteAsset({this.url = '', this.storagePath = ''});

  factory WebsiteAsset.fromLegacyUrl(String url) =>
      WebsiteAsset(url: url, storagePath: _storagePathFromDownloadUrl(url));

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
    this.slug = '',
    this.enabled = true,
  });

  String get resolvedSlug => slug.isEmpty ? id : slug;

  factory WebsiteNavigationItem.fromMap(Map<String, dynamic> map) =>
      WebsiteNavigationItem(
        id: (map['id'] ?? '').toString(),
        label: (map['label'] ?? '').toString(),
        slug: (map['slug'] ?? map['id'] ?? '').toString(),
        enabled: map['enabled'] != false,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label.trim(),
    'slug': resolvedSlug,
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

class WebsiteBlock {
  final String id;
  final String type;
  final String pageId;
  final String title;
  final String body;
  final WebsiteAsset image;
  final String buttonLabel;
  final String buttonUrl;
  final bool enabled;
  final bool showOnDesktop;
  final bool showOnMobile;
  final int mobileOrder;
  final String textAlignment;
  final String imagePosition;
  final String mobileImagePosition;
  final String imageFit;
  final String contentWidth;
  final String backgroundColor;
  final String textColor;
  final String accentColor;
  final bool showAccent;
  final String fontFamily;
  final int titleSize;
  final int mobileTitleSize;
  final int bodySize;
  final int mobileBodySize;
  final int padding;
  final int mobilePadding;

  const WebsiteBlock({
    required this.id,
    this.type = 'imageText',
    this.pageId = 'about',
    this.title = '',
    this.body = '',
    this.image = const WebsiteAsset(),
    this.buttonLabel = '',
    this.buttonUrl = '',
    this.enabled = true,
    this.showOnDesktop = true,
    this.showOnMobile = true,
    this.mobileOrder = 0,
    this.textAlignment = 'left',
    this.imagePosition = 'left',
    this.mobileImagePosition = 'top',
    this.imageFit = 'cover',
    this.contentWidth = 'wide',
    this.backgroundColor = '#FAF8F5',
    this.textColor = '#212121',
    this.accentColor = '#B71C1C',
    this.showAccent = false,
    this.fontFamily = 'Montserrat',
    this.titleSize = 34,
    this.mobileTitleSize = 30,
    this.bodySize = 17,
    this.mobileBodySize = 16,
    this.padding = 38,
    this.mobilePadding = 22,
  });

  factory WebsiteBlock.fromMap(Map<String, dynamic> map, {int index = 0}) {
    final rawImage = map['image'];
    return WebsiteBlock(
      id: (map['id'] ?? 'block_$index').toString(),
      type: (map['type'] ?? 'imageText').toString(),
      pageId: (map['pageId'] ?? 'about').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      image: rawImage is Map
          ? WebsiteAsset.fromMap(Map<String, dynamic>.from(rawImage))
          : WebsiteAsset.fromLegacyUrl((map['imageUrl'] ?? '').toString()),
      buttonLabel: (map['buttonLabel'] ?? '').toString(),
      buttonUrl: (map['buttonUrl'] ?? '').toString(),
      enabled: map['enabled'] != false,
      showOnDesktop: map['showOnDesktop'] != false,
      showOnMobile: map['showOnMobile'] != false,
      mobileOrder: map['mobileOrder'] is num
          ? (map['mobileOrder'] as num).toInt()
          : index,
      textAlignment: (map['textAlignment'] ?? 'left').toString(),
      imagePosition: (map['imagePosition'] ?? 'left').toString(),
      mobileImagePosition: (map['mobileImagePosition'] ?? 'top').toString(),
      imageFit: (map['imageFit'] ?? 'cover').toString(),
      contentWidth: (map['contentWidth'] ?? 'wide').toString(),
      backgroundColor: (map['backgroundColor'] ?? '#FAF8F5').toString(),
      textColor: (map['textColor'] ?? '#212121').toString(),
      accentColor: (map['accentColor'] ?? map['primaryColor'] ?? '#B71C1C')
          .toString(),
      showAccent: map['showAccent'] == true,
      fontFamily: (map['fontFamily'] ?? 'Montserrat').toString(),
      titleSize: _int(map['titleSize'], 34),
      mobileTitleSize: _int(map['mobileTitleSize'], 30),
      bodySize: _int(map['bodySize'], 17),
      mobileBodySize: _int(map['mobileBodySize'], 16),
      padding: _int(map['padding'], 38),
      mobilePadding: _int(map['mobilePadding'], 22),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'pageId': pageId,
    'title': title.trim(),
    'body': body.trim(),
    'image': image.toMap(),
    'buttonLabel': buttonLabel.trim(),
    'buttonUrl': buttonUrl.trim(),
    'enabled': enabled,
    'showOnDesktop': showOnDesktop,
    'showOnMobile': showOnMobile,
    'mobileOrder': mobileOrder,
    'textAlignment': textAlignment,
    'imagePosition': imagePosition,
    'mobileImagePosition': mobileImagePosition,
    'imageFit': imageFit,
    'contentWidth': contentWidth,
    'backgroundColor': backgroundColor,
    'textColor': textColor,
    'accentColor': accentColor,
    'showAccent': showAccent,
    'fontFamily': fontFamily,
    'titleSize': titleSize,
    'mobileTitleSize': mobileTitleSize,
    'bodySize': bodySize,
    'mobileBodySize': mobileBodySize,
    'padding': padding,
    'mobilePadding': mobilePadding,
  };

  WebsiteBlock copyWith({
    String? id,
    String? type,
    String? pageId,
    String? title,
    String? body,
    WebsiteAsset? image,
    String? buttonLabel,
    String? buttonUrl,
    bool? enabled,
    bool? showOnDesktop,
    bool? showOnMobile,
    int? mobileOrder,
    String? textAlignment,
    String? imagePosition,
    String? mobileImagePosition,
    String? imageFit,
    String? contentWidth,
    String? backgroundColor,
    String? textColor,
    String? accentColor,
    bool? showAccent,
    String? fontFamily,
    int? titleSize,
    int? mobileTitleSize,
    int? bodySize,
    int? mobileBodySize,
    int? padding,
    int? mobilePadding,
  }) => WebsiteBlock(
    id: id ?? this.id,
    type: type ?? this.type,
    pageId: pageId ?? this.pageId,
    title: title ?? this.title,
    body: body ?? this.body,
    image: image ?? this.image,
    buttonLabel: buttonLabel ?? this.buttonLabel,
    buttonUrl: buttonUrl ?? this.buttonUrl,
    enabled: enabled ?? this.enabled,
    showOnDesktop: showOnDesktop ?? this.showOnDesktop,
    showOnMobile: showOnMobile ?? this.showOnMobile,
    mobileOrder: mobileOrder ?? this.mobileOrder,
    textAlignment: textAlignment ?? this.textAlignment,
    imagePosition: imagePosition ?? this.imagePosition,
    mobileImagePosition: mobileImagePosition ?? this.mobileImagePosition,
    imageFit: imageFit ?? this.imageFit,
    contentWidth: contentWidth ?? this.contentWidth,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    textColor: textColor ?? this.textColor,
    accentColor: accentColor ?? this.accentColor,
    showAccent: showAccent ?? this.showAccent,
    fontFamily: fontFamily ?? this.fontFamily,
    titleSize: titleSize ?? this.titleSize,
    mobileTitleSize: mobileTitleSize ?? this.mobileTitleSize,
    bodySize: bodySize ?? this.bodySize,
    mobileBodySize: mobileBodySize ?? this.mobileBodySize,
    padding: padding ?? this.padding,
    mobilePadding: mobilePadding ?? this.mobilePadding,
  );

  static int _int(dynamic value, int fallback) =>
      value is num ? value.toInt() : fallback;
}

typedef WebsiteSection = WebsiteBlock;

class WebsitePage {
  final String id;
  final String label;
  final String slug;
  final bool enabled;
  final bool showInNavigation;
  final int sortOrder;
  final List<WebsiteBlock> blocks;

  const WebsitePage({
    required this.id,
    required this.label,
    required this.slug,
    this.enabled = true,
    this.showInNavigation = true,
    this.sortOrder = 0,
    this.blocks = const [],
  });

  factory WebsitePage.fromMap(String id, Map<String, dynamic> map) {
    final rawBlocks = map['blocks'];
    return WebsitePage(
      id: id,
      label: (map['label'] ?? id).toString(),
      slug: (map['slug'] ?? id).toString(),
      enabled: map['enabled'] != false,
      showInNavigation: map['showInNavigation'] != false,
      sortOrder: WebsiteBlock._int(map['sortOrder'], 0),
      blocks: rawBlocks is List
          ? rawBlocks
                .asMap()
                .entries
                .where((entry) => entry.value is Map)
                .map(
                  (entry) => WebsiteBlock.fromMap(
                    Map<String, dynamic>.from(entry.value as Map),
                    index: entry.key,
                  ),
                )
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'label': label.trim(),
    'slug': slug.trim(),
    'enabled': enabled,
    'showInNavigation': showInNavigation,
    'sortOrder': sortOrder,
    'blocks': blocks.map((block) => block.toMap()).toList(),
  };

  WebsitePage copyWith({
    String? label,
    String? slug,
    bool? enabled,
    bool? showInNavigation,
    int? sortOrder,
    List<WebsiteBlock>? blocks,
  }) => WebsitePage(
    id: id,
    label: label ?? this.label,
    slug: slug ?? this.slug,
    enabled: enabled ?? this.enabled,
    showInNavigation: showInNavigation ?? this.showInNavigation,
    sortOrder: sortOrder ?? this.sortOrder,
    blocks: blocks ?? this.blocks,
  );
}

class WebsiteFooterConfig {
  final bool enabled;
  final String layout;
  final String alignment;
  final String backgroundColor;
  final String textColor;
  final String secondaryTextColor;
  final String accentColor;
  final String fontFamily;
  final String title;
  final String description;
  final String contactTitle;
  final String linksTitle;
  final String copyrightText;
  final WebsiteAsset logo;
  final bool useSiteLogo;
  final bool showLogo;
  final bool showDescription;
  final bool showContact;
  final bool showSocialLinks;
  final bool showNavigation;
  final bool showCopyright;
  final bool useGlobalContact;
  final String address;
  final String phone;
  final String email;
  final int titleSize;
  final int bodySize;
  final int padding;
  final int mobilePadding;
  final int logoSize;
  final int maxWidth;

  const WebsiteFooterConfig({
    this.enabled = true,
    this.layout = 'columns',
    this.alignment = 'left',
    this.backgroundColor = '#25090A',
    this.textColor = '#FFFFFF',
    this.secondaryTextColor = '#D7C6C6',
    this.accentColor = '#B71C1C',
    this.fontFamily = '',
    this.title = '',
    this.description = '',
    this.contactTitle = 'Contáctanos',
    this.linksTitle = 'Enlaces',
    this.copyrightText = '',
    this.logo = const WebsiteAsset(),
    this.useSiteLogo = true,
    this.showLogo = false,
    this.showDescription = true,
    this.showContact = true,
    this.showSocialLinks = true,
    this.showNavigation = false,
    this.showCopyright = true,
    this.useGlobalContact = true,
    this.address = '',
    this.phone = '',
    this.email = '',
    this.titleSize = 23,
    this.bodySize = 15,
    this.padding = 42,
    this.mobilePadding = 24,
    this.logoSize = 72,
    this.maxWidth = 1280,
  });

  factory WebsiteFooterConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const WebsiteFooterConfig();
    final rawLogo = map['logo'];
    return WebsiteFooterConfig(
      enabled: map['enabled'] != false,
      layout: (map['layout'] ?? 'columns').toString(),
      alignment: (map['alignment'] ?? 'left').toString(),
      backgroundColor: (map['backgroundColor'] ?? '#25090A').toString(),
      textColor: (map['textColor'] ?? '#FFFFFF').toString(),
      secondaryTextColor: (map['secondaryTextColor'] ?? '#D7C6C6').toString(),
      accentColor: (map['accentColor'] ?? '#B71C1C').toString(),
      fontFamily: (map['fontFamily'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      contactTitle: (map['contactTitle'] ?? 'Contáctanos').toString(),
      linksTitle: (map['linksTitle'] ?? 'Enlaces').toString(),
      copyrightText: (map['copyrightText'] ?? '').toString(),
      logo: rawLogo is Map
          ? WebsiteAsset.fromMap(Map<String, dynamic>.from(rawLogo))
          : const WebsiteAsset(),
      useSiteLogo: map['useSiteLogo'] != false,
      showLogo: map['showLogo'] == true,
      showDescription: map['showDescription'] != false,
      showContact: map['showContact'] != false,
      showSocialLinks: map['showSocialLinks'] != false,
      showNavigation: map['showNavigation'] == true,
      showCopyright: map['showCopyright'] != false,
      useGlobalContact: map['useGlobalContact'] != false,
      address: (map['address'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      titleSize: WebsiteBlock._int(map['titleSize'], 23),
      bodySize: WebsiteBlock._int(map['bodySize'], 15),
      padding: WebsiteBlock._int(map['padding'], 42),
      mobilePadding: WebsiteBlock._int(map['mobilePadding'], 24),
      logoSize: WebsiteBlock._int(map['logoSize'], 72),
      maxWidth: WebsiteBlock._int(map['maxWidth'], 1280),
    );
  }

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'layout': layout,
    'alignment': alignment,
    'backgroundColor': backgroundColor.trim(),
    'textColor': textColor.trim(),
    'secondaryTextColor': secondaryTextColor.trim(),
    'accentColor': accentColor.trim(),
    'fontFamily': fontFamily,
    'title': title.trim(),
    'description': description.trim(),
    'contactTitle': contactTitle.trim(),
    'linksTitle': linksTitle.trim(),
    'copyrightText': copyrightText.trim(),
    'logo': logo.toMap(),
    'useSiteLogo': useSiteLogo,
    'showLogo': showLogo,
    'showDescription': showDescription,
    'showContact': showContact,
    'showSocialLinks': showSocialLinks,
    'showNavigation': showNavigation,
    'showCopyright': showCopyright,
    'useGlobalContact': useGlobalContact,
    'address': address.trim(),
    'phone': phone.trim(),
    'email': email.trim(),
    'titleSize': titleSize,
    'bodySize': bodySize,
    'padding': padding,
    'mobilePadding': mobilePadding,
    'logoSize': logoSize,
    'maxWidth': maxWidth,
  };

  WebsiteFooterConfig copyWith({
    bool? enabled,
    String? layout,
    String? alignment,
    String? backgroundColor,
    String? textColor,
    String? secondaryTextColor,
    String? accentColor,
    String? fontFamily,
    String? title,
    String? description,
    String? contactTitle,
    String? linksTitle,
    String? copyrightText,
    WebsiteAsset? logo,
    bool? useSiteLogo,
    bool? showLogo,
    bool? showDescription,
    bool? showContact,
    bool? showSocialLinks,
    bool? showNavigation,
    bool? showCopyright,
    bool? useGlobalContact,
    String? address,
    String? phone,
    String? email,
    int? titleSize,
    int? bodySize,
    int? padding,
    int? mobilePadding,
    int? logoSize,
    int? maxWidth,
  }) => WebsiteFooterConfig(
    enabled: enabled ?? this.enabled,
    layout: layout ?? this.layout,
    alignment: alignment ?? this.alignment,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    textColor: textColor ?? this.textColor,
    secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
    accentColor: accentColor ?? this.accentColor,
    fontFamily: fontFamily ?? this.fontFamily,
    title: title ?? this.title,
    description: description ?? this.description,
    contactTitle: contactTitle ?? this.contactTitle,
    linksTitle: linksTitle ?? this.linksTitle,
    copyrightText: copyrightText ?? this.copyrightText,
    logo: logo ?? this.logo,
    useSiteLogo: useSiteLogo ?? this.useSiteLogo,
    showLogo: showLogo ?? this.showLogo,
    showDescription: showDescription ?? this.showDescription,
    showContact: showContact ?? this.showContact,
    showSocialLinks: showSocialLinks ?? this.showSocialLinks,
    showNavigation: showNavigation ?? this.showNavigation,
    showCopyright: showCopyright ?? this.showCopyright,
    useGlobalContact: useGlobalContact ?? this.useGlobalContact,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    titleSize: titleSize ?? this.titleSize,
    bodySize: bodySize ?? this.bodySize,
    padding: padding ?? this.padding,
    mobilePadding: mobilePadding ?? this.mobilePadding,
    logoSize: logoSize ?? this.logoSize,
    maxWidth: maxWidth ?? this.maxWidth,
  );
}

class WebsiteSiteConfig {
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
  final WebsiteFooterConfig footer;

  const WebsiteSiteConfig({
    required this.schoolName,
    required this.tagline,
    this.logo = const WebsiteAsset(),
    this.phone = '',
    this.email = '',
    this.address = '',
    this.primaryColor = '#B71C1C',
    this.fontFamily = 'Montserrat',
    this.navigation = const [],
    this.socialLinks = const [],
    this.footer = const WebsiteFooterConfig(),
  });

  factory WebsiteSiteConfig.fromMap(Map<String, dynamic> map) {
    final logo = map['logo'];
    return WebsiteSiteConfig(
      schoolName: (map['schoolName'] ?? '').toString(),
      tagline: (map['tagline'] ?? '').toString(),
      logo: logo is Map
          ? WebsiteAsset.fromMap(Map<String, dynamic>.from(logo))
          : WebsiteAsset.fromLegacyUrl((map['logoUrl'] ?? '').toString()),
      phone: (map['phone'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      primaryColor: (map['primaryColor'] ?? '#B71C1C').toString(),
      fontFamily: (map['fontFamily'] ?? 'Montserrat').toString(),
      navigation: _maps(map['navigation'], WebsiteNavigationItem.fromMap),
      socialLinks: _maps(map['socialLinks'], WebsiteSocialLink.fromMap),
      footer: map['footer'] is Map
          ? WebsiteFooterConfig.fromMap(
              Map<String, dynamic>.from(map['footer'] as Map),
            )
          : const WebsiteFooterConfig(),
    );
  }

  Map<String, dynamic> toMap() => {
    'schoolName': schoolName.trim(),
    'tagline': tagline.trim(),
    'logo': logo.toMap(),
    'phone': phone.trim(),
    'email': email.trim(),
    'address': address.trim(),
    'primaryColor': primaryColor.trim(),
    'fontFamily': fontFamily,
    'navigation': navigation.map((item) => item.toMap()).toList(),
    'socialLinks': socialLinks.map((item) => item.toMap()).toList(),
    'footer': footer.toMap(),
    'version': 4,
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
    footer: footer ?? this.footer,
  );

  static List<T> _maps<T>(dynamic raw, T Function(Map<String, dynamic>) read) =>
      raw is List
      ? raw
            .whereType<Map>()
            .map((item) => read(Map<String, dynamic>.from(item)))
            .toList()
      : <T>[];
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
    if (config.footer.logo.isManaged) config.footer.logo.storagePath,
    for (final page in pages)
      for (final block in page.blocks)
        if (block.image.isManaged) block.image.storagePath,
  };

  static final defaults = _defaultBundle();
}

// Modelo v2 conservado exclusivamente para migrar contenido ya publicado.
class WebsiteContent {
  final String schoolName;
  final String tagline;
  final String heroTitle;
  final String heroBody;
  final String heroImageUrl;
  final String logoUrl;
  final String phone;
  final String email;
  final String address;
  final String primaryColor;
  final List<WebsiteNavigationItem> navigation;
  final List<WebsiteBlock> sections;

  const WebsiteContent({
    required this.schoolName,
    required this.tagline,
    required this.heroTitle,
    required this.heroBody,
    required this.heroImageUrl,
    required this.logoUrl,
    required this.phone,
    required this.email,
    required this.address,
    required this.primaryColor,
    required this.navigation,
    required this.sections,
  });

  factory WebsiteContent.fromMap(Map<String, dynamic> map) {
    final rawSections = map['sections'];
    var sections = rawSections is List
        ? rawSections
              .asMap()
              .entries
              .where((entry) => entry.value is Map)
              .map(
                (entry) => WebsiteBlock.fromMap(
                  Map<String, dynamic>.from(entry.value as Map),
                  index: entry.key,
                ),
              )
              .toList()
        : <WebsiteBlock>[];
    final defaults = WebsiteContent.defaults;
    final existingPages = <String>{
      for (final raw in rawSections is List ? rawSections : const [])
        if (raw is Map) (raw['pageId'] ?? 'about').toString(),
    };
    for (final item in defaults.sectionsByPage.entries) {
      if (!existingPages.contains(item.key)) sections.addAll(item.value);
    }
    return WebsiteContent(
      schoolName: (map['schoolName'] ?? defaults.schoolName).toString(),
      tagline: (map['tagline'] ?? defaults.tagline).toString(),
      heroTitle: (map['heroTitle'] ?? defaults.heroTitle).toString(),
      heroBody: (map['heroBody'] ?? defaults.heroBody).toString(),
      heroImageUrl: (map['heroImageUrl'] ?? defaults.heroImageUrl).toString(),
      logoUrl: (map['logoUrl'] ?? defaults.logoUrl).toString(),
      phone: (map['phone'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      primaryColor: (map['primaryColor'] ?? '#B71C1C').toString(),
      navigation:
          WebsiteSiteConfig._maps(
            map['navigation'],
            WebsiteNavigationItem.fromMap,
          ).isEmpty
          ? defaults.navigation
          : WebsiteSiteConfig._maps(
              map['navigation'],
              WebsiteNavigationItem.fromMap,
            ),
      sections: sections,
    );
  }

  Map<String, dynamic> toMap() => {
    'schoolName': schoolName,
    'tagline': tagline,
    'heroTitle': heroTitle,
    'heroBody': heroBody,
    'heroImageUrl': heroImageUrl,
    'logoUrl': logoUrl,
    'phone': phone,
    'email': email,
    'address': address,
    'primaryColor': primaryColor,
    'navigation': navigation.map((item) => item.toMap()).toList(),
    'sections': sections.map((item) => item.toMap()).toList(),
  };

  Map<String, List<WebsiteBlock>> get sectionsByPage {
    final result = <String, List<WebsiteBlock>>{};
    for (final section in sections) {
      result.putIfAbsent(section.pageId, () => []).add(section);
    }
    return result;
  }

  WebsiteBundle toBundle(Map<String, List<WebsiteBlock>> grouped) {
    final config = WebsiteSiteConfig(
      schoolName: schoolName,
      tagline: tagline,
      logo: WebsiteAsset.fromLegacyUrl(logoUrl),
      phone: phone,
      email: email,
      address: address,
      primaryColor: primaryColor,
      navigation: navigation,
      socialLinks: WebsiteBundle.defaults.config.socialLinks,
    );
    final pages = <WebsitePage>[
      WebsitePage(
        id: 'home',
        label: 'Inicio',
        slug: 'home',
        showInNavigation: false,
        sortOrder: -1,
        blocks: [
          WebsiteBlock(
            id: 'home_hero',
            type: 'hero',
            title: heroTitle,
            body: heroBody,
            image: WebsiteAsset.fromLegacyUrl(heroImageUrl),
            textColor: '#FFFFFF',
            backgroundColor: '#25090A',
            titleSize: 62,
            mobileTitleSize: 39,
          ),
        ],
      ),
      for (var index = 0; index < navigation.length; index++)
        WebsitePage(
          id: navigation[index].id,
          label: navigation[index].label,
          slug: navigation[index].resolvedSlug,
          enabled: navigation[index].enabled,
          sortOrder: index,
          blocks: grouped[navigation[index].id] ?? const [],
        ),
    ];
    return WebsiteBundle(config: config, pages: pages);
  }

  static final defaults = _legacyDefaults();
}

WebsiteBundle _defaultBundle() {
  const navigation = [
    WebsiteNavigationItem(id: 'about', label: 'About', slug: 'about'),
    WebsiteNavigationItem(
      id: 'admissions',
      label: 'Admissions',
      slug: 'admissions',
    ),
    WebsiteNavigationItem(id: 'learning', label: 'Learning', slug: 'learning'),
    WebsiteNavigationItem(
      id: 'news',
      label: 'News & Events',
      slug: 'news-events',
    ),
    WebsiteNavigationItem(id: 'parents', label: 'Parents', slug: 'parents'),
  ];
  const config = WebsiteSiteConfig(
    schoolName: 'Liceo Bilingüe Rodolfo Llinás',
    tagline: 'Educamos hoy para liderar mañana',
    logo: WebsiteAsset(url: 'asset:assets/logo_fondo.png'),
    primaryColor: '#B71C1C',
    fontFamily: 'Montserrat',
    navigation: navigation,
    socialLinks: [
      WebsiteSocialLink(platform: 'facebook'),
      WebsiteSocialLink(platform: 'instagram'),
      WebsiteSocialLink(platform: 'youtube'),
      WebsiteSocialLink(platform: 'tiktok'),
    ],
  );
  final pages = <WebsitePage>[
    const WebsitePage(
      id: 'home',
      label: 'Inicio',
      slug: 'home',
      showInNavigation: false,
      sortOrder: -1,
      blocks: [
        WebsiteBlock(
          id: 'home_hero',
          type: 'hero',
          title: 'Formamos estudiantes con valores y pasión por aprender',
          body:
              'Educación bilingüe integral en un ambiente seguro e inclusivo.',
          image: WebsiteAsset(
            url:
                'asset:assets/pagina_inicio/WhatsApp Image 2026-06-26 at 12.16.23 PM.jpeg',
          ),
          textColor: '#FFFFFF',
          titleSize: 62,
          mobileTitleSize: 39,
        ),
      ],
    ),
    for (var index = 0; index < navigation.length; index++)
      WebsitePage(
        id: navigation[index].id,
        label: navigation[index].label,
        slug: navigation[index].resolvedSlug,
        sortOrder: index,
        blocks: [
          WebsiteBlock(
            id: '${navigation[index].id}_intro',
            type: 'imageText',
            pageId: navigation[index].id,
            title: navigation[index].label,
            body: _defaultBody(navigation[index].id),
            image: WebsiteAsset(
              url:
                  'asset:assets/pagina_inicio/WhatsApp Image 2026-06-26 at 12.16.20 PM (${index + 1}).jpeg',
            ),
            mobileOrder: 0,
          ),
        ],
      ),
  ];
  return WebsiteBundle(config: config, pages: pages);
}

WebsiteContent _legacyDefaults() {
  final bundle = WebsiteBundle.defaults;
  return WebsiteContent(
    schoolName: bundle.config.schoolName,
    tagline: bundle.config.tagline,
    heroTitle: bundle.pages.first.blocks.first.title,
    heroBody: bundle.pages.first.blocks.first.body,
    heroImageUrl: bundle.pages.first.blocks.first.image.url,
    logoUrl: bundle.config.logo.url,
    phone: '',
    email: '',
    address: '',
    primaryColor: bundle.config.primaryColor,
    navigation: bundle.config.navigation,
    sections: [for (final page in bundle.pages.skip(1)) ...page.blocks],
  );
}

String _defaultBody(String id) => switch (id) {
  'about' => 'Conoce nuestra historia, filosofía y comunidad educativa.',
  'admissions' => 'Encuentra el proceso de admisiones y solicita información.',
  'learning' => 'Explora nuestra propuesta académica y formación bilingüe.',
  'news' => 'Consulta las noticias, actividades y próximos eventos.',
  _ => 'Accede a información y recursos importantes para las familias.',
};

String _storagePathFromDownloadUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.host.contains('firebasestorage.googleapis.com')) {
    return '';
  }
  final marker = '/o/';
  final markerIndex = uri.path.indexOf(marker);
  if (markerIndex < 0) return '';
  final encoded = uri.path.substring(markerIndex + marker.length);
  final decoded = Uri.decodeComponent(encoded);
  return decoded.startsWith('website/') ? decoded : '';
}
