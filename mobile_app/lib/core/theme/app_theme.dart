import 'package:flutter/material.dart';

class AppTheme {
  /// Brand "Cin Cin": notte calda, spritz, lampone e limone.
  /// Il tema è scuro: i widget che distinguono chiaro/scuro leggono questo flag.
  static const bool isDarkPalette = true;

  static const String displayFont = 'BricolageGrotesque';
  static const String textFont = 'Figtree';

  // Palette Cin Cin
  static const notte = Color(0xFF1B1124);
  static const velluto = Color(0xFF2A1C36);
  static const vellutoChiaro = Color(0xFF3A2949);
  static const bordo = Color(0xFF4A3A5A);
  static const spritz = Color(0xFFFF6A2B);
  static const lampone = Color(0xFFFF4D8D);

  /// Lampone scuro: fondo dei messaggi inviati, regge il testo bianco.
  static const lamponeScuro = Color(0xFF6E2346);
  static const limone = Color(0xFFFFE04A);
  static const menta = Color(0xFF3DDC97);
  static const lilla = Color(0xFFB79CFF);
  static const panna = Color(0xFFFFF4EA);
  static const lavandaChiara = Color(0xFFD9CCE3);
  static const lavanda = Color(0xFFA898B6);

  /// Testo e icone sopra Spritz, Lampone, Limone, Menta e Panna.
  static const onAccent = notte;

  // Nomi storici usati in tutta l'app, rimappati sulla palette Cin Cin.
  static const cream = notte;
  static const paper = velluto;
  static const sand = vellutoChiaro;
  static const peach = bordo;
  static const orange = spritz;
  static const brown = lavandaChiara;
  static const espresso = panna;
  static const sage = limone;
  static const mist = Color(0xFF231730);
  static const cardBorder = bordo;
  static const moss = menta;
  static const gold = limone;
  static const berry = lilla;
  static const plum = lampone;
  static const vividViolet = lampone;
  static const offerGreen = menta;
  static const shadow = Color(0x40000000);

