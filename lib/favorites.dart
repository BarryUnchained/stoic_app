import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config.dart';
import 'models.dart';

// ============================================================
// 收藏列表主页面
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
  void initState() { 
    super.initState(); 
    _favIds = Set.from(widget.favoriteIds); 
    _load(); 
  }

  Future<void> _load() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase.from('favorites').select('quote_id, created_at').eq('user_id', user.id).order('created_at', ascending: false);
      final orderedIds = (data as List).map((r) => r['quote_id'] as int).toList();
      _favs = orderedIds.map((id) => widget.allQuotes.firstWhere((q) => q.id == id, orElse: () => const Quote(id: 0, english: '', chinese: '', author: ''))).where((q) => q.id != 0).toList();
    } catch (_) {
      _favs = widget.allQuotes.where((q) => _favIds.contains(q.id)).toList();
    }
    setState(() => _loading = false);
  }

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

  List<Quote> get _filtered => _filterAuthor == 'All' ? _favs : _favs.where((q) => q.author == _filterAuthor).toList();

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
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: ['All', 'Marcus Aurelius', 'Seneca', 'Epictetus'].map((a) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(label: Text(a == 'All' ? '全部' : a.split(' ').last, style: const TextStyle(fontSize: 11)), selected: _filterAuthor == a, onSelected: (_) => setState(() => _filterAuthor = a), visualDensity: VisualDensity.compact),
                    )).toList(),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.favorite_outline, size: 48, color: Colors.grey), SizedBox(height: 16), Text('还没有收藏', style: TextStyle(color: Colors.grey))]))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16), itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final q = _filtered[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteDetailScreen(quote: q, isFavorited: _favIds.contains(q.id), onFavoriteChanged: (fav) { if (!fav) { setState(() { _favs.remove(q); _favIds.remove(q.id); }); } }))),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(q.english, style: GoogleFonts.lora(fontSize: 14, fontWeight: FontWeight.w300, height: 1.5)),
                                    const SizedBox(height: 8),
                                    Text(q.chinese, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[600], height: 1.5)),
                                    const SizedBox(height: 8),
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('— ${q.author}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)), IconButton(icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 20), onPressed: () => _remove(q), padding: EdgeInsets.zero, constraints: const BoxConstraints())]),
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
// 名言详情页（含评论功能）
// ============================================================
class QuoteDetailScreen extends StatefulWidget {
  final Quote quote;
  final bool isFavorited;
  final Function(bool) onFavoriteChanged;
  const QuoteDetailScreen({
    super.key, 
    required this.quote, 
    required this.isFavorited, 
    required this.onFavoriteChanged
  });

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  late bool _isFav;
  final _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _loadingComments = true;

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFavorited;
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final data = await supabase
          .from('comments')
          .select('*, profiles(username)')
          .eq('quote_id', widget.quote.id)
          .order('created_at', ascending: false);
      setState(() {
        _comments = data as List<dynamic>;
        _loadingComments = false;
      });
    } catch (e) {
      debugPrint('加载评论失败: $e');
    }
  }

  Future<void> _postComment() async {
    final user = supabase.auth.currentUser;
    final content = _commentController.text.trim();
    if (user == null || content.isEmpty) return;

    try {
      await supabase.from('comments').insert({
        'quote_id': widget.quote.id,
        'user_id': user.id,
        'content': content,
      });
      _commentController.clear();
      _fetchComments();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评论已发布')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发布失败: $e')));
    }
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isFav ? Icons.favorite : Icons.favorite_outline, color: _isFav ? Colors.redAccent : Colors.grey), 
            onPressed: _toggle
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            child: Column(
              children: [
                Text(widget.quote.english, style: GoogleFonts.lora(fontSize: 22, fontWeight: FontWeight.w300, height: 1.6), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text(widget.quote.chinese, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300, height: 1.6), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text('— ${widget.quote.author}', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _loadingComments 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final c = _comments[index];
                    return ListTile(
                      title: Text(c['profiles']?['username'] ?? '匿名践行者', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      subtitle: Text(c['content'], style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                      trailing: Text(c['created_at'].toString().substring(5, 10), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    );
                  },
                ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(hintText: '写下你的感悟...', border: OutlineInputBorder()),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _postComment),
              ],
            ),
          ),
        ],
      ),
    );
  }
}