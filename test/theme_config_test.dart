import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/config/theme_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la cabecera y las pestañas conservan contraste institucional', () {
    ThemeProvider.usarConfiguracionPredeterminada();
    final theme = ThemeProvider.themeData;
    final colors = theme.colorScheme;

    expect(theme.appBarTheme.backgroundColor, colors.surface);
    expect(theme.appBarTheme.foregroundColor, colors.primary);
    expect(theme.appBarTheme.centerTitle, isTrue);
    expect(theme.tabBarTheme.labelColor, colors.primary);
    expect(theme.tabBarTheme.unselectedLabelColor, colors.onSurfaceVariant);
    expect(
      theme.tabBarTheme.labelColor,
      isNot(theme.tabBarTheme.unselectedLabelColor),
    );
  });
}
