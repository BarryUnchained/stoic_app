import 'auth.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'quote_screen.dart';

void main() async {
  // 1. 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. 加载环境变量 ← 新增
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print('⚠️ 警告: .env 文件加载失败: $e');
  }
  
  // 3. 初始化 Supabase（使用环境变量）← 改进
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? 'https://asbzdkewvpixrvfeldwb.supabase.co',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? 'sb_publishable_DRkIY58m0eK9B7-_smWxrA_FefcshnA',
    );
    print('✅ Supabase 初始化成功');
  } catch (e) {
    print('❌ Supabase 初始化失败: $e');
    runApp(const InitializationErrorApp());
    return;
  }
  
  // 4. 启动应用
  runApp(const StoicApp());
}

// 初始化失败时显示错误页 ← 新增
class InitializationErrorApp extends StatelessWidget {
  const InitializationErrorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('初始化失败'),
              const SizedBox(height: 8),
              const Text('请检查 .env 文件配置', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // 重启应用
                  main();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoicApp extends StatelessWidget {
  const StoicApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '每日斯多葛智慧 | Stoic Wisdom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C4033), // ← 优化: 使用棕色，符合Stoic气质
          brightness: Brightness.light
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
textTheme: ThemeData.light().textTheme,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B7355), // ← 优化: 浅棕色
          brightness: Brightness.dark
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
textTheme: ThemeData.dark().textTheme,
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
    
    // ← 改进: 智能等待，而不是固定延迟
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final startTime = DateTime.now();
      
      // 检查用户登录状态
      final user = Supabase.instance.client.auth.currentUser;
      
      // 确保至少显示1.5秒启动页（品牌展示）
      final elapsed = DateTime.now().difference(startTime);
      final remaining = const Duration(milliseconds: 1500) - elapsed;
      
      if (remaining.isNegative == false) {
        await Future.delayed(remaining);
      }
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => user != null 
              ? const QuoteScreen()
              : const LoginScreen(), // ← 改进: 未登录用户跳转到登录页
            transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (r) => false,
        );
      }
    } catch (e) {
      print('启动初始化错误: $e');
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const QuoteScreen()),
          (r) => false,
        );
      }
    }
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
Text('STOIC WISDOM', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, letterSpacing: 4, color: isDark ? Colors.white54 : const Color(0xFF2C2C2C))),
              const SizedBox(height: 8),
              Text('每日斯多葛智慧', style: TextStyle(fontSize: 14, color: isDark ? Colors.white30 : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}