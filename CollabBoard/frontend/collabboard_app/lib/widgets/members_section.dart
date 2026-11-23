import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/board_member.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/board_provider.dart';

class MembersSection extends StatefulWidget {
  final int boardId;
  const MembersSection({super.key, required this.boardId});

  @override
  State<MembersSection> createState() => _MembersSectionState();
}

class _MembersSectionState extends State<MembersSection> {
  final ApiService _api = ApiService();
  List<BoardMember> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final token = Provider.of<BoardProvider>(context, listen: false).getAuthToken?.call();
      final resp = await _api.getMembers(widget.boardId, token!);
      final List data = resp.data as List;
      _members = data.map((json) => BoardMember.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _error = e.response?.data['message'] ?? e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.red));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _members.map((m) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Chip(
              avatar: CircleAvatar(child: Text(m.name[0].toUpperCase())),
              label: Text('${m.name} (${m.role})'),
              backgroundColor: m.role == 'owner'
                  ? Colors.orange[200]
                  : m.role == 'editor'
                      ? Colors.green[200]
                      : Colors.blue[200],
            ),
          );
        }).toList(),
      ),
    );
  }
}
