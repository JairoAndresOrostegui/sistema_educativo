class WebsiteNavigationItem {
  final String id;
  final String label;
  final bool enabled;

  const WebsiteNavigationItem({
    required this.id,
    required this.label,
    this.enabled = true,
  });

  factory WebsiteNavigationItem.fromMap(Map<String, dynamic> map) =>
      WebsiteNavigationItem(
        id: (map['id'] ?? '').toString(),
        label: (map['label'] ?? '').toString(),
        enabled: map['enabled'] != false,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label.trim(),
    'enabled': enabled,
  };

  WebsiteNavigationItem copyWith({String? label, bool? enabled}) =>
      WebsiteNavigationItem(
        id: id,
        label: label ?? this.label,
        enabled: enabled ?? this.enabled,
      );
}

class WebsiteSection {
  final String id;
  final String title;
  final String body;
  final String imageUrl;
  final String buttonLabel;
  final String buttonUrl;
  final bool enabled;
  final String pageId;
  final String textAlignment;
  final String imagePosition;
  final String imageFit;
  final String contentWidth;
  final String backgroundColor;
  final String textColor;

  const WebsiteSection({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl = '',
    this.buttonLabel = '',
    this.buttonUrl = '',
    this.enabled = true,
    this.pageId = 'about',
    this.textAlignment = 'left',
    this.imagePosition = 'left',
    this.imageFit = 'cover',
    this.contentWidth = 'wide',
    this.backgroundColor = '#FAF8F5',
    this.textColor = '#212121',
  });

