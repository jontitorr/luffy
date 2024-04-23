import "package:flutter/material.dart";
import "package:flutter/services.dart";

ThemeData lightTheme({
  required Color primaryColor,
}) {
  return ThemeData(
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
      iconTheme: IconThemeData(
        color: Colors.white,
      ),
    ),
    canvasColor: const Color.fromARGB(255, 242, 242, 242),
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: const Color.fromARGB(255, 28, 28, 30),
      secondary: primaryColor,
      onSecondary: const Color.fromARGB(255, 28, 28, 30),
      error: const Color.fromARGB(255, 255, 59, 48),
      onError: const Color.fromARGB(255, 28, 28, 30),
      background: const Color.fromARGB(255, 242, 242, 242),
      onBackground: const Color.fromARGB(255, 28, 28, 30),
      surface: const Color.fromARGB(255, 255, 255, 255),
      onSurface: const Color.fromARGB(255, 28, 28, 30),
    ),
    dialogTheme: const DialogTheme(
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      titleTextStyle: TextStyle(
        color: Color.fromARGB(255, 28, 28, 30),
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: TextStyle(
        color: Color.fromARGB(255, 28, 28, 30),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primaryColor,
    ),
    tabBarTheme: TabBarTheme(
      indicatorColor: primaryColor,
      labelColor: const Color.fromARGB(255, 28, 28, 30),
      unselectedLabelColor: const Color.fromARGB(255, 28, 28, 30),
    ),
    // textTheme: const TextTheme(
    //   bodySmall: TextStyle(),
    //   bodyMedium: TextStyle(),
    //   bodyLarge: TextStyle(),
    //   labelSmall: TextStyle(),
    //   labelMedium: TextStyle(),
    //   labelLarge: TextStyle(),
    //   titleSmall: TextStyle(),
    //   titleMedium: TextStyle(),
    //   titleLarge: TextStyle(),
    // ).apply(
    //   bodyColor: Colors.white,
    //   displayColor: Colors.white,
    // ),
  );
}

ThemeData darkTheme({
  required Color primaryColor,
}) {
  return ThemeData(
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    ),
    canvasColor: const Color.fromARGB(255, 1, 1, 1),
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: primaryColor,
      onPrimary: const Color.fromARGB(255, 229, 229, 231),
      secondary: primaryColor,
      onSecondary: const Color.fromARGB(255, 229, 229, 231),
      error: const Color.fromARGB(255, 255, 69, 58),
      onError: const Color.fromARGB(255, 229, 229, 231),
      background: const Color.fromARGB(255, 1, 1, 1),
      onBackground: const Color.fromARGB(255, 229, 229, 231),
      surface: const Color.fromARGB(255, 18, 18, 18),
      onSurface: const Color.fromARGB(255, 229, 229, 231),
    ),
    dialogTheme: const DialogTheme(
      backgroundColor: Color.fromARGB(255, 18, 18, 18),
      titleTextStyle: TextStyle(
        color: Color.fromARGB(255, 229, 229, 231),
      ),
      contentTextStyle: TextStyle(
        color: Color.fromARGB(255, 229, 229, 231),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primaryColor,
    ),
    tabBarTheme: TabBarTheme(
      indicatorColor: primaryColor,
      labelColor: const Color.fromARGB(255, 229, 229, 231),
      unselectedLabelColor: Colors.white54,
    ),
  );
}
