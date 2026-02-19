import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://asbzdkewvpixrvfeldwb.supabase.co',
    anonKey: 'sb_publishable_DRkIY58m0eK9B7-_smWxrA_FefcshnA',
  );
  runApp(const StoicApp());
}

final supabase = Supabase.instance.client;

// ============================================================
// 数据模型
// ============================================================

class Quote {
  final int id;
  final String english;
  final String chinese;
  final String author;

  const Quote({
    required this.id,
    required this.english,
    required this.chinese,
    required this.author,
  });
}

// ============================================================
// App 入口
// ============================================================

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
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      // 直接将主页设为名言页，支持游客模式
      home: const QuoteScreen(),
    );
  }
}

// ============================================================
// 登录 / 注册页面
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = '请输入邮箱和密码');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = '密码至少 6 位');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        await supabase.auth.signUp(email: email, password: password);
      } else {
        await supabase.auth.signInWithPassword(email: email, password: password);
      }

      if (mounted) {
        // 登录成功后，清空路由栈并回到主页
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const QuoteScreen()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = '出错了：$e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white70 : const Color(0xFF2C2C2C);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF5A5A5A);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inputFillColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // 增加透明导航栏，方便游客点左上角返回
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryTextColor),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 48,
                  color: secondaryTextColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Stoic Wisdom',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: primaryTextColor,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '每日一句斯多葛智慧',
                  style: TextStyle(fontSize: 14, color: secondaryTextColor),
                ),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isSignUp ? '创建账户' : '欢迎回来',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: primaryTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: primaryTextColor),
                        decoration: InputDecoration(
                          hintText: '邮箱',
                          hintStyle: TextStyle(color: secondaryTextColor),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(color: primaryTextColor),
                        decoration: InputDecoration(
                          hintText: '密码',
                          hintStyle: TextStyle(color: secondaryTextColor),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onSubmitted: (_) => _handleAuth(),
                      ),
                      const SizedBox(height: 16),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white12 : const Color(0xFF2C2C2C),
                            foregroundColor: isDark ? Colors.white70 : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  _isSignUp ? '注册' : '登录',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _errorMessage = null;
                          });
                        },
                        child: Text(
                          _isSignUp ? '已有账户？点此登录' : '没有账户？点此注册',
                          style: TextStyle(color: secondaryTextColor, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 名言主页面（含收藏与游客模式逻辑）
// ============================================================

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

  Set<int> _favoriteQuoteIds = {};
  bool _isFavoriting = false;

  @override
  void initState() {
    super.initState();
    _fetchQuotes();
    _fetchFavorites();
  }

  Future<void> _fetchQuotes() async {
    setState(() => _isLoading = true);

    try {
      final data = await supabase.from('quotes').select();
      final List<Quote> fetched = (data as List<dynamic>)
          .map((row) => Quote(
                id: row['id'] as int,
                english: row['english'] as String? ?? '',
                chinese: row['chinese'] as String? ?? '',
                author: row['author'] as String? ?? '',
              ))
          .toList();

      setState(() {
        if (fetched.isNotEmpty) {
          _quotes = fetched;
        } else {
          _currentQuote = const Quote(
            id: 0,
            english: "Database connected, but no quotes found.",
            chinese: "云端连接成功，但数据库里还没有名言，请去后台添加。",
            author: "System",
          );
        }
      });
      
      // 执行分配逻辑并记录本地浏览次数
      await _assignRandomQuote(isInitialLoad: true);

    } catch (e) {
      print('🔴 报错信息: $e');
      setState(() {
        _currentQuote = Quote(
          id: 0,
          english: "Oops! Connection failed.",
          chinese: "连接云端失败！\n错误原因：$e",
          author: "Error",
        );
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 核心计次分配逻辑
  Future<void> _assignRandomQuote({required bool isInitialLoad}) async {
    if (_quotes.isEmpty) return;

    final user = supabase.auth.currentUser;
    if (user != null) {
      // 已登录，无限制刷新
      _pickNewQuote();
      return;
    }

    // 游客模式，检查本地存储限额
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    
    String? lastDate = prefs.getString('last_view_date');
    int viewCount = prefs.getInt('view_count') ?? 0;

    if (lastDate != today) {
      // 新的一天，重置限额
      await prefs.setString('last_view_date', today);
      await prefs.setInt('view_count', 1);
      _pickNewQuote();
    } else {
      if (viewCount < 10) {
        // 额度充足
        await prefs.setInt('view_count', viewCount + 1);
        _pickNewQuote();
      } else {
        // 额度超限
        if (isInitialLoad) {
          // 首次加载应用，仍然显示一句，但随后弹出拦截框
          _pickNewQuote();
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showRegistrationHook(context);
            });
          }
        } else {
          // 点击刷新按钮时触发，拦截并直接弹窗，不切换名言
          _showRegistrationHook(context);
        }
      }
    }
  }

  void _pickNewQuote() {
    if (_quotes.isEmpty) return;
    Quote newQuote;
    if (_quotes.length <= 1) {
      setState(() => _currentQuote = _quotes.first);
      return;
    }
    do {
      newQuote = _quotes[_random.nextInt(_quotes.length)];
    } while (_currentQuote != null && newQuote.id == _currentQuote!.id);
    setState(() => _currentQuote = newQuote);
  }

  Future<void> _fetchFavorites() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase.from('favorites').select('quote_id').eq('user_id', userId);
      setState(() {
        _favoriteQuoteIds = (data as List<dynamic>).map((row) => row['quote_id'] as int).toSet();
      });
    } catch (e) {
      print('🔴 拉取收藏失败: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentQuote == null || _currentQuote!.id == 0 || _isFavoriting) return;

    final user = supabase.auth.currentUser;
    // 如果游客试图收藏，弹出引诱注册框
    if (user == null) {
      _showRegistrationHook(context, isFromFavorite: true);
      return;
    }

    final quoteId = _currentQuote!.id;
    final isFavorited = _favoriteQuoteIds.contains(quoteId);

    setState(() => _isFavoriting = true);

    try {
      if (isFavorited) {
        await supabase.from('favorites').delete().eq('user_id', user.id).eq('quote_id', quoteId);
        setState(() => _favoriteQuoteIds.remove(quoteId));
      } else {
        await supabase.from('favorites').insert({'user_id': user.id, 'quote_id': quoteId});
        setState(() => _favoriteQuoteIds.add(quoteId));
      }
    } catch (e) {
      print('🔴 收藏操作失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isFavoriting = false);
      }
    }
  }

  // 弹窗引导核心逻辑
  void _showRegistrationHook(BuildContext context, {bool isFromFavorite = false}) {
    final title = isFromFavorite ? "注册以永久保存" : "探索更深的智慧";
    final message = isFromFavorite
        ? "登录后，你可以将击中灵魂的名言永久保存在云端，随时跨设备回顾。"
        : "你已完成今日的 10 条免费阅读。注册并加入斯多葛社区，你将解锁：";

    showDialog(
      context: context,
      barrierDismissible: isFromFavorite, // 如果是限制阅读则强制阻挡，收藏点击则可取消
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isFromFavorite) ...[
              const Text("“欲求多者，所得必少。” —— 塞内卡", style: TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
            ],
            Text(message),
            const SizedBox(height: 12),
            const Text("• 300+ 条完整经典名言库"),
            const Text("• 永久收藏并回顾你的感悟"),
            const Text("• 深度评论与其他践行者交流"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isFromFavorite ? "再逛逛" : "明天再来"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text("立即注册 / 登录"),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    // 退出后回到 QuoteScreen 将自动转为游客模式
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const QuoteScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white70 : const Color(0xFF2C2C2C);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF5A5A5A);
    final authorTextColor = isDark ? Colors.white38 : const Color(0xFF6B6B6B);
    final bottomBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final user = supabase.auth.currentUser;
    final isGuest = user == null;
    final bool isCurrentFavorited = _currentQuote != null && _favoriteQuoteIds.contains(_currentQuote!.id);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏：区分游客与已登录状态
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      isGuest ? '未登录 (游客模式)' : user.email ?? '',
                      style: TextStyle(fontSize: 12, color: authorTextColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (isGuest) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      } else {
                        _signOut();
                      }
                    },
                    child: Text(
                      isGuest ? '登录 / 注册' : '退出',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 主要内容区域
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
                  _ActionButton(
                    icon: Icons.casino_outlined,
                    label: '刷新',
                    onTap: () => _assignRandomQuote(isInitialLoad: false),
                    isDark: isDark,
                  ),
                  _ActionButton(
                    icon: isCurrentFavorited ? Icons.favorite : Icons.favorite_outline,
                    label: isCurrentFavorited ? '已收藏' : '收藏',
                    onTap: _toggleFavorite,
                    isDark: isDark,
                    isActive: isCurrentFavorited,
                  ),
                  _ActionButton(
                    icon: Icons.list_outlined,
                    label: '收藏列表',
                    onTap: () {
                      if (isGuest) {
                        _showRegistrationHook(context, isFromFavorite: true);
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FavoritesScreen(allQuotes: _quotes),
                        ),
                      );
                    },
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

// ============================================================
// 收藏列表页面
// ============================================================

class FavoritesScreen extends StatefulWidget {
  final List<Quote> allQuotes;

  const FavoritesScreen({super.key, required this.allQuotes});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Quote> _favoriteQuotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase.from('favorites').select('quote_id').eq('user_id', userId);
      final favoriteIds = (data as List<dynamic>).map((row) => row['quote_id'] as int).toSet();

      setState(() {
        _favoriteQuotes = widget.allQuotes.where((q) => favoriteIds.contains(q.id)).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('🔴 加载收藏列表失败: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white70 : const Color(0xFF2C2C2C);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF5A5A5A);
    final authorTextColor = isDark ? Colors.white38 : const Color(0xFF6B6B6B);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '我的收藏',
          style: TextStyle(fontWeight: FontWeight.w400, color: primaryTextColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryTextColor),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? Colors.white54 : const Color(0xFF4A4A4A),
                ),
              ),
            )
          : _favoriteQuotes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_outline, size: 48, color: authorTextColor),
                      const SizedBox(height: 16),
                      Text('还没有收藏任何名言', style: TextStyle(fontSize: 16, color: secondaryTextColor)),
                      const SizedBox(height: 8),
                      Text('回到首页点击 ❤️ 收藏喜欢的名言', style: TextStyle(fontSize: 14, color: authorTextColor)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favoriteQuotes.length,
                  itemBuilder: (context, index) {
                    final quote = _favoriteQuotes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quote.english,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              height: 1.5,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            quote.chinese,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              height: 1.5,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '— ${quote.author}',
                              style: TextStyle(
                                fontSize: 13,
                                color: authorTextColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ============================================================
// 通用按钮组件
// ============================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool isActive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
    final iconColor = isActive
        ? Colors.redAccent
        : (isDark ? Colors.white70 : const Color(0xFF4A4A4A));
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
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: labelColor, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}