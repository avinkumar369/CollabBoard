import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/board.dart';
import '../providers/board_provider.dart';
import 'board_workspace_screen.dart';

class BoardFormScreen extends StatefulWidget {
  final Board? board;
  const BoardFormScreen({super.key, this.board});

  @override
  State<BoardFormScreen> createState() => _BoardFormScreenState();
}

class _BoardFormScreenState extends State<BoardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _description;
  String _selectedTemplate = 'Blank Canvas';

  final List<String> _templates = [
    'Blank Canvas',
    'Brainstorming & Ideas',
    'Flowchart & Process',
    'Agile Kanban',
  ];

  @override
  void initState() {
    super.initState();
    _title = widget.board?.title ?? '';
    _description = widget.board?.description ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.board != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Board' : 'Create New Board'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEdit ? 'Update Board Details' : 'Set up your collaborative workspace',
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(
                  labelText: 'Board Title',
                  prefixIcon: Icon(Icons.dashboard_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Title is required' : null,
                onSaved: (value) => _title = value!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                onSaved: (value) => _description = value!.trim(),
                maxLines: 3,
              ),
              if (!isEdit) ...[
                const SizedBox(height: 24),
                const Text('Choose Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTemplate,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.auto_awesome_outlined),
                  ),
                  items: _templates.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _selectedTemplate = v ?? 'Blank Canvas'),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: Icon(isEdit ? Icons.save : Icons.add_circle_outline),
                label: Text(isEdit ? 'Update Board' : 'Create & Open Workspace'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B4BDB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    final fullDesc = widget.board == null && _selectedTemplate != 'Blank Canvas'
        ? '$_description [Template: $_selectedTemplate]'
        : _description;

    final boardProvider = Provider.of<BoardProvider>(context, listen: false);

    if (widget.board == null) {
      final newBoard = await boardProvider.createBoard(_title, fullDesc);
      if (newBoard != null && mounted) {
        Navigator.of(context).pop(); // pop form screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BoardWorkspaceScreen(board: newBoard)),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(boardProvider.errorMessage ?? 'Creation failed')),
        );
      }
    } else {
      final success = await boardProvider.updateBoard(widget.board!.id, _title, fullDesc);
      if (success && mounted) {
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(boardProvider.errorMessage ?? 'Update failed')),
        );
      }
    }
  }
}
