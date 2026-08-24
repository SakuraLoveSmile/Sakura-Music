import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../../data/db/app_database.dart';
import '../../../data/server_repository.dart';
import '../../../l10n/l10n.dart';
import 'server_url.dart';

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
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  bool _testing = false;
  bool _saving = false;
  String? _statusMessage;
  bool _statusIsError = false;
  int _selectedProtocolIndex = 0;
  String _scheme = 'https';

  static const _protocols = <String>['Navidrome', 'Subsonic', 'OpenSubsonic', 'Emby'];

  @override
  void initState() {
    super.initState();
    final edit = widget.serverToEdit;
    _nameController = TextEditingController(text: edit?.name ?? '');
    final parts = edit == null
        ? null
        : decomposeBaseUrl(edit.baseUrl);
    _hostController = TextEditingController(text: parts?.host ?? '');
    _portController = TextEditingController(text: parts?.port ?? '');
    _usernameController = TextEditingController(text: edit?.username ?? '');
    _passwordController = TextEditingController(text: edit?.password ?? '');
    _scheme = parts?.scheme ?? 'https';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _composedBaseUrl => composeBaseUrl(
    scheme: _scheme,
    host: _hostController.text,
    port: _portController.text,
  );

  void _selectProtocol(int index) {
    setState(() {
      final previousDefault =
          serverTypeDefaultPorts[_protocols[_selectedProtocolIndex]];
      final currentPort = _portController.text.trim();
      final nextDefault = serverTypeDefaultPorts[_protocols[index]];
      // Only prefill when the user left the port empty or kept the previous
      // type's default; a custom port must survive type switches.
      if (nextDefault != null &&
          (currentPort.isEmpty || currentPort == previousDefault)) {
        _portController.text = nextDefault;
      }
      _selectedProtocolIndex = index;
    });
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
        baseUrl: _composedBaseUrl,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      await client.ping();
      if (mounted) {
        if (!silentSuccess) {
          setState(() {
            _statusMessage = context.l10n.connectSuccess;
            _statusIsError = false;
          });
        }
      }
      return true;
    } on SubsonicException catch (error) {
      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.connectFailed(error.message);
          _statusIsError = true;
        });
      }
      return false;
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.connectFailed(error.toString());
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
          baseUrl: _composedBaseUrl,
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
          baseUrl: _composedBaseUrl,
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
          _statusMessage = context.l10n.saveFailed(error.toString());
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
                          isEditing
                              ? context.l10n.editServer
                              : context.l10n.addServer,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        tooltip: context.l10n.close,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Server type pills
                  Text(
                    context.l10n.serverType,
                    style: const TextStyle(
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
                            _selectProtocol(index);
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
                    labelText: context.l10n.serverName,
                    hintText: context.l10n.serverNameHint,
                    prefixIcon: Icons.label_outline_rounded,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? context.l10n.pleaseInputServerName
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // Split address: scheme + host + port
                  Text(
                    context.l10n.serverAddress,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SegmentedButton<String>(
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment<String>(
                              value: 'https',
                              label: Text('HTTPS'),
                            ),
                            ButtonSegment<String>(
                              value: 'http',
                              label: Text('HTTP'),
                            ),
                          ],
                          selected: <String>{_scheme},
                          onSelectionChanged: (selection) {
                            // Switching schemes never touches the port field.
                            setState(() => _scheme = selection.first);
                          },
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              return states.contains(WidgetState.selected)
                                  ? const Color(0xFF0A84FF)
                                  : const Color(0xFF262933);
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              return states.contains(WidgetState.selected)
                                  ? Colors.white
                                  : Colors.white70;
                            }),
                            side: WidgetStatePropertyAll(
                              BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            textStyle: const WidgetStatePropertyAll(
                              TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 10, vertical: 22),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _InputField(
                          controller: _hostController,
                          labelText: context.l10n.hostLabel,
                          hintText: 'music.example.com',
                          prefixIcon: Icons.link_rounded,
                          keyboardType: TextInputType.url,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return context.l10n.pleaseInputServerAddress;
                            }
                            if (text.contains('://')) {
                              return context.l10n.hostNoScheme;
                            }
                            if (text.contains(':')) {
                              return context.l10n.portInRightField;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 88,
                        child: _InputField(
                          controller: _portController,
                          labelText: context.l10n.portLabel,
                          hintText: _scheme == 'https' ? '443' : '80',
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return null;
                            }
                            final port = int.tryParse(text);
                            if (port == null || port < 1 || port > 65535) {
                              return context.l10n.portRange;
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Username input
                  _InputField(
                    controller: _usernameController,
                    labelText: context.l10n.username,
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? context.l10n.pleaseInputUsername
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // Password input
                  _InputField(
                    controller: _passwordController,
                    labelText: context.l10n.password,
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: true,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? context.l10n.pleaseInputPassword
                        : null,
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
                          label: Text(context.l10n.testConnection),
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
                          label: Text(
                            isEditing
                                ? context.l10n.saveChanges
                                : context.l10n.saveAndConnect,
                          ),
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
    this.prefixIcon,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: Colors.white60, size: 20),
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
