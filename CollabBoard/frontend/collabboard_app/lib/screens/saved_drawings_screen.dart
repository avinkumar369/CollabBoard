import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/board_provider.dart';
import '../models/board.dart';
import 'board_workspace_screen.dart';
import 'board_form_screen.dart';
import '../widgets/share_dialog.dart';

class SavedDrawingsScreen extends StatefulWidget {
  const SavedDrawingsScreen({super.key});

  @override
  State<SavedDrawingsScreen> createState() => _SavedDrawingsScreenState();
}

class _SavedDrawingsScreenState extends State<SavedDrawingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'recent'; // 'recent', 'alphabetical'

  static const Color primaryColor = Color(0xFF5B4BDB);
  static const Color secondaryColor = Color(0xFF8065E8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BoardProvider>(context, listen: false).loadBoards();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleOptionSelected(String val, Board board, BoardProvider boardProvider) async {
    if (!mounted) return;
    switch (val) {
      case 'open':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BoardWorkspaceScreen(board: board)),
        );
        break;
      case 'rename':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BoardFormScreen(board: board)),
        );
        break;
      case 'duplicate':
        final success = await boardProvider.duplicateBoard(board.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(success ? 'Drawing duplicated successfully' : 'Failed to duplicate drawing')),
          );
        }
        break;
      case 'share':
        showDialog(context: context, builder: (_) => ShareDialog(board: board));
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Delete Drawing'),
            content: Text('Are you sure you want to delete "${board.title}"? This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true && mounted) {
          await boardProvider.deleteBoard(board.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Drawing deleted.')),
            );
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        title: const Text(
          'Saved Drawings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort drawings',
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (c) => [
              const PopupMenuItem(value: 'recent', child: Text('Recently Modified')),
              const PopupMenuItem(value: 'alphabetical', child: Text('Alphabetical (A-Z)')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => Provider.of<BoardProvider>(context, listen: false).loadBoards(),
          ),
        ],
      ),
      body: Consumer<BoardProvider>(
        builder: (context, boardProvider, _) {
          if (boardProvider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (boardProvider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load drawings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 6),
                    Text(boardProvider.errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => boardProvider.loadBoards(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          }

          List<Board> boards = boardProvider.boards.where((b) {
            if (_searchQuery.isEmpty) return true;
            return b.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                b.description.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          if (_sortBy == 'alphabetical') {
            boards.sort((a, b) => a.title.compareTo(b.title));
          } else {
            boards.sort((a, b) => b.id.compareTo(a.id));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search saved drawings...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),
              Expanded(
                child: boards.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.brush_outlined, size: 48, color: primaryColor),
                            ),
                            const SizedBox(height: 16),
                            Text('No saved drawings found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 6),
                            Text('Create a new drawing or board to get started.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: primaryColor,
                        onRefresh: () => boardProvider.loadBoards(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: boards.length,
                          itemBuilder: (context, index) {
                            final board = boards[index];
                            return _buildDrawingCard(context, boardProvider, board);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const BoardFormScreen()));
        },
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Drawing', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildDrawingCard(BuildContext context, BoardProvider boardProvider, Board board) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.dividerTheme.color ?? const Color(0xFFE9E9F2);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BoardWorkspaceScreen(board: board)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [primaryColor, secondaryColor]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.palette_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        board.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        board.description.isEmpty ? 'Cloud whiteboard drawing' : board.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.3),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 13, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'ID: #${board.id}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Drawing options',
                  icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
                  onSelected: (val) => _handleOptionSelected(val, board, boardProvider),
                  itemBuilder: (c) => const [
                    PopupMenuItem(value: 'open', child: Row(children: [Icon(Icons.open_in_new, size: 18), SizedBox(width: 8), Text('Open')])),
                    PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Rename')])),
                    PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy, size: 18), SizedBox(width: 8), Text('Duplicate')])),
                    PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share, size: 18), SizedBox(width: 8), Text('Share')])),
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
