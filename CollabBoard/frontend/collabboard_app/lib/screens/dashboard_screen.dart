import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/board_provider.dart';
import '../models/board.dart';
import 'board_form_screen.dart';
import 'board_workspace_screen.dart';
import 'saved_drawings_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        title: Text(
          _currentIndex == 0
              ? 'CollabBoard'
              : _currentIndex == 1
                  ? 'My Boards'
                  : _currentIndex == 2
                      ? 'Saved Drawings'
                      : 'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 21,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: Icon(Icons.settings_outlined, color: theme.colorScheme.onSurface),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          IconButton(
            tooltip: 'Create board',
            icon: Icon(Icons.add_circle_outline_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => _openBoardForm(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(context),
          _buildMyBoardsTab(context, shared: false),
          const SavedDrawingsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'My Boards'),
          NavigationDestination(icon: Icon(Icons.brush_outlined), selectedIcon: Icon(Icons.brush), label: 'Saved Drawings'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _currentIndex != 3
          ? FloatingActionButton.extended(
              onPressed: () => _openBoardForm(context),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Board', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<AuthProvider>(context).user;

    return Consumer<BoardProvider>(
      builder: (context, boardProvider, _) {
        if (boardProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final allBoards = boardProvider.boards;
        final myBoards = allBoards.where((b) => user == null || b.ownerId == user.id).toList();
        final sharedBoards = allBoards.where((b) => user != null && b.ownerId != user.id).toList();

        final filteredBoards = allBoards.where((b) {
          if (_searchQuery.isEmpty) return true;
          return b.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              b.description.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        return RefreshIndicator(
          color: primaryColor,
          onRefresh: () => boardProvider.loadBoards(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildWelcomeSection(context, user?.name ?? 'Creator'),
              const SizedBox(height: 20),

              // Search Bar
              TextField(
                controller: _searchController,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search boards & drawings...',
                  prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: theme.colorScheme.onSurfaceVariant),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),

              const SizedBox(height: 24),

              // Overview Statistics Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Total Boards',
                      allBoards.length.toString(),
                      Icons.dashboard,
                      primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'My Boards',
                      myBoards.length.toString(),
                      Icons.folder,
                      secondaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Shared',
                      sharedBoards.length.toString(),
                      Icons.people,
                      Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Drawings & Boards',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${filteredBoards.length} ${filteredBoards.length == 1 ? 'board' : 'boards'}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (filteredBoards.isEmpty)
                _buildEmptyState(context)
              else
                ...filteredBoards.map(
                  (board) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildBoardCard(context, boardProvider, board),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyBoardsTab(BuildContext context, {required bool shared}) {
    final user = Provider.of<AuthProvider>(context).user;

    return Consumer<BoardProvider>(
      builder: (context, boardProvider, _) {
        if (boardProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final filtered = boardProvider.boards.where((b) {
          final isOwn = user == null || b.ownerId == user.id;
          return shared ? !isOwn : isOwn;
        }).toList();

        return RefreshIndicator(
          color: primaryColor,
          onRefresh: () => boardProvider.loadBoards(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (filtered.isEmpty)
                _buildEmptyState(context)
              else
                ...filtered.map(
                  (board) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildBoardCard(context, boardProvider, board),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeSection(BuildContext context, String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.waving_hand, color: Colors.amber, size: 28),
              const SizedBox(width: 10),
              Text(
                'Welcome, $name!',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Think together. Create together. Real-time whiteboard workspace.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.dividerTheme.color ?? const Color(0xFFE9E9F2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerTheme.color ?? const Color(0xFFE9E9F2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.dashboard_outlined, size: 42, color: primaryColor),
          ),
          const SizedBox(height: 18),
          Text(
            'No boards found',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new board to start drawing and collaborating in real time.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openBoardForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Board'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardCard(BuildContext context, BoardProvider boardProvider, Board board) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.dividerTheme.color ?? const Color(0xFFE9E9F2);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BoardWorkspaceScreen(board: board)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [primaryColor, secondaryColor]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 25),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      board.description.isEmpty ? 'No description' : board.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Board options',
                icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
                onSelected: (value) async {
                  if (value == 'edit') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BoardFormScreen(board: board)),
                    );
                  } else if (value == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Delete board?'),
                        content: const Text('Are you sure you want to delete this board?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && context.mounted) {
                      await boardProvider.deleteBoard(board.id);
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 19),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 19, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBoardForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BoardFormScreen()),
    );
  }
}
