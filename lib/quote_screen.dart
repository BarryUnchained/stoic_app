import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:html' as html;
import 'config.dart';
import 'models.dart';
import 'auth.dart';
import 'profile.dart';
import 'favorites.dart';

class QuoteScreen extends StatefulWidget {
  const QuoteScreen({super.key});
  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  final Random _random = Random();
  late FocusNode _focusNode; // 修复：全局唯一焦点管理，杜绝抢焦点闪退
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
  bool _showHeartAnimation = false;

  final List<String> _authors = ['All', 'Marcus Aurelius', 'Seneca', 'Epictetus'];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..requestFocus(); // 仅申请一次
    _loadData();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _fetchQuotes();
    await _fetchFavorites();
    await _fetchProfile();
    await _loadViewedIds();
    if (supabase.auth.currentUser != null && (_username == null || _username!.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSetUsernameDialog());
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchQuotes() async {
    try {
      final data = await supabase.from('quotes').select();
      _quotes = (data as List).map((r) => Quote.fromJson(r)).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_quotes', jsonEncode(_quotes.map((q) => q.toJson()).toList()));
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_quotes');
      if (cached != null) _quotes = (jsonDecode(cached) as List).map((j) => Quote.fromJson(j)).toList();
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

  Future<void> _loadViewedIds() async {
    final prefs = await SharedPreferences.getInstance();
    _viewedIds = (prefs.getStringList('viewed_ids') ?? []).map((s) => int.parse(s)).toSet();
  }

  Future<void> _saveViewedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('viewed_ids', _viewedIds.map((i) => i.toString()).toList());
  }

  void _pickDailyQuote() {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final filtered = _selectedAuthor == 'All' ? _quotes : _quotes.where((q) => q.author == _selectedAuthor).toList();
    if (filtered.isEmpty) return;
    _currentQuote = filtered[Random(seed).nextInt(filtered.length)];
    _viewedIds.add(_currentQuote!.id);
    _saveViewedIds();
  }

  void _pickNewQuote() {
    final filtered = _selectedAuthor == 'All' ? _quotes : _quotes.where((q) => q.author == _selectedAuthor).toList();
    if (filtered.isEmpty) return;
    final unseen = filtered.where((q) => !_viewedIds.contains(q.id)).toList();
    final pool = unseen.isNotEmpty ? unseen : filtered;
    if (unseen.isEmpty) _viewedIds.clear();
    Quote next;
    do { next = pool[_random.nextInt(pool.length)]; } while (_currentQuote != null && next.id == _currentQuote!.id && pool.length > 1);
    setState(() => _currentQuote = next);
    _viewedIds.add(next.id);
    _saveViewedIds();
  }

  Future<void> _assignRandomQuote({required bool isInitialLoad}) async {
    if (_quotes.isEmpty) return;
    if (isInitialLoad) { _pickDailyQuote(); return; }
    if (supabase.auth.currentUser != null) { _pickNewQuote(); return; }

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    if (prefs.getString('last_view_date') != today) {
      await prefs.setString('last_view_date', today); await prefs.setInt('view_count', 1);
      setState(() => _guestViewCount = 1); _pickNewQuote();
    } else if ((prefs.getInt('view_count') ?? 0) < 10) {
      await prefs.setInt('view_count', (prefs.getInt('view_count') ?? 0) + 1);
      setState(() => _guestViewCount = prefs.getInt('view_count')!); _pickNewQuote();
    } else {
      setState(() => _guestViewCount = 10); _showRegistrationHook(context);
    }
  }

  void _copyToClipboard() {
    if (_currentQuote == null) return;
    Clipboard.setData(ClipboardData(text: "${_currentQuote!.english}\n${_currentQuote!.chinese}\n— ${_currentQuote!.author}"));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)));
  }

  void _onDoubleTap() {
    if (supabase.auth.currentUser == null) { _showRegistrationHook(context, isFromFavorite: true); return; }
    if (_currentQuote == null || _favoriteQuoteIds.contains(_currentQuote!.id)) return;
    _toggleFavorite();
    setState(() => _showHeartAnimation = true);
    Future.delayed(const Duration(milliseconds: 800), () { if (mounted) setState(() => _showHeartAnimation = false); });
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
    } finally { setState(() => _isFavoriting = false); }
  }

  Future<void> _shareCard() async {
    if (_currentQuote == null || _isGeneratingCard) return;
    setState(() => _isGeneratingCard = true);
    try {
      final theme = cardThemes[_random.nextInt(cardThemes.length)];
      final bytes = await _renderCard(_currentQuote!, theme);
      if (bytes != null) {
        final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], 'image/png'));
        html.AnchorElement(href: url)..setAttribute('download', 'stoic_wisdom_${_currentQuote!.id}.png')..click();
        html.Url.revokeObjectUrl(url);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('卡片已下载'), duration: Duration(seconds: 2)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成失败：$e')));
    } finally { setState(() => _isGeneratingCard = false); }
  }

  Future<List<int>?> _renderCard(Quote q, CardTheme theme) async {
    final recorder = ui.PictureRecorder(); final canvas = Canvas(recorder);
    const double w = 1080, h = 1350, p = 80, cw = w - p * 2;
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: theme.gradient).createShader(const Rect.fromLTWH(0, 0, w, h)));
    canvas.drawLine(const Offset(p, 120), const Offset(w - p, 120), Paint()..color = const Color(0x33FFFFFF)..strokeWidth = 1);
    
    final eng = (ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center, maxLines: 20))..pushStyle(ui.TextStyle(color: const Color(0xFFE0E0E0), fontSize: 42, fontWeight: ui.FontWeight.w300, height: 1.6))..addText(q.english)).build()..layout(const ui.ParagraphConstraints(width: cw));
    final cn = (ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center, maxLines: 20))..pushStyle(ui.TextStyle(color: const Color(0x99FFFFFF), fontSize: 34, fontWeight: ui.FontWeight.w300, height: 1.7))..addText(q.chinese)).build()..layout(const ui.ParagraphConstraints(width: cw));
    final au = (ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))..pushStyle(ui.TextStyle(color: const Color(0x66FFFFFF), fontSize: 28, fontStyle: ui.FontStyle.italic))..addText('— ${q.author}')).build()..layout(const ui.ParagraphConstraints(width: cw));

    double y = max(160, (h - eng.height - 50 - cn.height - 50 - au.height) / 2);
    canvas.drawParagraph(eng, Offset(p, y)); y += eng.height + 50; canvas.drawParagraph(cn, Offset(p, y)); y += cn.height + 50; canvas.drawParagraph(au, Offset(p, y));
    canvas.drawLine(const Offset(p, h - 120), const Offset(w - p, h - 120), Paint()..color = const Color(0x33FFFFFF)..strokeWidth = 1);
    canvas.drawParagraph((ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))..pushStyle(ui.TextStyle(color: const Color(0x44FFFFFF), fontSize: 18, letterSpacing: 1))..addText('STOIC WISDOM  ·  barryunchained.github.io/stoic_app')).build()..layout(const ui.ParagraphConstraints(width: cw)), const Offset(p, h - 90));
    
    return (await (await recorder.endRecording().toImage(w.toInt(), h.toInt())).toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();
  }

  void _showSetUsernameDialog() { Navigator.push(context, MaterialPageRoute(builder: (_) => SetUsernameScreen(onDone: (name) => setState(() => _username = name)))); }

  void _showRegistrationHook(BuildContext context, {bool isFromFavorite = false}) {
    showDialog(
      context: context, barrierDismissible: isFromFavorite,
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

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出'), content: const Text('退出后需要重新登录'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); supabase.auth.signOut().then((_) { if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const QuoteScreen())); }); }, child: const Text('退出')),
        ],
      ),
    );
  }

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
    final now = DateTime.now();
    final dateStr = '${now.year}年${now.month}月${now.day}日 星期${['一', '二', '三', '四', '五', '六', '日'][now.weekday - 1]}';

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyPress,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: Text(_username ?? (isGuest ? '游客模式' : user.email ?? ''), style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                        Row(children: [
                          if (!isGuest) GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(username: _username, onUpdate: (n) => setState(() => _username = n)))), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.person_outline, size: 18, color: Colors.grey))),
                          GestureDetector(onTap: () => isGuest ? Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())) : _confirmSignOut(), child: Text(isGuest ? '登录' : '退出', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.withOpacity(0.6))),
                  ],
                ),
              ),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _authors.map((a) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(a == 'All' ? '全部' : a.split(' ').last, style: const TextStyle(fontSize: 11)), selected: _selectedAuthor == a, onSelected: (_) { setState(() => _selectedAuthor = a); _pickNewQuote(); }, visualDensity: VisualDensity.compact),
                  )).toList(),
                ),
              ),
              Expanded(
                child: _isLoading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
                  onRefresh: () async => _assignRandomQuote(isInitialLoad: false),
                  child: GestureDetector(
                    onDoubleTap: _onDoubleTap, onLongPress: _copyToClipboard, onVerticalDragEnd: (d) { if ((d.primaryVelocity ?? 0).abs() > 200) _assignRandomQuote(isInitialLoad: false); },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.65,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200), transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                                child: Padding(
                                  key: ValueKey(_currentQuote?.id), padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(_currentQuote?.english ?? '', style: GoogleFonts.lora(fontSize: 22, fontWeight: FontWeight.w300, height: 1.6), textAlign: TextAlign.center),
                                      const SizedBox(height: 20),
                                      Text(_currentQuote?.chinese ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300, height: 1.6), textAlign: TextAlign.center),
                                      const SizedBox(height: 24),
                                      Text('— ${_currentQuote?.author ?? ''}', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                                      const SizedBox(height: 12),
                                      IconButton(icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey), onPressed: _copyToClipboard, tooltip: '复制'),
                                      if (isGuest && _guestViewCount >= 7 && _guestViewCount < 10) Padding(padding: const EdgeInsets.only(top: 20), child: Text('今日额度剩余 ${10 - _guestViewCount} 条', style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic))),
                                    ],
                                  ),
                                ),
                              ),
                              if (_showHeartAnimation) TweenAnimationBuilder<double>(tween: Tween(begin: 0.5, end: 1.2), duration: const Duration(milliseconds: 400), curve: Curves.elasticOut, builder: (_, v, __) => Opacity(opacity: v > 1 ? 2 - v : v, child: Transform.scale(scale: v, child: const Icon(Icons.favorite, color: Colors.redAccent, size: 80)))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16), color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionBtn(icon: Icons.casino_outlined, label: '刷新', onTap: () => _assignRandomQuote(isInitialLoad: false)),
                    SizedBox(width: 56, child: Stack(clipBehavior: Clip.none, children: [Center(child: _ActionBtn(icon: isFav ? Icons.favorite : Icons.favorite_outline, label: '收藏', onTap: _toggleFavorite, isActive: isFav)), if (_favoriteQuoteIds.isNotEmpty) Positioned(right: 4, top: -4, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: Text('${_favoriteQuoteIds.length}', style: const TextStyle(fontSize: 8, color: Colors.white, height: 1))))])),
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

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final bool isActive;
  const _ActionBtn({required this.icon, required this.label, required this.onTap, this.isActive = false});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: isActive ? Colors.redAccent : Colors.grey, size: 22), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))]));
  }
}