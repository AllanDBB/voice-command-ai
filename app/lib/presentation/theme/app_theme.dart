// Presentation — centralized design tokens
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const kBg      = Color(0xFF070C18);   // deep space
const kSurface = Color(0xFF0D1325);   // card surface
const kBorder  = Color(0xFF1B2540);   // default stroke
const kCyan    = Color(0xFF00CFFF);   // focus / active
const kCyanDim = Color(0xFF002D3D);   // focused card tint
const kAmber   = Color(0xFFFFAD33);   // ON state
const kCoral   = Color(0xFFFF4D6A);   // OFF / cancel
const kGreen   = Color(0xFF00E09A);   // running / confirmed
const kText    = Color(0xFFDDE4F0);   // primary text
const kTextDim = Color(0xFF556080);   // secondary text

// ── Typography ────────────────────────────────────────────────────────────────
TextStyle kDisplay(double size, {FontWeight weight = FontWeight.w700}) =>
    GoogleFonts.rajdhani(fontSize: size, fontWeight: weight, color: kText, letterSpacing: 1.2);

TextStyle kLabel(double size, {Color color = kText}) =>
    GoogleFonts.outfit(fontSize: size, color: color, letterSpacing: 0.3);

TextStyle kMono(double size, {Color color = kCyan}) =>
    GoogleFonts.shareTechMono(fontSize: size, color: color);

// ── Theme ─────────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  colorScheme: const ColorScheme.dark(
    surface: kSurface,
    primary: kCyan,
    secondary: kAmber,
    error: kCoral,
  ),
  useMaterial3: true,
  textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
  appBarTheme: AppBarTheme(
    backgroundColor: kBg,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: kDisplay(20),
    iconTheme: const IconThemeData(color: kCyan),
    surfaceTintColor: Colors.transparent,
  ),
);
