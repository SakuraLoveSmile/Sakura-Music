import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../../data/db/app_database.dart';
import '../../../data/server_repository.dart';

class AddServerDialog extends ConsumerStatefulWidget {
  const AddServerDialog({
    this.serverToEdit,
    super.key,
  });

  final Server? serverToEdit;

  static Future<bool?> show(BuildContext context, {Server? serverToEdit}) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => AddServerDialog(serverToEdit: serverToEdit),
    );
  }

  @override
  ConsumerState<AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends ConsumerState<AddServerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  bool _testing = false;
  bool _saving = false;
  String? _statusMessage;
  bool _statusIsError = false;
  int _selectedProtocolIndex = 0;

  static const _protocols = <String>['Navidrome', 'Subsonic', 'OpenSubsonic', 'Emby'];

  @override
  void initState() {
    super.initState();
    final edit = widget.serverToEdit;
    _nameController = TextEditingController(text: edit?.name ?? '');
    _urlController = TextEditingController(text: edit?.baseUrl ?? '');
    _usernameController = TextEditingController(text: edit?.username ?? '');
    _passwordController = TextEditingController(text: edit?.password ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _testConnection({bool silentSuccess = false}) async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    setState(() {
      _testing = true;
      _statusMessage = null;
    });

    try {
      final client = SubsonicClient(
        baseUrl: _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      await client.ping();
      if (mounted) {
        if (!silentSuccess) {
          setState(() {
            _statusMessage = '连接成功！服务器通信正常。';
            _statusIsError = false;
          });
        }
      }
      return true;
    } on SubsonicException catch (error) {
      if (mounted) {
        setState(() {
          _statusMessage = '连接失败：${error.message}';
          _statusIsError = true;
        });
      }
      return false;
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusMessage = '连接失败：$error';
          _statusIsError = true;
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _saveServer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    try {
      final repository = ref.read(serverRepositoryProvider);
      final edit = widget.serverToEdit;

      if (edit == null) {
        final id = await repository.addServer(
          name: _nameController.text.trim(),
          baseUrl: _urlController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          ref.read(selectedServerIdProvider.notifier).state = id;
          Navigator.of(context).pop(true);
        }
      } else {
        final updated = await repository.updateServer(
          id: edit.id,
          name: _nameController.text.trim(),
          baseUrl: _urlController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
        if (!updated) {
          throw StateError('服务器不存在或已被删除');
        }
        if (mounted) {
          ref.read(selectedServerIdProvider.notifier).state = edit.id;
          Navigator.of(context).pop(true);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusMessage = '保存失败：$error';
          _statusIsError = true;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.serverToEdit != null;

    return Dialog(
      backgroundColor: const Color(0xFF1C1E24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A84FF).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.dns_rounded,
                          color: Color(0xFF0A84FF),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEditing ? '编辑伺服器' : '新增伺服器',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Protocol selection pills
                  const Text(
                    '伺服器協定',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List<Widget>.generate(_protocols.length, (index) {
                      final selected = _selectedProtocolIndex == index;
                      return ChoiceChip(
                        label: Text(_protocols[index]),
                        selected: selected,
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedProtocolIndex = index);
                          }
                        },
                        selectedColor: const Color(0xFF0A84FF),
                        backgroundColor: const Color(0xFF262933),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFF0A84FF)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),

                  // Server name input
                  _InputField(
                    controller: _nameController,
                    labelText: '伺服器名稱',
                    hintText: '如：我的 Navidrome',
                    prefixIcon: Icons.label_outline_rounded,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '請輸入伺服器名稱' : null,
                  ),
                  const SizedBox(height: 14),

                  // Server URL input
                  _InputField(
                    controller: _urlController,
                    labelText: '伺服器位址',
                    hintText: 'https://music.example.com',
                    prefixIcon: Icons.link_rounded,
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '請輸入伺服器位址';
                      }
                      final uri = Uri.tryParse(value.trim());
                      if (uri == null ||
                          (uri.scheme != 'http' && uri.scheme != 'https') ||
                          uri.host.isEmpty) {
                        return '請輸入有效的 http/https 位址';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Username input
                  _InputField(
                    controller: _usernameController,
                    labelText: '帳號 / 使用者名稱',
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '請輸入使用者名稱' : null,
                  ),
                  const SizedBox(height: 14),

                  // Password input
                  _InputField(
                    controller: _passwordController,
                    labelText: '密碼',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: true,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '請輸入密碼' : null,
                  ),

                  if (_statusMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _statusIsError
                            ? const Color(0xFFFF453A).withValues(alpha: 0.15)
                            : const Color(0xFF30D158).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _statusIsError
                              ? const Color(0xFFFF453A).withValues(alpha: 0.4)
                              : const Color(0xFF30D158).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            _statusIsError
                                ? Icons.error_outline_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: _statusIsError
                                ? const Color(0xFFFF453A)
                                : const Color(0xFF30D158),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                color: _statusIsError
                                    ? const Color(0xFFFF6961)
                                    : const Color(0xFF32D74B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testing || _saving ? null : () => _testConnection(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _testing
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white70,
                                  ),
                                )
                              : const Icon(Icons.wifi_tethering, size: 18),
                          label: const Text('測試連線'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _testing || _saving ? null : _saveServer,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0A84FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.cloud_done_rounded, size: 18),
                          label: Text(isEditing ? '儲存修改' : '儲存並連線'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        prefixIcon: Icon(prefixIcon, color: Colors.white60, size: 20),
        filled: true,
        fillColor: const Color(0xFF262933),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF0A84FF),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF453A)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF453A), width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}
