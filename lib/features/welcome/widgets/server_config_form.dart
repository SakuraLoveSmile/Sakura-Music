import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../../data/webdav/webdav_client.dart';

import '../../../data/db/app_database.dart';
import '../../../data/server_repository.dart';
import '../../../l10n/l10n.dart';
import 'server_url.dart';

/// A selectable server protocol shown on the add-server grid and as a config
/// form preset.
class ServerProtocolItem {
  const ServerProtocolItem({
    required this.id,
    required this.name,
    this.defaultPort = '4533',
    this.defaultPath = '',
    this.supported = false,
  });

  final String id;
  final String name;
  final String defaultPort;
  final String defaultPath;
  final bool supported;
}

/// The protocols offered on the new add-server grid. Only Navidrome and
/// Subsonic are currently connectable through the Subsonic client; the rest
/// show a "coming soon" hint.
const List<ServerProtocolItem> serverProtocols = <ServerProtocolItem>[
  ServerProtocolItem(
    id: 'navidrome',
    name: 'Navidrome',
    defaultPort: '4533',
    supported: true,
  ),
  ServerProtocolItem(
    id: 'subsonic',
    name: 'Subsonic',
    defaultPort: '4040',
    supported: true,
  ),
  ServerProtocolItem(id: 'plex', name: 'Plex', defaultPort: '32400'),
  ServerProtocolItem(id: 'jellyfin', name: 'Jellyfin', defaultPort: '8096'),
  ServerProtocolItem(id: 'emby', name: 'Emby', defaultPort: '8096'),
  ServerProtocolItem(
    id: 'audiostation',
    name: 'Audio Station',
    defaultPort: '5000',
  ),
  ServerProtocolItem(
    id: 'webdav',
    name: 'WebDAV',
    defaultPort: '80',
    supported: true,
  ),
];

/// Shared server-configuration form used by both the edit dialog (free mode,
/// no fixed protocol) and the full-screen add-server config page (a fixed
/// protocol that hides the type chips).
class ServerConfigForm extends ConsumerStatefulWidget {
  const ServerConfigForm({
    super.key,
    required this.protocols,
    this.fixedProtocol,
    this.serverToEdit,
    this.prefillHost,
    this.prefillPort,
    this.onSaved,
  });

  final List<ServerProtocolItem> protocols;
  final ServerProtocolItem? fixedProtocol;
  final Server? serverToEdit;
  final String? prefillHost;
  final String? prefillPort;
  final void Function(int serverId)? onSaved;

  @override
  ConsumerState<ServerConfigForm> createState() => _ServerConfigFormState();
}

class _ServerConfigFormState extends ConsumerState<ServerConfigForm> {
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

