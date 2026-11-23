import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import '../models/board.dart';
import '../services/api_service.dart';
import '../providers/board_provider.dart';

class ShareDialog extends StatefulWidget {
  final Board board;
  const ShareDialog({super.key, required this.board});

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  final ApiService _api = ApiService();
  String? _invitationLink;
  String? _invitationCode;
  DateTime? _expiryDate;
  String _role = 'viewer';
  bool _isLoading = false;
  String? _error;

  Future<void> _createInvitation() async {
    setState(() => _isLoading = true);
    try {
      final token = Provider.of<BoardProvider>(context, listen: false).getAuthToken?.call();
      final resp = await _api.createInvitation(
        widget.board.id,
        {
          'expiresInSec': 7 * 24 * 60 * 60, // 7 days default
          'maxUses': 1,
          'role': _role,
        },
        token!,
      );
      final data = resp.data as Map<String, dynamic>;
      setState(() {
        _invitationLink = data['link'] as String?;
        _invitationCode = data['token'] as String?;
        _expiryDate = DateTime.parse(data['expiresAt'] as String);
      });
    } on DioException catch (e) {
      setState(() => _error = e.response?.data['message'] ?? e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _revokeInvitation() async {
    if (_invitationCode == null) return;
    setState(() => _isLoading = true);
    try {
      final token = Provider.of<BoardProvider>(context, listen: false).getAuthToken?.call();
      await _api.revokeInvitation(widget.board.id, _invitationCode!, token!);
      setState(() {
        _invitationLink = null;
        _invitationCode = null;
        _expiryDate = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation revoked')));
    } on DioException catch (e) {
      setState(() => _error = e.response?.data['message'] ?? e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _createInvitation();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Share "${widget.board.title}"'),
      content: _isLoading
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? Text(_error!, style: const TextStyle(color: Colors.red))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_invitationLink != null) ...[
                      const Text('Invitation Link:'),
                      SelectableText(_invitationLink!),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _invitationLink!));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                            },
                            child: const Text('Copy Link'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              // Native share – placeholder (requires share_plus) but we just copy for now.
                              Clipboard.setData(ClipboardData(text: _invitationLink!));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied for sharing')));
                            },
                            child: const Text('Share'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_invitationCode != null) ...[
                      const Text('Invitation Code:'),
                      SelectableText(_invitationCode!),
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _invitationCode!));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                        },
                        child: const Text('Copy Code'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Text('Role granted to invitees:'),
                    DropdownButton<String>(
                      value: _role,
                      items: const [
                        DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                        DropdownMenuItem(value: 'editor', child: Text('Editor')),
                      ],
                      onChanged: (v) => setState(() => _role = v ?? 'viewer'),
                    ),
                    const SizedBox(height: 8),
                    Text('Expires: ${_expiryDate?.toLocal().toString().split('.').first ?? '—'}'),
                    const SizedBox(height: 8),
                    if (_invitationCode != null)
                      ElevatedButton(
                        onPressed: _revokeInvitation,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Revoke Invitation'),
                      ),
                  ],
                ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
