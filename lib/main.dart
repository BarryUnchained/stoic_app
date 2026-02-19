import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://asbzdkewvpixrvfeldwb.supabase.co',
    anonKey: 'sb_publishable_DRkIY58m0eK9B7-_smWxrA_FefcshnA',
  );
  runApp(const StoicApp());
}

// 名言数据模型
class Quote {
  final String english;
  final String chinese;
  final String author;

  const Quote({
    required this.english,
    required this.chinese,
    required this.author,
  });
}

class StoicApp extends StatelessWidget {
  const StoicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stoic Wisdom',
      debugShowCheckedModeBanner: false,
      // 浅色主题 (保留你原来的质感)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        useMaterial3: true,
      ),
      // 深色主题 (新加入的灵魂)
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      // 自动跟随系统颜色
      themeMode: ThemeMode.system,
      home: const QuoteScreen(),
    );
  }
}

class QuoteScreen extends StatefulWidget {
  const QuoteScreen({super.key});

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  final Random _random = Random();

  List<Quote> _quotes = [];
  Quote? _currentQuote;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuotes();
  }

  Future<void> _fetchQuotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await Supabase.instance.client.from('quotes').select();

      final List<Quote> fetched = (data as List<dynamic>)
          .map(
            (row) => Quote(
              english: row['english'] as String? ?? '',
              chinese: row['chinese'] as String? ?? '',
              author: row['author'] as String? ?? '',
            ),
          )
          .toList();

      setState(() {
        if (fetched.isNotEmpty) {
          _quotes = fetched;
          _currentQuote = _quotes[_random.nextInt(_quotes.length)];
        } else {
          // 防白板：如果数据库连上了，但是表里没数据
          _currentQuote = const Quote(
            english: "Database connected, but no quotes found.",
            chinese: "云端连接成功，但数据库里还没有名言，请去后台添加。",
            author: "System",
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      // 防白板：如果发生网络错误或权限错误，直接显示在屏幕上
      print('🔴 报错信息: $e');
      setState(() {
        _currentQuote = Quote(
          english: "Oops! Connection failed.",
          chinese: "连接云端失败！\n错误原因：$e",
          author: "Error",
        );
        _isLoading = false;
      });
    }
  }

  void _refreshQuote() {
    if (_quotes.isEmpty || _currentQuote == null) return;

    setState(() {
      // 确保随机选择的名言与当前不同
      Quote newQuote;
      do {
        newQuote = _quotes[_random.nextInt(_quotes.length)];
      } while (newQuote == _currentQuote && _quotes.length > 1);
      _currentQuote = newQuote;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 智能检测当前是否为深色模式，以调整文字和组件颜色
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final primaryTextColor = isDark ? Colors.white70 : const Color(0xFF2C2C2C);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF5A5A5A);
    final authorTextColor = isDark ? Colors.white38 : const Color(0xFF6B6B6B);
    final bottomBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 主要内容区域 - 占据剩余空间
            Expanded(
              child: Center(
                child: _isLoading
                    ? CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? Colors.white54 : const Color(0xFF4A4A4A),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 英文名言
                            Text(
                              _currentQuote?.english ?? '',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w300,
                                height: 1.5,
                                letterSpacing: 0.5,
                                color: primaryTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            // 中文翻译
                            Text(
                              _currentQuote?.chinese ?? '',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                                height: 1.6,
                                letterSpacing: 0.3,
                                color: secondaryTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            // 作者名称
                            Text(
                              _currentQuote?.author ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: authorTextColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            // 底部操作栏
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 32.0),
              decoration: BoxDecoration(
                color: bottomBarColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 刷新按钮 (现在真正有用啦！)
                  _ActionButton(
                    icon: Icons.casino_outlined,
                    label: '刷新',
                    onTap: _refreshQuote,
                    isDark: isDark,
                  ),
                  // 收藏按钮
                  _ActionButton(
                    icon: Icons.favorite_outline,
                    label: '收藏',
                    onTap: () {},
                    isDark: isDark,
                  ),
                  // 笔记按钮
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    label: '笔记',
                    onTap: () {},
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF4A4A4A);
    final labelColor = isDark ? Colors.white54 : const Color(0xFF6B6B6B);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: labelColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}