  @override
  void initState() {
    super.initState();
    final edit = widget.serverToEdit;
    _nameController = TextEditingController(text: edit?.name ?? '');
    final parts = edit == null ? null : decomposeBaseUrl(edit.baseUrl);
    _hostController = TextEditingController(
      text: widget.prefillHost ?? parts?.host ?? '',
    );
    final defaultPort =
        widget.fixedProtocol?.defaultPort ??
        widget.protocols.firstOrNull?.defaultPort ??
        '';
    _portController = TextEditingController(
      text: widget.prefillPort ?? parts?.port ?? defaultPort,
    );
    _usernameController = TextEditingController(text: edit?.username ?? '');
    _passwordController = TextEditingController(text: edit?.password ?? '');
    _scheme = parts?.scheme ?? 'https';
    if (edit?.type != null) {
      final index = widget.protocols.indexWhere(
        (protocol) => protocol.id == edit!.type,
      );
      if (index >= 0) {
        _selectedProtocolIndex = index;
      }
    }
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

  /// The protocol chosen by the fixed page or by the free-mode chips.
  ServerProtocolItem get _selectedProtocol =>
      widget.fixedProtocol ??
      widget.protocols[_selectedProtocolIndex.clamp(
        0,
        widget.protocols.length - 1,
      )];

  bool get _isWebDav => _selectedProtocol.id == 'webdav';

  String get _composedBaseUrl => composeBaseUrl(
    scheme: _scheme,
    host: _hostController.text,
    port: _portController.text,
  );

  void _selectProtocol(int index) {
    setState(() {
      final previousDefault =
          widget.protocols[_selectedProtocolIndex].defaultPort;
      final currentPort = _portController.text.trim();
      final nextDefault = widget.protocols[index].defaultPort;
      if (nextDefault.isNotEmpty &&
          (currentPort.isEmpty || currentPort == previousDefault)) {
        _portController.text = nextDefault;
      }
      _selectedProtocolIndex = index;
    });
  }

  void _handleHostChanged(String value) {
    final text = value.trim();
    if (text.contains('://') || (text.contains(':') && !text.contains(' '))) {
      final parts = decomposeBaseUrl(text);
      if (parts.host.isNotEmpty && parts.host != text) {
        setState(() {
          _scheme = parts.scheme;
          if (parts.port != null && parts.port!.isNotEmpty) {
            _portController.text = parts.port!;
          }
          _hostController.text = parts.host;
          _hostController.selection = TextSelection.collapsed(
            offset: parts.host.length,
          );
        });
      }
    }
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
      if (_isWebDav) {
        final client = WebDavClient(
          baseUrl: _composedBaseUrl,
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
        final reachable = await client.testConnection();
        if (!reachable) {
          throw Exception('WebDAV PROPFIND failed');
        }
      } else {
        final client = SubsonicClient(
          baseUrl: _composedBaseUrl,
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
        await client.ping();
      }
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
          type: _isWebDav ? 'webdav' : null,
        );
        if (mounted) {
          ref.read(selectedServerIdProvider.notifier).state = id;
          _finish(id);
        }
      } else {
        final updated = await repository.updateServer(
          id: edit.id,
          name: _nameController.text.trim(),
          baseUrl: _composedBaseUrl,
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          type: _isWebDav ? 'webdav' : null,
        );
        if (!updated) {
          throw StateError('服务器不存在或已被删除');
        }
        if (mounted) {
          ref.read(selectedServerIdProvider.notifier).state = edit.id;
          _finish(edit.id);
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

  void _finish(int serverId) {
    final onSaved = widget.onSaved;
    if (onSaved != null) {
      onSaved(serverId);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.serverToEdit != null;
    final fixed = widget.fixedProtocol;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (fixed != null) ...<Widget>[
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
                    fixed.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ] else ...<Widget>[
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
              children: List<Widget>.generate(widget.protocols.length, (index) {
                final selected = _selectedProtocolIndex == index;
                return ChoiceChip(
                  label: Text(widget.protocols[index].name),
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
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
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
          ],
          _InputField(
            controller: _nameController,
            labelText: context.l10n.serverName,
            hintText: context.l10n.serverNameHint,
            prefixIcon: Icons.label_outline_rounded,
            validator: (v) => v == null || v.trim().isEmpty
                ? context.l10n.pleaseInputServerName
                : null,
          ),
          _InputField(
            controller: _hostController,
            labelText: context.l10n.serverAddress,
            hintText: 'music.example.com',
            prefixIcon: Icons.link_rounded,
            keyboardType: TextInputType.url,
            onChanged: _handleHostChanged,
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
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 48,
                child: SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(value: 'https', label: Text('HTTPS')),
                    ButtonSegment<String>(value: 'http', label: Text('HTTP')),
                  ],
                  selected: <String>{_scheme},
                  onSelectionChanged: (selection) {
                    setState(() => _scheme = selection.first);
                  },
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      return states.contains(WidgetState.selected)
                          ? const Color(0xFF0A84FF)
                          : const Color(0xFF262933);
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      return states.contains(WidgetState.selected)
                          ? Colors.white
                          : Colors.white70;
                    }),
                    side: WidgetStatePropertyAll(
                      BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InputField(
                  controller: _portController,
                  labelText: context.l10n.portLabel,
                  hintText: _scheme == 'https' ? '443' : '80',
                  prefixIcon: Icons.tag_rounded,
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
          _InputField(
            controller: _usernameController,
            labelText: context.l10n.username,
            prefixIcon: Icons.person_outline_rounded,
            validator: (v) => v == null || v.trim().isEmpty
                ? context.l10n.pleaseInputUsername
                : null,
          ),
          const SizedBox(height: 14),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  onPressed: _testing || _saving
                      ? null
                      : () => _testConnection(),
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
    );
  }
}

/// Text field shared by the server config form and dialog.
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
    this.onChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0A84FF), width: 1.5),
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
