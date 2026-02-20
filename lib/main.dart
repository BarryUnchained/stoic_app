import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 必须直接导入 supabase 插件
import 'quote_screen.dart';

void main() async {
  // 1. 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. 彻底初始化 Supabase，这是防止白屏的关键地基
  await Supabase.initialize(
    url: 'https://asbzdkewvpixrvfeldwb.supabase.co',
    anonKey: 'sb_publishable_DRkIY58m0eK9B7-_smWxrA_FefcshnA',
  );
  
  // 3. 启动应用
  runApp(const StoicApp());
}

class StoicApp extends StatelessWidget {
  const StoicApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '每日斯多葛智慧 | Stoic Wisdom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        textTheme: GoogleFonts.loraTextTheme(ThemeData.light().textTheme),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: GoogleFonts.loraTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
    
    // 启动页停留 2 秒后跳转至主引擎
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const QuoteScreen(),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() { 
    _controller.dispose(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_stories_outlined, size: 64, color: isDark ? Colors.white38 : Colors.grey),
              const SizedBox(height: 20),
              Text('STOIC WISDOM', style: GoogleFonts.lora(fontSize: 28, fontWeight: FontWeight.w300, letterSpacing: 4, color: isDark ? Colors.white54 : const Color(0xFF2C2C2C))),
              const SizedBox(height: 8),
              Text('每日斯多葛智慧', style: TextStyle(fontSize: 14, color: isDark ? Colors.white30 : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}