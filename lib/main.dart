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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        useMaterial3: true,
      ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // 主要内容区域 - 占据剩余空间
            Expanded(
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF4A4A4A),
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
                              style: const TextStyle(
                                fontSize: 24, // 稍微调小一点字体以适应可能出现的报错信息
                                fontWeight: FontWeight.w300,
                                height: 1.5,
                                letterSpacing: 0.5,
                                color: Color(0xFF2C2C2C),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            // 中文翻译
                            Text(
                              _currentQuote?.chinese ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                                height: 1.6,
                                letterSpacing: 0.3,
                                color: Color(0xFF5A5A5A),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            // 作者名称
                            Text(
                              _currentQuote?.author ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B6B6B),
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
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 刷新按钮
                  _ActionButton(
                    icon: Icons.casino_outlined,
                    label: '刷新',
                    onTap: _refreshQuote,
                  ),
                  // 收藏按钮
                  _ActionButton(
                    icon: Icons.favorite_outline,
                    label: '收藏',
                    onTap: () {},
                  ),
                  // 笔记按钮
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    label: '笔记',
                    onTap: () {},
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

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: const Color(0xFF4A4A4A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B6B6B),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}