  factory WebsiteSection.fromMap(Map<String, dynamic> map) => WebsiteSection(
    id: (map['id'] ?? '').toString(),
    title: (map['title'] ?? '').toString(),
    body: (map['body'] ?? '').toString(),
    imageUrl: (map['imageUrl'] ?? '').toString(),
    buttonLabel: (map['buttonLabel'] ?? '').toString(),
    buttonUrl: (map['buttonUrl'] ?? '').toString(),
    enabled: map['enabled'] != false,
    pageId: (map['pageId'] ?? 'about').toString(),
    textAlignment: (map['textAlignment'] ?? 'left').toString(),
    imagePosition: (map['imagePosition'] ?? 'left').toString(),
    imageFit: (map['imageFit'] ?? 'cover').toString(),
    contentWidth: (map['contentWidth'] ?? 'wide').toString(),
    backgroundColor: (map['backgroundColor'] ?? '#FAF8F5').toString(),
    textColor: (map['textColor'] ?? '#212121').toString(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title.trim(),
    'body': body.trim(),
    'imageUrl': imageUrl.trim(),
    'buttonLabel': buttonLabel.trim(),
    'buttonUrl': buttonUrl.trim(),
    'enabled': enabled,
    'pageId': pageId,
    'textAlignment': textAlignment,
    'imagePosition': imagePosition,
    'imageFit': imageFit,
    'contentWidth': contentWidth,
    'backgroundColor': backgroundColor,
    'textColor': textColor,
  };

  WebsiteSection copyWith({
    String? id,
    String? title,
    String? body,
    String? imageUrl,
    String? buttonLabel,
    String? buttonUrl,
    bool? enabled,
    String? pageId,
    String? textAlignment,
    String? imagePosition,
    String? imageFit,
    String? contentWidth,
    String? backgroundColor,
    String? textColor,
  }) => WebsiteSection(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    imageUrl: imageUrl ?? this.imageUrl,
    buttonLabel: buttonLabel ?? this.buttonLabel,
    buttonUrl: buttonUrl ?? this.buttonUrl,
    enabled: enabled ?? this.enabled,
    pageId: pageId ?? this.pageId,
    textAlignment: textAlignment ?? this.textAlignment,
    imagePosition: imagePosition ?? this.imagePosition,
    imageFit: imageFit ?? this.imageFit,
    contentWidth: contentWidth ?? this.contentWidth,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    textColor: textColor ?? this.textColor,
  );
}

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
  final List<WebsiteSection> sections;

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
    final rawNavigation = map['navigation'];
    final version = map['version'] is num ? (map['version'] as num).toInt() : 1;
    var sections =
        rawSections is List
            ? rawSections
                .whereType<Map>()
                .map(
                  (item) =>
                      WebsiteSection.fromMap(Map<String, dynamic>.from(item)),
                )
                .toList()
            : <WebsiteSection>[];
    if (version < 2) {
      final requiredPages = {'admissions', 'learning', 'news', 'parents'};
      final existingPages = sections.map((section) => section.pageId).toSet();
      sections = [
        ...sections,
        ...defaults.sections.where(
          (section) =>
              requiredPages.contains(section.pageId) &&
              !existingPages.contains(section.pageId),
        ),
      ];
    }
    return WebsiteContent(
      schoolName: (map['schoolName'] ?? '').toString(),
      tagline: (map['tagline'] ?? '').toString(),
      heroTitle: (map['heroTitle'] ?? '').toString(),
      heroBody: (map['heroBody'] ?? '').toString(),
      heroImageUrl: (map['heroImageUrl'] ?? '').toString(),
      logoUrl: (map['logoUrl'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      primaryColor: (map['primaryColor'] ?? '#B71C1C').toString(),
      navigation:
          rawNavigation is List
              ? rawNavigation
                  .whereType<Map>()
                  .map(
                    (item) => WebsiteNavigationItem.fromMap(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList()
              : defaults.navigation,
      sections: sections,
    );
  }

  Map<String, dynamic> toMap() => {
    'schoolName': schoolName.trim(),
    'tagline': tagline.trim(),
    'heroTitle': heroTitle.trim(),
    'heroBody': heroBody.trim(),
    'heroImageUrl': heroImageUrl.trim(),
    'logoUrl': logoUrl.trim(),
    'phone': phone.trim(),
    'email': email.trim(),
    'address': address.trim(),
    'primaryColor': primaryColor.trim(),
    'navigation': navigation.map((item) => item.toMap()).toList(),
    'sections': sections.map((section) => section.toMap()).toList(),
  };

  static const defaults = WebsiteContent(
    schoolName: 'Liceo Bilingüe Rodolfo Llinás',
    tagline: 'Educamos hoy para liderar mañana',
    heroTitle: 'Formamos estudiantes con valores y pasión por aprender',
    heroBody:
        'Educación bilingüe integral en un ambiente seguro e inclusivo, que fortalece el desarrollo académico, social y emocional.',
    heroImageUrl:
        'asset:assets/pagina_inicio/WhatsApp Image 2026-06-26 at 12.16.23 PM.jpeg',
    logoUrl: 'asset:assets/logo_fondo.png',
    phone: '',
    email: '',
    address:
        'Barrio Tablanca, autopista Floridablanca–Piedecuesta, retorno La Españolita, Piedecuesta, Santander.',
    primaryColor: '#B71C1C',
    navigation: [
      WebsiteNavigationItem(id: 'about', label: 'About'),
      WebsiteNavigationItem(id: 'admissions', label: 'Admissions'),
      WebsiteNavigationItem(id: 'learning', label: 'Learning'),
      WebsiteNavigationItem(id: 'news', label: 'News & Events'),
      WebsiteNavigationItem(id: 'parents', label: 'Parents'),
    ],
    sections: [
      WebsiteSection(
        id: 'identidad',
        title: 'Sobre nuestro colegio',
        body:
            'Somos un colegio bilingüe con sedes en Barrancabermeja y Piedecuesta. Ofrecemos educación desde preescolar hasta grado 11, con grupos reducidos y un enfoque personalizado en ciencias, investigación y aprendizaje práctico.',
        imageUrl:
            'asset:assets/pagina_inicio/WhatsApp Image 2026-06-26 at 12.16.20 PM.jpeg',
        pageId: 'about',
      ),
      WebsiteSection(
        id: 'experiencias',
        title: 'Nuestra misión',
        body:
            'Formamos estudiantes con una sólida base académica, valores, conciencia ambiental y responsabilidad social. Desde grado 9 ofrecemos un programa internacional de doble titulación en alianza con una institución educativa de Wisconsin, Estados Unidos.',
        imageUrl:
            'asset:assets/pagina_inicio/WhatsApp Image 2026-06-26 at 12.16.21 PM.jpeg',
        pageId: 'about',
        imagePosition: 'right',
      ),
      WebsiteSection(
        id: 'vision',
        title: 'Nuestra visión',
        body:
            'Ser una institución líder, reconocida por su excelencia académica, innovación y formación de ciudadanos globales con sólidos valores y habilidades bilingües.',
        imageUrl:
            'asset:assets/pagina_inicio/WhatsApp Image 2026-06-26 at 12.16.20 PM (1).jpeg',
        pageId: 'about',
      ),
      WebsiteSection(
        id: 'calidad',
        title: 'Política de calidad',
        body:
            'Nos comprometemos a brindar servicios educativos de alta calidad, mejorar continuamente nuestros procesos, fortalecer nuestro equipo y garantizar la satisfacción de la comunidad educativa.',
        imageUrl:
            'asset:assets/pagina_inicio/WhatsApp Image 2026-06-26 at 12.16.23 PM (1).jpeg',
        pageId: 'about',
        imagePosition: 'right',
      ),
      WebsiteSection(
        id: 'admissions',
        title: 'Admisiones',
        body:
            'Conoce nuestra propuesta educativa y da el primer paso para formar parte de una comunidad bilingüe, cercana e innovadora.',
        imageUrl:
            'asset:assets/pagina_inicio/WhatsApp Image 2026-06-26 at 12.16.20 PM (2).jpeg',
        buttonLabel: 'Formulario de inscripción',
        buttonUrl: '/enrollment_public',
        pageId: 'admissions',
        imagePosition: 'background',
        textAlignment: 'center',
        textColor: '#FFFFFF',
      ),
      WebsiteSection(
        id: 'learning',
        title: 'Aprendizaje que transforma',
        body:
            'Fortalecemos el bilingüismo, las ciencias, la investigación, el pensamiento crítico y el aprendizaje práctico para preparar ciudadanos globales.',
        imageUrl:
            'asset:assets/pagina_inicio/WhatsApp Image 2026-06-26 at 12.16.20 PM (3).jpeg',
        pageId: 'learning',
        imagePosition: 'top',
        textAlignment: 'center',
      ),
      WebsiteSection(
        id: 'news',
        title: 'Noticias y eventos',
        body:
            'Compartimos experiencias académicas, culturales, deportivas y artísticas que hacen parte de la vida de nuestra comunidad educativa.',
        imageUrl:
            'asset:assets/pagina_inicio/WhatsApp Image 2026-06-26 at 12.16.21 PM (1).jpeg',
        pageId: 'news',
        imagePosition: 'right',
      ),
      WebsiteSection(
        id: 'parents',
        title: 'Familias que acompañan',
        body:
            'Las familias son parte esencial del proceso formativo. Desde el sistema educativo pueden consultar y gestionar la información académica de sus estudiantes.',
        imageUrl:
            'asset:assets/pagina_inicio/WhatsApp Image 2026-06-26 at 12.16.22 PM (5).jpeg',
        buttonLabel: 'Ingresar al sistema',
        buttonUrl: '/login',
        pageId: 'parents',
      ),
    ],
  );
}
