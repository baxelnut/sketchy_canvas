import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sketchy_canvas/canvas.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: TextTheme(
          titleMedium: GoogleFonts.quicksand(
            textStyle:
                const TextStyle(fontSize: 22.0, fontWeight: FontWeight.w500),
          ),
          bodyMedium: GoogleFonts.quicksand(
            textStyle: const TextStyle(fontSize: 16.0),
          ),
          bodyLarge: GoogleFonts.quicksand(
              textStyle: const TextStyle(fontSize: 16.0),
              fontWeight: FontWeight.w600),
          labelMedium: GoogleFonts.quicksand(
              textStyle: const TextStyle(fontSize: 16.0),
              fontWeight: FontWeight.w600,
              color: const Color(0xff9A22A5)),
        ),
        useMaterial3: true,
      ),
      home: const Canvas(),
    );
  }
}
