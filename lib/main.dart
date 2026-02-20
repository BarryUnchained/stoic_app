import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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
  const Quote({required this.id, required this.english, required this.chinese, required this.author});

  Map<String, dynamic> toJson() => {'id': id, 'english': english, 'chinese': chinese, 'author': author};
  factory Quote.fromJson(Map<String, dynamic> j) => Quote(id: j['id'], english: j['english'], chinese: j['chinese'], author: j['author']);
}

// ============================================================
// 卡片配色方案
// ============================================================
class CardTheme {
  final List<Color> gradient;
  final String name;
  const CardTheme({required this.gradient, required this.name});
}

const cardThemes = [
  CardTheme(name: '深蓝', gradient: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)]),
  CardTheme(name: '暗红', gradient: [Color(0xFF1a0000), Color(0xFF3d0000), Color(0xFF600000)]),
  CardTheme(name: '墨绿', gradient: [Color(0xFF0a1a0a), Color(0xFF0d2818), Color(0xFF04471C)]),
  CardTheme(name: '纯黑', gradient: [Color(0xFF0a0a0a), Color(0xFF1a1a1a), Color(0xFF2a2a2a)]),
];

// ============================================================
// App 入口
// ============================================================
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

// ============================================================
// #31 Splash 启动页
// ============================================================
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
  void dispose() { _controller.dispose(); super.dispose(); }

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

// ============================================================
// 登录页面
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

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) { setState(() => _errorMessage = '请输入邮箱和密码'); return; }
    if (password.length < 6) { setState(() => _errorMessage = '密码至少 6 位'); return; }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      if (_isSignUp) {
        await supabase.auth.signUp(email: email, password: password);
      } else {
        await supabase.auth.signInWithPassword(email: email, password: password);
      }
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const QuoteScreen()), (r) => false);
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : const Color(0xFF2C2C2C);
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: textColor)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            Icon(Icons.auto_stories_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Stoic Wisdom', style: GoogleFonts.lora(fontSize: 28, fontWeight: FontWeight.w300, color: textColor)),
            const SizedBox(height: 48),
            TextField(controller: _emailController, decoration: const InputDecoration(hintText: '邮箱', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(hintText: '密码（至少6位）', border: OutlineInputBorder()), onSubmitted: (_) => _handleAuth()),
            const SizedBox(height: 20),
            if (_errorMessage != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
            SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _isLoading ? null : _handleAuth, child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isSignUp ? '注册' : '登录'))),
            const SizedBox(height: 12),
            TextButton(onPressed: () => setState(() { _isSignUp = !_isSignUp; _errorMessage = null; }), child: Text(_isSignUp ? '已有账号？去登录' : '没有账号？去注册')),
          ]),
        ),
      ),
    );
  }
}