  static const heroGradient = LinearGradient(
    colors: [velluto, Color(0xFF331F42)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradient = LinearGradient(
    colors: [spritz, lampone],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const surfaceGradient = LinearGradient(
    colors: [velluto, velluto],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const elevatedSurfaceGradient = LinearGradient(
    colors: [Color(0xFF2F1F3C), velluto],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const softAccentGradient = LinearGradient(
    colors: [vellutoChiaro, Color(0xFF33243F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static String _normalizeMeal(String tipoPasto) =>
      tipoPasto.trim().toLowerCase();

  /// Colore di ogni momento: colazione limone, aperitivo spritz,
  /// pranzo menta, cena lilla.
  static Color mealColor(String tipoPasto) {
    switch (_normalizeMeal(tipoPasto)) {
      case 'colazione':
        return limone;
      case 'ape':
      case 'aperitivo':
        return spritz;
      case 'pranzo':
        return menta;
      case 'cena':
        return lilla;
      default:
        return lampone;
    }
  }

  static IconData mealIcon(String tipoPasto) {
    switch (_normalizeMeal(tipoPasto)) {
      case 'colazione':
        return Icons.free_breakfast_rounded;
      case 'ape':
      case 'aperitivo':
        return Icons.local_bar_rounded;
      case 'pranzo':
        return Icons.restaurant_rounded;
      case 'cena':
        return Icons.nights_stay_rounded;
      default:
        return Icons.local_dining_rounded;
    }
  }

  static String mealLabel(String tipoPasto) {
    switch (_normalizeMeal(tipoPasto)) {
      case 'colazione':
        return 'Colazione';
      case 'ape':
      case 'aperitivo':
        return 'Aperitivo';
      case 'pranzo':
        return 'Pranzo';
      case 'cena':
        return 'Cena';
      default:
        return tipoPasto;
    }
  }

  static ThemeData theme() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: spritz,
      onPrimary: onAccent,
      primaryContainer: Color(0xFF4A2418),
      onPrimaryContainer: panna,
      secondary: lampone,
      onSecondary: onAccent,
      secondaryContainer: Color(0xFF4A1F33),
      onSecondaryContainer: panna,
      tertiary: limone,
      onTertiary: onAccent,
      error: Color(0xFFFF6B6B),
      onError: onAccent,
      surface: velluto,
      onSurface: panna,
      onSurfaceVariant: lavandaChiara,
      surfaceContainerLowest: notte,
      surfaceContainerLow: mist,
      surfaceContainer: velluto,
      surfaceContainerHigh: vellutoChiaro,
      surfaceContainerHighest: Color(0xFF443356),
      outline: bordo,
      outlineVariant: vellutoChiaro,
      inverseSurface: panna,
      onInverseSurface: notte,
      inversePrimary: Color(0xFFB8400F),
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );

    const textTheme = TextTheme(
      displaySmall: TextStyle(
        fontFamily: displayFont,
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -1.2,
        color: panna,
      ),
      headlineLarge: TextStyle(
        fontFamily: displayFont,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.02,
        letterSpacing: -0.9,
        color: panna,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFont,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -0.7,
        color: panna,
      ),
      headlineSmall: TextStyle(
        fontFamily: displayFont,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.4,
        color: panna,
      ),
      titleLarge: TextStyle(
        fontFamily: displayFont,
        fontSize: 21,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.3,
        color: panna,
      ),
      titleMedium: TextStyle(
        fontFamily: textFont,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: panna,
      ),
      titleSmall: TextStyle(
        fontFamily: textFont,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: panna,
      ),
      bodyLarge: TextStyle(
        fontFamily: textFont,
        color: lavandaChiara,
        fontSize: 16,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        fontFamily: textFont,
        color: lavandaChiara,
        fontSize: 14,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontFamily: textFont,
        color: lavanda,
        fontSize: 12.5,
        height: 1.35,
      ),
      labelLarge: TextStyle(
        fontFamily: textFont,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
      labelMedium: TextStyle(
        fontFamily: textFont,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: TextStyle(
        fontFamily: textFont,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: textFont,
      textTheme: textTheme,
      scaffoldBackgroundColor: notte,
      canvasColor: notte,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: panna,
        elevation: 0,
        toolbarHeight: 72,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: displayFont,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: panna,
        ),
      ),
      cardTheme: CardThemeData(
        color: velluto,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        surfaceTintColor: Colors.transparent,
        shadowColor: shadow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: velluto,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: const TextStyle(color: lavanda),
        labelStyle: const TextStyle(color: lavandaChiara),
        floatingLabelStyle: const TextStyle(
          color: limone,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: lavanda,
        suffixIconColor: lavanda,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: bordo),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: spritz, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: spritz,
          foregroundColor: onAccent,
          disabledBackgroundColor: vellutoChiaro,
          disabledForegroundColor: lavanda,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: textFont,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: panna,
          side: BorderSide(color: panna.withValues(alpha: 0.6), width: 1.5),
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: textFont,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: limone,
          textStyle: const TextStyle(
            fontFamily: textFont,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: vellutoChiaro,
          foregroundColor: panna,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: textFont,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: spritz,
        foregroundColor: onAccent,
        elevation: 0,
        shape: StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: velluto,
        indicatorColor: panna,
        indicatorShape: const StadiumBorder(),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? notte : lavanda);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: textFont,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            color: selected ? panna : lavanda,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panna,
        contentTextStyle: const TextStyle(
          fontFamily: textFont,
          color: notte,
          fontWeight: FontWeight.w700,
        ),
        actionTextColor: const Color(0xFFB8400F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: vellutoChiaro,
        selectedColor: panna,
        disabledColor: velluto,
        secondarySelectedColor: panna,
        checkmarkColor: notte,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        labelStyle: TextStyle(
          fontFamily: textFont,
          color: panna,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: textFont,
          color: notte,
          fontWeight: FontWeight.w800,
        ),
        brightness: Brightness.dark,
        side: BorderSide(color: bordo),
        shape: StadiumBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: velluto,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: displayFont,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: panna,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: textFont,
          fontSize: 15,
          height: 1.45,
          color: lavandaChiara,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: velluto,
        modalBackgroundColor: velluto,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: bordo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: vellutoChiaro,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
          fontFamily: textFont,
          color: panna,
          fontWeight: FontWeight.w600,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: lavandaChiara,
        textColor: panna,
      ),
      dividerTheme: const DividerThemeData(
        color: bordo,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: spritz,
        linearTrackColor: vellutoChiaro,
        circularTrackColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: spritz,
        inactiveTrackColor: bordo,
        thumbColor: spritz,
        overlayColor: spritz.withValues(alpha: 0.16),
        valueIndicatorColor: spritz,
        valueIndicatorTextStyle: const TextStyle(
          fontFamily: textFont,
          color: onAccent,
          fontWeight: FontWeight.w800,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected) ? notte : lavanda;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected) ? limone : vellutoChiaro;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? Colors.transparent
              : bordo;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? spritz
              : Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll<Color>(onAccent),
        side: const BorderSide(color: lavanda, width: 1.6),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected) ? spritz : lavanda;
        }),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: spritz,
        selectionColor: spritz.withValues(alpha: 0.35),
        selectionHandleColor: spritz,
      ),
    );
  }
}
