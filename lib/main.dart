import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 核心：用于剪贴板功能
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

class Quote {
  final int id;
  final String english;
  final String chinese;
  final String author;
  const Quote({required this.id, required this.english, required this.chinese, required this.author});
}

class StoicApp extends StatelessWidget {
  const StoicApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stoic Wisdom | 斯多葛智慧',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const QuoteScreen(),
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
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = '请输入邮箱和密码');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      if (_isSignUp) {
        await supabase.auth.signUp(email: email, password: password);
      } else {
        await supabase.auth.signInWithPassword(email: email, password: password);
      }
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const QuoteScreen()), (route) => false,
        );
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
    final primaryTextColor = isDark ? Colors.white70 : const Color(0xFF2C2C2C);
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.auto_stories_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Stoic Wisdom', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: primaryTextColor)),
              const SizedBox(height: 48),
              TextField(controller: _emailController, decoration: const InputDecoration(hintText: '邮箱')),
              const SizedBox(height: 12),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(hintText: '密码')),
              const SizedBox(height: 24),
              if (_errorMessage != null) Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
              ElevatedButton(onPressed: _isLoading ? null : _handleAuth, child: Text(_isSignUp ? '注册' : '登录')),
              TextButton(onPressed: () => setState(() => _isSignUp = !_isSignUp), child: Text(_isSignUp ? '已有账号？去登录' : '没有账号？去注册')),
            ],
          ),
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
      _quotes = (data as List).map((r) => Quote(id: r['id'], english: r['english'], chinese: r['chinese'], author: r['author'])).toList();
      await _assignRandomQuote(isInitialLoad: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignRandomQuote({required bool isInitialLoad}) async {
    final user = supabase.auth.currentUser;
    if (user != null) { _pickNewQuote(); return; }
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    String? lastDate = prefs.getString('last_view_date');
    int viewCount = prefs.getInt('view_count') ?? 0;
    if (lastDate != today) {
      await prefs.setString('last_view_date', today); await prefs.setInt('view_count', 1);
      setState(() => _guestViewCount = 1); _pickNewQuote();
    } else {
      if (viewCount < 10) {
        await prefs.setInt('view_count', viewCount + 1); setState(() => _guestViewCount = viewCount + 1); _pickNewQuote();
      } else {
        setState(() => _guestViewCount = 10); _showRegistrationHook(context);
      }
    }
  }

  void _pickNewQuote() {
    if (_quotes.isEmpty) return;
    Quote next;
    do {
      next = _quotes[_random.nextInt(_quotes.length)];
    } while (_currentQuote != null && next.id == _currentQuote!.id && _quotes.length > 1);
    setState(() => _currentQuote = next);
  }

  // 新增：一键复制功能
  void _copyToClipboard() {
    if (_currentQuote == null) return;
    final text = "${_currentQuote!.english}\n${_currentQuote!.chinese}\n— ${_currentQuote!.author}";
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('名言已复制到剪贴板'), duration: Duration(seconds: 1)),
        );
      }
    });
  }

  Future<void> _fetchFavorites() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase.from('favorites').select('quote_id').eq('user_id', user.id);
    setState(() => _favoriteQuoteIds = (data as List).map((r) => r['quote_id'] as int).toSet());
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

  void _showRegistrationHook(BuildContext context, {bool isFromFavorite = false}) {
    showDialog(
      context: context,
      barrierDismissible: isFromFavorite,
      builder: (context) => AlertDialog(
        title: Text(isFromFavorite ? "收藏以永久保存" : "今日智慧已达上限"),
        content: const Text("注册登录后，即可解锁 300+ 完整名言库及评论收藏功能。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("再逛逛")),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); },
            child: const Text("立即登录"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = supabase.auth.currentUser;
    final isGuest = user == null;
    final bool isFavorited = _currentQuote != null && _favoriteQuoteIds.contains(_currentQuote!.id);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isGuest ? '游客模式' : user.email!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  GestureDetector(
                    onTap: () => isGuest ? Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())) : supabase.auth.signOut().then((_) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const QuoteScreen()))),
                    child: Text(isGuest ? '登录' : '退出', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _isLoading ? const CircularProgressIndicator() : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                    child: Column(
                      key: ValueKey(_currentQuote?.id),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_currentQuote!.english, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w300), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        Text(_currentQuote!.chinese, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Text("— ${_currentQuote!.author}", style: const TextStyle(color: Colors.grey)),
                        
                        // 复制按钮
                        const SizedBox(height: 16),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.grey),
                          onPressed: _copyToClipboard,
                          tooltip: '复制名言',
                        ),

                        if (isGuest && _guestViewCount >= 7 && _guestViewCount < 10) ...[
                          const SizedBox(height: 40),
                          Text('今日额度剩余 ${10 - _guestViewCount} 条，登录解锁全部', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(icon: Icons.casino_outlined, label: '刷新', onTap: () => _assignRandomQuote(isInitialLoad: false)),
                  _ActionButton(icon: isFavorited ? Icons.favorite : Icons.favorite_outline, label: '收藏', onTap: _toggleFavorite, isActive: isFavorited),
                  _ActionButton(icon: Icons.list_outlined, label: '列表', onTap: () => isGuest ? _showRegistrationHook(context, isFromFavorite: true) : Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritesScreen(allQuotes: _quotes)))),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 收藏列表页面（含取消收藏功能）
// ============================================================

class FavoritesScreen extends StatefulWidget {
  final List<Quote> allQuotes;
  const FavoritesScreen({super.key, required this.allQuotes});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Quote> _favs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase.from('favorites').select('quote_id').eq('user_id', user.id);
    final ids = (data as List).map((r) => r['quote_id'] as int).toSet();
    setState(() {
      _favs = widget.allQuotes.where((q) => ids.contains(q.id)).toList();
      _loading = false;
    });
  }

  Future<void> _remove(int id) async {
    final user = supabase.auth.currentUser;
    await supabase.from('favorites').delete().eq('user_id', user!.id).eq('quote_id', id);
    setState(() => _favs.removeWhere((q) => q.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _favs.length,
        itemBuilder: (context, i) => ListTile(
          title: Text(_favs[i].chinese),
          subtitle: Text(_favs[i].author),
          trailing: IconButton(icon: const Icon(Icons.favorite, color: Colors.redAccent), onPressed: () => _remove(_favs[i].id)),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final bool isActive;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.isActive = false});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [Icon(icon, color: isActive ? Colors.redAccent : Colors.grey), Text(label, style: const TextStyle(fontSize: 10))]),
    );
  }
}