// ============================================================
// 名言主页面
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
  int _guestViewCount = 0;
  bool _isGeneratingCard = false;
  String? _username;
  Set<int> _viewedIds = {};
  String _selectedAuthor = 'All';
  // #24 心跳动画
  bool _showHeartAnimation = false;

  final List<String> _authors = ['All', 'Marcus Aurelius', 'Seneca', 'Epictetus'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _fetchQuotes();
    await _fetchFavorites();
    await _fetchProfile();
    await _loadViewedIds();
    // #8 首次登录弹昵称
    if (supabase.auth.currentUser != null && (_username == null || _username!.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSetUsernameDialog());
    }
    setState(() => _isLoading = false);
  }

  // #33 离线缓存
  Future<void> _fetchQuotes() async {
    try {
      final data = await supabase.from('quotes').select();
      _quotes = (data as List).map((r) => Quote.fromJson(r)).toList();
      // 缓存到本地
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_quotes', jsonEncode(_quotes.map((q) => q.toJson()).toList()));
    } catch (_) {
      // 离线：从缓存加载
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_quotes');
      if (cached != null) {
        _quotes = (jsonDecode(cached) as List).map((j) => Quote.fromJson(j)).toList();
      }
    }
    if (_quotes.isNotEmpty) _pickDailyQuote();
  }

  Future<void> _fetchFavorites() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase.from('favorites').select('quote_id').eq('user_id', user.id);
      _favoriteQuoteIds = (data as List).map((r) => r['quote_id'] as int).toSet();
    } catch (_) {}
  }

  Future<void> _fetchProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (data != null) _username = data['username'] as String?;
    } catch (_) {}
  }

  // #25 智能刷新：记录已看过的
  Future<void> _loadViewedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('viewed_ids') ?? [];
    _viewedIds = list.map((s) => int.parse(s)).toSet();
  }

  Future<void> _saveViewedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('viewed_ids', _viewedIds.map((i) => i.toString()).toList());
  }

  void _pickDailyQuote() {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final dailyRandom = Random(seed);
    final filtered = _getFilteredQuotes();
    if (filtered.isEmpty) return;
    _currentQuote = filtered[dailyRandom.nextInt(filtered.length)];
    _viewedIds.add(_currentQuote!.id);
    _saveViewedIds();
  }

  // #25 优先未看过的
  void _pickNewQuote() {
    final filtered = _getFilteredQuotes();
    if (filtered.isEmpty) return;
    final unseen = filtered.where((q) => !_viewedIds.contains(q.id)).toList();
    final pool = unseen.isNotEmpty ? unseen : filtered;
    if (unseen.isEmpty) _viewedIds.clear(); // 全部看完，重置

    Quote next;
    do {
      next = pool[_random.nextInt(pool.length)];
    } while (_currentQuote != null && next.id == _currentQuote!.id && pool.length > 1);
    setState(() => _currentQuote = next);
    _viewedIds.add(next.id);
    _saveViewedIds();
  }

  // #26 作者筛选
  List<Quote> _getFilteredQuotes() {
    if (_selectedAuthor == 'All') return _quotes;
    return _quotes.where((q) => q.author == _selectedAuthor).toList();
  }

  Future<void> _assignRandomQuote({required bool isInitialLoad}) async {
    if (_quotes.isEmpty) return;
    if (isInitialLoad) { _pickDailyQuote(); return; }
    final user = supabase.auth.currentUser;
    if (user != null) { _pickNewQuote(); return; }

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    String? lastDate = prefs.getString('last_view_date');
    int viewCount = prefs.getInt('view_count') ?? 0;

    if (lastDate != today) {
      await prefs.setString('last_view_date', today);
      await prefs.setInt('view_count', 1);
      setState(() => _guestViewCount = 1);
      _pickNewQuote();
    } else if (viewCount < 10) {
      await prefs.setInt('view_count', viewCount + 1);
      setState(() => _guestViewCount = viewCount + 1);
      _pickNewQuote();
    } else {
      setState(() => _guestViewCount = 10);
      _showRegistrationHook(context);
    }
  }

  void _copyToClipboard() {
    if (_currentQuote == null) return;
    Clipboard.setData(ClipboardData(text: "${_currentQuote!.english}\n${_currentQuote!.chinese}\n— ${_currentQuote!.author}"));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)));
  }

  // #20 双击收藏 + #24 心跳动画
  void _onDoubleTap() {
    final user = supabase.auth.currentUser;
    if (user == null) { _showRegistrationHook(context, isFromFavorite: true); return; }
    if (_currentQuote == null || _favoriteQuoteIds.contains(_currentQuote!.id)) return;
    _toggleFavorite();
    setState(() => _showHeartAnimation = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeartAnimation = false);
    });
  }

  Future<void> _toggleFavorite() async {
    final user = supabase.auth.currentUser;
    if (user == null) { _showRegistrationHook(context, isFromFavorite: true); return; }
    if (_currentQuote == null || _isFavoriting) return;
    setState(() => _isFavoriting = true);
    try {
      if (_favoriteQuoteIds.contains(_currentQuote!.id)) {
        await supabase.from('favorites').delete().eq('user_id', user.id).eq('quote_id', _currentQuote!.id);
        setState(() => _favoriteQuoteIds.remove(_currentQuote!.id));
      } else {
        await supabase.from('favorites').insert({'user_id': user.id, 'quote_id': _currentQuote!.id});
        setState(() => _favoriteQuoteIds.add(_currentQuote!.id));
      }
    } finally {
      setState(() => _isFavoriting = false);
    }
  }

  // #13 #14 #15 分享卡片
  Future<void> _shareCard({Quote? quote}) async {
    final q = quote ?? _currentQuote;
    if (q == null || _isGeneratingCard) return;
    setState(() => _isGeneratingCard = true);
    try {
      final theme = cardThemes[_random.nextInt(cardThemes.length)];
      final bytes = await _renderCard(q, theme);
      if (bytes != null) {
        final blob = html.Blob([bytes], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)..setAttribute('download', 'stoic_wisdom_${q.id}.png')..click();
        html.Url.revokeObjectUrl(url);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('卡片已下载'), duration: Duration(seconds: 2)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成失败：$e')));
    } finally {
      setState(() => _isGeneratingCard = false);
    }
  }

  Future<List<int>?> _renderCard(Quote q, CardTheme theme) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double w = 1080, h = 1350, p = 80, cw = w - p * 2;

    final bg = Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: theme.gradient).createShader(const Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), bg);

    final line = Paint()..color = const Color(0x33FFFFFF)..strokeWidth = 1;
    canvas.drawLine(const Offset(p, 120), const Offset(w - p, 120), line);

    final eng = _para(q.english, ui.TextStyle(color: const Color(0xFFE0E0E0), fontSize: 42, fontWeight: ui.FontWeight.w300, height: 1.6), cw, ui.TextAlign.center);
    final cn = _para(q.chinese, ui.TextStyle(color: const Color(0x99FFFFFF), fontSize: 34, fontWeight: ui.FontWeight.w300, height: 1.7), cw, ui.TextAlign.center);
    final au = _para('— ${q.author}', ui.TextStyle(color: const Color(0x66FFFFFF), fontSize: 28, fontStyle: ui.FontStyle.italic), cw, ui.TextAlign.center);

    double y = (h - eng.height - 50 - cn.height - 50 - au.height) / 2;
    if (y < 160) y = 160;
    canvas.drawParagraph(eng, Offset(p, y)); y += eng.height + 50;
    canvas.drawParagraph(cn, Offset(p, y)); y += cn.height + 50;
    canvas.drawParagraph(au, Offset(p, y));

    canvas.drawLine(const Offset(p, h - 120), const Offset(w - p, h - 120), line);

    // #15 网址水印
    final wm = _para('STOIC WISDOM  ·  barryunchained.github.io/stoic_app', ui.TextStyle(color: const Color(0x44FFFFFF), fontSize: 18, letterSpacing: 1), cw, ui.TextAlign.center);
    canvas.drawParagraph(wm, Offset(p, h - 90));

    final pic = recorder.endRecording();
    final img = await pic.toImage(w.toInt(), h.toInt());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd?.buffer.asUint8List();
  }

  ui.Paragraph _para(String t, ui.TextStyle s, double w, ui.TextAlign a) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: a, maxLines: 20))..pushStyle(s)..addText(t);
    final p = b.build()..layout(ui.ParagraphConstraints(width: w));
    return p;
  }

  // #8 设置昵称弹窗
 void _showSetUsernameDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SetUsernameScreen(
          onDone: (name) => setState(() => _username = name),
        ),
      ),
    );
  }

  void _showRegistrationHook(BuildContext context, {bool isFromFavorite = false}) {
    showDialog(
      context: context,
      barrierDismissible: isFromFavorite,
      builder: (ctx) => AlertDialog(
        title: Text(isFromFavorite ? '收藏以永久保存' : '今日智慧已达上限'),
        content: const Text('注册登录后，即可解锁 300+ 完整名言库及收藏功能。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('再逛逛')),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); Navigator.push(ctx, MaterialPageRoute(builder: (_) => const LoginScreen())); }, child: const Text('立即登录')),
        ],
      ),
    );
  }

  // #12 退出确认
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('退出后需要重新登录'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              supabase.auth.signOut().then((_) {
                if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const QuoteScreen()));
              });
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  // #28 键盘快捷键
  void _handleKeyPress(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.space) _assignRandomQuote(isInitialLoad: false);
    if (event.logicalKey == LogicalKeyboardKey.keyF) _toggleFavorite();
    if (event.logicalKey == LogicalKeyboardKey.keyS) _shareCard();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = supabase.auth.currentUser;
    final isGuest = user == null;
    final isFav = _currentQuote != null && _favoriteQuoteIds.contains(_currentQuote!.id);
    // #22 今日日期
    final now = DateTime.now();
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final dateStr = '${now.year}年${now.month}月${now.day}日 星期${weekdays[now.weekday - 1]}';
    final displayName = _username ?? (isGuest ? '游客模式' : user.email ?? '');

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKeyPress,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // 顶部栏：#9 #22
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: Text(displayName, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                        Row(children: [
                          if (!isGuest) GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(username: _username, onUpdate: (n) => setState(() => _username = n)))),
                            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.person_outline, size: 18, color: Colors.grey)),
                          ),
                          GestureDetector(
                            onTap: () => isGuest ? Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())) : _confirmSignOut(),
                            child: Text(isGuest ? '登录' : '退出', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.withOpacity(0.6))),
                  ],
                ),
              ),

              // #26 作者筛选
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _authors.map((a) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(a == 'All' ? '全部' : a.split(' ').last, style: const TextStyle(fontSize: 11)),
                      selected: _selectedAuthor == a,
                      onSelected: (_) {
                        setState(() => _selectedAuthor = a);
                        _pickNewQuote();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  )).toList(),
                ),
              ),

              // 主内容：#17 #18 #19 #20 #21
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () async => _assignRandomQuote(isInitialLoad: false),
                        child: GestureDetector(
                          onDoubleTap: _onDoubleTap,
                          onLongPress: _copyToClipboard,
                          onVerticalDragEnd: (d) {
                            if (d.primaryVelocity != null) {
                              if (d.primaryVelocity! < -200 || d.primaryVelocity! > 200) {
                                _assignRandomQuote(isInitialLoad: false);
                              }
                            }
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.65,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                                      child: Padding(
                                        key: ValueKey(_currentQuote?.id),
                                        padding: const EdgeInsets.symmetric(horizontal: 32),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(_currentQuote?.english ?? '', style: GoogleFonts.lora(fontSize: 22, fontWeight: FontWeight.w300, height: 1.6), textAlign: TextAlign.center),
                                            const SizedBox(height: 20),
                                            Text(_currentQuote?.chinese ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300, height: 1.6), textAlign: TextAlign.center),
                                            const SizedBox(height: 24),
                                            Text('— ${_currentQuote?.author ?? ''}', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                                            const SizedBox(height: 12),
                                            IconButton(icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey), onPressed: _copyToClipboard, tooltip: '复制'),
                                            if (isGuest && _guestViewCount >= 7 && _guestViewCount < 10)
                                              Padding(padding: const EdgeInsets.only(top: 20), child: Text('今日额度剩余 ${10 - _guestViewCount} 条', style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic))),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // #20 双击心形动画
                                    if (_showHeartAnimation)
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0.5, end: 1.2),
                                        duration: const Duration(milliseconds: 400),
                                        curve: Curves.elasticOut,
                                        builder: (_, v, __) => Opacity(
                                          opacity: v > 1 ? 2 - v : v,
                                          child: Transform.scale(scale: v, child: const Icon(Icons.favorite, color: Colors.redAccent, size: 80)),
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
// ============================================================
// 设置昵称独立页面（修复华为浏览器输入问题）
// ============================================================
class SetUsernameScreen extends StatefulWidget {
  final Function(String) onDone;
  const SetUsernameScreen({super.key, required this.onDone});
  @override
  State<SetUsernameScreen> createState() => _SetUsernameScreenState();
}

class _SetUsernameScreenState extends State<SetUsernameScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('昵称不能为空')),
      );
      return;
    }
    if (name.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('昵称最多20个字')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      await supabase.from('profiles').upsert({
        'id': uid,
        'username': name,
        'updated_at': DateTime.now().toIso8601String(),
      });
      widget.onDone(name);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置昵称'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              '给自己取个名字吧',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 8),
            Text(
              '其他用户会看到这个名字',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              maxLength: 20,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '输入昵称',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('确认'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('以后再说', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
              // 底部操作栏：#23
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionBtn(icon: Icons.casino_outlined, label: '刷新', onTap: () => _assignRandomQuote(isInitialLoad: false)),
                    SizedBox(
  width: 56,
  child: Stack(
    clipBehavior: Clip.none,
    children: [
      Center(child: _ActionBtn(icon: isFav ? Icons.favorite : Icons.favorite_outline, label: '收藏', onTap: _toggleFavorite, isActive: isFav)),
      if (_favoriteQuoteIds.isNotEmpty)
        Positioned(
          right: 4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
            child: Text('${_favoriteQuoteIds.length}', style: const TextStyle(fontSize: 8, color: Colors.white, height: 1)),
          ),
        ),
    ],
  ),
),
                    _ActionBtn(icon: _isGeneratingCard ? Icons.hourglass_top : Icons.share_outlined, label: '分享', onTap: () => _shareCard()),
                    _ActionBtn(icon: Icons.list_outlined, label: '列表', onTap: () => isGuest ? _showRegistrationHook(context, isFromFavorite: true) : Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritesScreen(allQuotes: _quotes, favoriteIds: _favoriteQuoteIds)))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// #2 #5 名言详情页
// ============================================================
class QuoteDetailScreen extends StatefulWidget {
  final Quote quote;
  final bool isFavorited;
  final Function(bool) onFavoriteChanged;
  const QuoteDetailScreen({super.key, required this.quote, required this.isFavorited, required this.onFavoriteChanged});
  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  late bool _isFav;
  bool _isGenerating = false;

  @override
  void initState() { super.initState(); _isFav = widget.isFavorited; }

  Future<void> _toggle() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      if (_isFav) {
        await supabase.from('favorites').delete().eq('user_id', user.id).eq('quote_id', widget.quote.id);
      } else {
        await supabase.from('favorites').insert({'user_id': user.id, 'quote_id': widget.quote.id});
      }
      setState(() => _isFav = !_isFav);
      widget.onFavoriteChanged(_isFav);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          IconButton(icon: Icon(_isFav ? Icons.favorite : Icons.favorite_outline, color: _isFav ? Colors.redAccent : Colors.grey), onPressed: _toggle),
          IconButton(icon: Icon(_isGenerating ? Icons.hourglass_top : Icons.share_outlined, color: Colors.grey), onPressed: () {}),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.quote.english, style: GoogleFonts.lora(fontSize: 24, fontWeight: FontWeight.w300, height: 1.6), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Text(widget.quote.chinese, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w300, height: 1.6), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Text('— ${widget.quote.author}', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 收藏列表页 #1 #3 #4 #27 #29 #30
// ============================================================
class FavoritesScreen extends StatefulWidget {
  final List<Quote> allQuotes;
  final Set<int> favoriteIds;
  const FavoritesScreen({super.key, required this.allQuotes, required this.favoriteIds});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Quote> _favs = [];
  bool _loading = true;
  String _filterAuthor = 'All';
  late Set<int> _favIds;

  @override
  void initState() { super.initState(); _favIds = Set.from(widget.favoriteIds); _load(); }

  Future<void> _load() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase.from('favorites').select('quote_id, created_at').eq('user_id', user.id).order('created_at', ascending: false);
      final orderedIds = (data as List).map((r) => r['quote_id'] as int).toList();
      _favs = orderedIds.map((id) => widget.allQuotes.firstWhere((q) => q.id == id, orElse: () => Quote(id: 0, english: '', chinese: '', author: ''))).where((q) => q.id != 0).toList();
    } catch (_) {
      _favs = widget.allQuotes.where((q) => _favIds.contains(q.id)).toList();
    }
    setState(() => _loading = false);
  }

  // #29 取消收藏 + 撤销
  Future<void> _remove(Quote quote) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase.from('favorites').delete().eq('user_id', user.id).eq('quote_id', quote.id);
    setState(() { _favs.remove(quote); _favIds.remove(quote.id); });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('已取消收藏'),
        action: SnackBarAction(label: '撤销', onPressed: () async {
          await supabase.from('favorites').insert({'user_id': user.id, 'quote_id': quote.id});
          setState(() { _favIds.add(quote.id); });
          _load();
        }),
      ));
    }
  }

  List<Quote> get _filtered {
    if (_filterAuthor == 'All') return _favs;
    return _favs.where((q) => q.author == _filterAuthor).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: AppBar(title: Text('我的收藏 (${_favs.length})')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // #27 收藏列表作者筛选
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: ['All', 'Marcus Aurelius', 'Seneca', 'Epictetus'].map((a) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(a == 'All' ? '全部' : a.split(' ').last, style: const TextStyle(fontSize: 11)),
                        selected: _filterAuthor == a,
                        onSelected: (_) => setState(() => _filterAuthor = a),
                        visualDensity: VisualDensity.compact,
                      ),
                    )).toList(),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.favorite_outline, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('还没有收藏', style: TextStyle(color: Colors.grey)),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final q = _filtered[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteDetailScreen(
                                quote: q,
                                isFavorited: _favIds.contains(q.id),
                                onFavoriteChanged: (fav) { if (!fav) { setState(() { _favs.remove(q); _favIds.remove(q.id); }); } },
                              ))),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(q.english, style: GoogleFonts.lora(fontSize: 14, fontWeight: FontWeight.w300, height: 1.5)),
                                    const SizedBox(height: 8),
                                    Text(q.chinese, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[600], height: 1.5)),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('— ${q.author}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                                        IconButton(icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 20), onPressed: () => _remove(q), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ============================================================
// #10 #32 个人资料页 + 关于
// ============================================================
class ProfileScreen extends StatefulWidget {
  final String? username;
  final Function(String) onUpdate;
  const ProfileScreen({super.key, required this.username, required this.onUpdate});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() { super.initState(); _controller = TextEditingController(text: widget.username ?? ''); }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('昵称不能为空，最多20字')));
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      await supabase.from('profiles').upsert({'id': uid, 'username': name, 'updated_at': DateTime.now().toIso8601String()});
      widget.onUpdate(name);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('昵称已更新')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('个人资料')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: Icon(Icons.account_circle_outlined, size: 64, color: Colors.grey)),
          const SizedBox(height: 8),
          Center(child: Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          const SizedBox(height: 32),
          const Text('昵称', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(controller: _controller, maxLength: 20, decoration: const InputDecoration(hintText: '设置你的昵称', border: OutlineInputBorder(), counterText: '')),
          const SizedBox(height: 16),
          SizedBox(height: 44, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('保存'))),
          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 16),
          // #32 关于
          const Text('关于 Stoic Wisdom', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          const SizedBox(height: 12),
          const Text('每日一句斯多葛智慧，帮助你在喧嚣的世界中找到内心的平静。\n\n收录了 Marcus Aurelius、Seneca、Epictetus 三位斯多葛哲学家的 300+ 条经典名言，中英对照。', style: TextStyle(color: Colors.grey, height: 1.6)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => html.window.open('mailto:01barrylee@gmail.com', '_blank'),
            child: const Row(children: [
              Icon(Icons.mail_outline, size: 18, color: Colors.grey),
              SizedBox(width: 8),
              Text('联系作者：01barrylee@gmail.com', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Version 2.0', style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}

// ============================================================
// 通用按钮
// ============================================================
class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final bool isActive;
  const _ActionBtn({required this.icon, required this.label, required this.onTap, this.isActive = false});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: isActive ? Colors.redAccent : Colors.grey, size: 22),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    );
  }
}
