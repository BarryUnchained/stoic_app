import 'package:flutter/material.dart';
import 'config.dart';
import 'models.dart';
import 'auth.dart';

// ============================================================
// 时间格式化工具
// ============================================================
class DateTimeFormatter {
  static String formatCommentTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return "${dt.month.toString().padLeft(2, '0')}-"
             "${dt.day.toString().padLeft(2, '0')} "
             "${dt.hour.toString().padLeft(2, '0')}:"
             "${dt.minute.toString().padLeft(2, '0')}:"
             "${dt.second.toString().padLeft(2, '0')}";
    } catch (_) {
      return "未知时间";
    }
  }

  static String formatCommentDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return dt.toString().substring(0, 10);
    } catch (_) {
      return "未知日期";
    }
  }
}

// ============================================================
// 修行记录主页面：双 Tab (我的收藏 | 我的笔记) + 全局搜索
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
  bool _loadingFavs = true;
  String _filterAuthor = 'All';
  late Set<int> _favIds;

  List<Map<String, dynamic>> _notesData = [];
  bool _loadingNotes = true;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() { 
    super.initState(); 
    _favIds = Set.from(widget.favoriteIds); 
    _loadAllData(); 
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() { _loadingFavs = false; _loadingNotes = false; });
      return;
    }

    try {
      final favData = await supabase.from('favorites').select('quote_id, created_at').eq('user_id', user.id).order('created_at', ascending: false);
      final orderedIds = (favData as List).map((r) => r['quote_id'] as int).toList();
      _favs = orderedIds.map((id) => widget.allQuotes.firstWhere((q) => q.id == id, orElse: () => const Quote(id: 0, english: '', chinese: '', author: ''))).where((q) => q.id != 0).toList();
    } catch (_) {
      _favs = widget.allQuotes.where((q) => _favIds.contains(q.id)).toList();
    }

    try {
      final notesData = await supabase.from('notes').select('quote_id, content, updated_at').eq('user_id', user.id).order('updated_at', ascending: false);
      _notesData = List<Map<String, dynamic>>.from(notesData);
    } catch (_) {}

    if (mounted) setState(() { _loadingFavs = false; _loadingNotes = false; });
  }

  Future<void> _removeFavorite(Quote quote) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() { _favs.remove(quote); _favIds.remove(quote.id); });
    try {
      await supabase.from('favorites').delete().eq('user_id', user.id).eq('quote_id', quote.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消收藏'), duration: Duration(seconds: 2)));
    } catch (_) { _loadAllData(); }
  }

  List<Quote> get _filteredFavs {
    var list = _filterAuthor == 'All' ? _favs : _favs.where((q) => q.author == _filterAuthor).toList();
    if (_searchQuery.isNotEmpty) list = list.where((q) => q.matchesSearch(_searchQuery)).toList();
    return list;
  }

  List<Map<String, dynamic>> get _filteredNotes {
    if (_searchQuery.isEmpty) return _notesData;
    return _notesData.where((note) {
      final q = widget.allQuotes.firstWhere((q) => q.id == note['quote_id'], orElse: () => const Quote(id: 0, english: '', chinese: '', author: ''));
      final contentMatch = (note['content'] as String?)?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      return q.matchesSearch(_searchQuery) || contentMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F6F0); 

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('修行记录', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
          bottom: const TabBar(tabs: [Tab(text: '我的收藏'), Tab(text: '我的笔记')]),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: '搜索原文、翻译或笔记内容...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                      : null,
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : Colors.grey[200],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildFavoritesTab(cardColor, isDark),
                  _buildNotesTab(cardColor, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesTab(Color cardColor, bool isDark) {
    if (_loadingFavs) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal, 
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: ['All', 'Marcus Aurelius', 'Seneca', 'Epictetus']
                .map((a) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(a == 'All' ? '全部' : a.split(' ').last, style: const TextStyle(fontSize: 11)), 
                    selected: _filterAuthor == a, 
                    onSelected: (_) => setState(() => _filterAuthor = a), 
                    visualDensity: VisualDensity.compact
                  ),
                )).toList(),
          ),
        ),
        Expanded(
          child: _filteredFavs.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 48, color: Colors.grey), SizedBox(height: 16), Text('未找到相关收藏', style: TextStyle(color: Colors.grey))]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16), 
                  itemCount: _filteredFavs.length,
                  itemBuilder: (_, i) {
                    final q = _filteredFavs[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteDetailScreen(quote: q, isFavorited: _favIds.contains(q.id), onFavoriteChanged: (fav) { if (!fav) { setState(() { _favs.remove(q); _favIds.remove(q.id); }); } }))).then((_) => _loadAllData()), 
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12), 
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(q.english, style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.w400, height: 1.6)),
                            const SizedBox(height: 12),
                            Text(q.chinese, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87, height: 1.6)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                              children: [
                                Text('– ${q.author}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)), 
                                IconButton(icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 20), onPressed: () => _removeFavorite(q), padding: EdgeInsets.zero, constraints: const BoxConstraints())
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
    );
  }

  Widget _buildNotesTab(Color cardColor, bool isDark) {
    if (_loadingNotes) return const Center(child: CircularProgressIndicator());
    if (_filteredNotes.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.edit_note, size: 48, color: Colors.grey), SizedBox(height: 16), Text('没有找到相关笔记', style: TextStyle(color: Colors.grey))]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredNotes.length,
      itemBuilder: (_, i) {
        final note = _filteredNotes[i];
        final quoteId = note['quote_id'] as int;
        final q = widget.allQuotes.firstWhere((q) => q.id == quoteId, orElse: () => const Quote(id: 0, english: '数据丢失', chinese: '数据丢失', author: ''));
        if (q.id == 0) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteDetailScreen(quote: q, isFavorited: _favIds.contains(q.id), onFavoriteChanged: (fav) { if (fav) { _favIds.add(q.id); } else { _favIds.remove(q.id); } }))).then((_) => _loadAllData()), 
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.chinese, style: TextStyle(fontFamily: 'Georgia', fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[700], height: 1.5, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
                const Divider(height: 24),
                Text(note['content'] ?? '', style: const TextStyle(fontSize: 15, height: 1.7), maxLines: 4, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Text('上次编辑: ${DateTimeFormatter.formatCommentTime(note['updated_at'])}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// 名言详情页面（完整保留，包含评论与笔记输入逻辑）
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

class _QuoteDetailScreenState extends State<QuoteDetailScreen> with SingleTickerProviderStateMixin {
  late bool _isFav;
  final _commentController = TextEditingController();
  final _noteController = TextEditingController();
  List<dynamic> _comments = [];
  bool _loadingComments = true;
  bool _postingComment = false;
  
  bool _loadingNote = true;
  bool _savingNote = false;
  bool _isEditingNote = false;
  String? _savedNote;
  DateTime? _noteUpdatedAt;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFavorited;
    _tabController = TabController(length: 2, vsync: this);
    _fetchComments();
    _fetchNote().then((hasNote) {
      if (hasNote && mounted) {
        _tabController.animateTo(1);
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _noteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final data = await supabase
          .from('comments')
          .select('*, profiles(username)')
          .eq('quote_id', widget.quote.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() => _comments = data as List<dynamic>);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('评论加载失败: $e'), duration: const Duration(seconds: 4))
        );
      }
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _postComment() async {
    if (_postingComment) return;
    
    final user = supabase.auth.currentUser;
    final content = _commentController.text.trim();
    if (user == null || content.isEmpty) return;

    setState(() => _postingComment = true);

    try {
      await supabase.from('comments').insert({
        'quote_id': widget.quote.id,
        'user_id': user.id,
        'content': content,
      });
      _commentController.clear();
      await _fetchComments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('评论已发布'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布失败: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  Future<bool> _fetchNote() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loadingNote = false);
      return false;
    }

    try {
      final data = await supabase
          .from('notes')
          .select()
          .eq('user_id', user.id)
          .eq('quote_id', widget.quote.id)
          .maybeSingle();
      
      if (mounted) {
        if (data != null) {
          _savedNote = data['content'] as String?;
          _noteUpdatedAt = data['updated_at'] != null 
              ? DateTime.parse(data['updated_at'] as String).toLocal() 
              : null;
          _noteController.text = _savedNote ?? '';
          setState(() => _loadingNote = false);
          return true;
        }
        setState(() => _loadingNote = false);
      }
      return false;
    } catch (e) {
      if (mounted) setState(() => _loadingNote = false);
      return false;
    }
  }

  Future<void> _saveNote() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final content = _noteController.text.trim();
    if (content.isEmpty && _savedNote == null) return;

    setState(() => _savingNote = true);

    try {
      if (content.isEmpty) {
        await supabase
            .from('notes')
            .delete()
            .eq('user_id', user.id)
            .eq('quote_id', widget.quote.id);
        setState(() {
          _savedNote = null;
          _noteUpdatedAt = null;
          _isEditingNote = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('笔记已删除'))
          );
        }
      } else {
        await supabase.from('notes').upsert({
          'user_id': user.id,
          'quote_id': widget.quote.id,
          'content': content,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,quote_id');
        
        setState(() {
          _savedNote = content;
          _noteUpdatedAt = DateTime.now();
          _isEditingNote = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('笔记已保存'))
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Future<void> _toggle() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      if (_isFav) {
        await supabase
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('quote_id', widget.quote.id);
      } else {
        await supabase
            .from('favorites')
            .insert({'user_id': user.id, 'quote_id': widget.quote.id});
      }
      setState(() => _isFav = !_isFav);
      widget.onFavoriteChanged(_isFav);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = supabase.auth.currentUser;
    final isGuest = user == null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isFav ? Icons.favorite : Icons.favorite_outline, 
              color: _isFav ? Colors.redAccent : Colors.grey), 
            onPressed: _toggle
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Column(
              children: [
                Text(widget.quote.english, 
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w300, height: 1.6), 
                  textAlign: TextAlign.center
                ),
                const SizedBox(height: 12),
                Text(widget.quote.chinese, 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300, height: 1.6), 
                  textAlign: TextAlign.center
                ),
                const SizedBox(height: 12),
                Text('– ${widget.quote.author}', 
                  style: const TextStyle(fontFamily: 'Georgia', color: Colors.grey, fontStyle: FontStyle.italic)
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: isDark ? Colors.white : Colors.black87,
            unselectedLabelColor: Colors.grey,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: '评论 (${_comments.length})'),
              Tab(text: _savedNote != null ? '我的笔记 ✏️' : '我的笔记'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Column(
                  children: [
                    Expanded(
                      child: _loadingComments 
                        ? const Center(child: CircularProgressIndicator())
                        : _comments.isEmpty 
                            ? const Center(
                                child: Text('暂无评论，成为第一个留下足迹的人吧', 
                                  style: TextStyle(color: Colors.grey, fontSize: 12)
                                )
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _comments.length,
                                itemBuilder: (context, index) {
                                  final c = _comments[index];
                                  return ListTile(
                                    title: Text(
                                      c['profiles']?['username'] ?? '匿名修行者', 
                                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey)
                                    ),
                                    subtitle: Text(
                                      c['content'], 
                                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)
                                    ),
                                    trailing: Text(
                                      DateTimeFormatter.formatCommentTime(c['created_at']),
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                    onTap: () {
                                      final targetUser = c['profiles']?['username'] ?? '匿名修行者';
                                      _commentController.text = "回复 @$targetUser : ";
                                    },
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
                              decoration: const InputDecoration(
                                hintText: '写下你的评论...', 
                                border: OutlineInputBorder()
                              ),
                              enabled: !_postingComment,
                            ),
                          ),
                          IconButton(
                            icon: _postingComment 
                              ? const SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                            onPressed: _postingComment ? null : _postComment,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _buildNoteTab(isDark, isGuest),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteTab(bool isDark, bool isGuest) {
    if (isGuest) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('登录后即可记录私人笔记', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const LoginScreen())
              ),
              child: const Text('立即登录'),
            ),
          ],
        ),
      );
    }

    if (_loadingNote) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_savedNote != null && !_isEditingNote) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _noteUpdatedAt != null 
                      ? '最后编辑于 ${DateTimeFormatter.formatCommentTime(_noteUpdatedAt!.toIso8601String())}' 
                      : '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                      onPressed: () => setState(() => _isEditingNote = true),
                      tooltip: '编辑',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('删除笔记'),
                            content: const Text('确定要删除这条笔记吗？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _noteController.clear();
                                  _saveNote();
                                },
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                      },
                      tooltip: '删除',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _savedNote!,
                  style: TextStyle(
                    fontSize: 15, 
                    height: 1.8,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _savedNote != null ? '编辑笔记' : '写下你的感悟与思考',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              Row(
                children: [
                  if (_savedNote != null)
                    TextButton(
                      onPressed: () {
                        _noteController.text = _savedNote ?? '';
                        setState(() => _isEditingNote = false);
                      },
                      child: const Text('取消', style: TextStyle(fontSize: 13)),
                    ),
                  TextButton(
                    onPressed: _savingNote ? null : _saveNote,
                    child: _savingNote 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('保存', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _noteController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: '这句话让你想到了什么？\n它如何与你的生活经历产生共鸣？\n你打算如何将这个智慧运用到生活中？',
                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 14, height: 1.8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: TextStyle(
                fontSize: 15, 
                height: 1.8,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}