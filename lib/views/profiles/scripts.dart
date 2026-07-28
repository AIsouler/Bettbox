import 'dart:convert';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/pages/editor.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/card.dart';
import 'package:bett_box/widgets/dialog.dart';
import 'package:bett_box/widgets/icon.dart';
import 'package:bett_box/widgets/input.dart';
import 'package:bett_box/widgets/list.dart';
import 'package:bett_box/widgets/null_status.dart';
import 'package:bett_box/widgets/pop_scope.dart';
import 'package:bett_box/widgets/popup.dart';
import 'package:bett_box/widgets/scaffold.dart';
import 'package:bett_box/widgets/scroll.dart';
import 'package:bett_box/widgets/sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isExtractingCustomOptions = false;
const Duration _kMinLoadingDuration = Duration(seconds: 1);

(Map<String, bool>, Map<String, String>) _processScriptData(
  Map<String, dynamic> data,
  Script script,
) {
  final rawOptions = data['options'];
  final rawIcons = data['icons'];

  final options = <String, bool>{};
  if (rawOptions is Map) {
    rawOptions.forEach((k, v) {
      options[k.toString()] = v is bool ? v : true;
    });
  }
  if (script.customOptions != null) {
    script.customOptions!.forEach((k, v) {
      if (options.containsKey(k)) {
        options[k] = v;
      }
    });
  }

  final icons = <String, String>{};
  if (rawIcons is Map) {
    rawIcons.forEach((k, v) {
      if (v != null) {
        icons[k.toString()] = v.toString();
      }
    });
  }
  return (options, icons);
}

Future<void> showScriptCustomOptions(
  BuildContext context,
  WidgetRef ref, {
  required Script script,
}) async {
  if (_isExtractingCustomOptions) return;
  _isExtractingCustomOptions = true;
  try {
    await globalState.appController.safeRun(
      silence: false,
      needLoading: true,
      () async {
        final stopwatch = Stopwatch()..start();
        final cached = JavaScriptRuntimeManager.getCachedOptions(
          script.content,
        );
        final data = cached ??
            await JavaScriptRuntimeManager.extractScriptOptions(
              script.content,
            );
        final (options, icons) = _processScriptData(data, script);

        final remaining = _kMinLoadingDuration.inMilliseconds -
            stopwatch.elapsedMilliseconds;
        if (remaining > 0) {
          await Future.delayed(Duration(milliseconds: remaining));
        }

        if (!context.mounted) return;

        showExtend(
          context,
          builder: (_, type) {
            return _ScriptCustomOptionsSheet(
              type: type,
              script: script,
              initialOptions: options,
              icons: icons,
            );
          },
        );
      },
    );
  } finally {
    _isExtractingCustomOptions = false;
  }
}

class ScriptsView extends ConsumerStatefulWidget {
  const ScriptsView({super.key});

  @override
  ConsumerState<ScriptsView> createState() => _ScriptsViewState();
}

class _ScriptsViewState extends ConsumerState<ScriptsView> {
  Future<void> _handleDelScript(String label) async {
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.script),
      ),
    );
    if (res != true) {
      return;
    }
    ref.read(scriptStateProvider.notifier).del(label);
  }

  Future<void> _handleSyncScript(String id) async {
    await globalState.appController.safeRun(
      silence: false,
      () async {
        await ref.read(scriptStateProvider.notifier).syncScript(id);
        globalState.showNotifier(appLocalizations.success);
      },
    );
  }

  Future<void> _handleCustomOptions(Script script) async {
    await showScriptCustomOptions(context, ref, script: script);
  }

  void _handleShowScriptSettings() {
    showSheet(
      context: context,
      builder: (_, type) {
        return _ScriptSettingsSheet(type: type);
      },
    );
  }

  Widget _buildContent() {
    return Consumer(
      builder: (_, ref, _) {
        final vm2 = ref.watch(
          scriptStateProvider.select(
            (state) => VM2(a: state.currentId, b: state.scripts),
          ),
        );
        final currentId = vm2.a;
        final scripts = vm2.b;
        if (scripts.isEmpty) {
          return NullStatus(
            label: appLocalizations.nullTip(appLocalizations.script),
          );
        }
        return CommonScrollBar(
          controller: null,
          child: ListView.builder(
            padding: kMaterialListPadding.copyWith(bottom: 16 + 64),
            itemCount: scripts.length,
            itemBuilder: (_, index) {
              final script = scripts[index];
              final isSelected = script.id == currentId;
              return Container(
                padding: kTabLabelPadding,
                margin: EdgeInsets.symmetric(vertical: 6),
                child: CommonCard(
                  type: CommonCardType.filled,
                  radius: 16,
                  child: ListItem(
                    padding: const EdgeInsets.only(left: 12, right: 12),
                    title: Text(script.label),
                    leading: Switch(
                      value: isSelected,
                      onChanged: (value) {
                        if (value) {
                          ref.read(scriptStateProvider.notifier).setId(script.id);
                        } else if (isSelected) {
                          ref.read(scriptStateProvider.notifier).setId(script.id);
                        }
                      },
                    ),
                    trailing: CommonPopupBox(
                      targetBuilder: (open) {
                        return IconButton(
                          onPressed: () {
                            open();
                          },
                          icon: Icon(Icons.more_vert),
                        );
                      },
                      popup: CommonPopupMenu(
                        items: [
                          PopupMenuItemData(
                            icon: Icons.edit,
                            label: appLocalizations.edit,
                            onPressed: () {
                              _handleToEditor(script: script);
                            },
                          ),
                          if (script.isCompatibleWithBettbox)
                            PopupMenuItemData(
                              icon: Icons.tune,
                              label: appLocalizations.custom,
                              onPressed: () {
                                _handleCustomOptions(script);
                              },
                            ),
                          if (script.url != null && script.url!.isNotEmpty)
                            PopupMenuItemData(
                              icon: Icons.sync,
                              label: appLocalizations.sync,
                              onPressed: () {
                                _handleSyncScript(script.id);
                              },
                            ),
                          PopupMenuItemData(
                            icon: Icons.delete,
                            label: appLocalizations.delete,
                            onPressed: () {
                              _handleDelScript(script.label);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleEditorSave(
    BuildContext _,
    String title,
    String content, {
    Script? script,
    String? url,
  }) async {
    if (script != null && script.content != content) {
      JavaScriptRuntimeManager.invalidateCachedOptions(script.content);
    }
    Script newScript =
        script?.copyWith(label: title, content: content, url: url) ??
        Script.create(label: title, content: content, url: url);
    if (newScript.label.isEmpty) {
      final res = await globalState.showCommonDialog<String>(
        child: InputDialog(
          title: appLocalizations.save,
          value: '',
          hintText: appLocalizations.pleaseEnterScriptName,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return appLocalizations.emptyTip(appLocalizations.name);
            }
            if (value != script?.label) {
              final isExits = ref
                  .read(scriptStateProvider.notifier)
                  .isExits(value);
              if (isExits) {
                return appLocalizations.existsTip(appLocalizations.name);
              }
            }
            return null;
          },
        ),
      );
      if (res == null || res.isEmpty) {
        return;
      }
      newScript = newScript.copyWith(label: res);
    }
    if (newScript.label != script?.label) {
      final isExits = ref
          .read(scriptStateProvider.notifier)
          .isExits(newScript.label);
      if (isExits) {
        globalState.showMessage(
          message: TextSpan(
            text: appLocalizations.existsTip(appLocalizations.name),
          ),
          cancelable: false,
        );
        return;
      }
    }
    ref.read(scriptStateProvider.notifier).setScript(newScript);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _handleEditorPop(
    BuildContext _,
    String title,
    String content,
    String raw, {
    Script? script,
  }) async {
    if (content == raw) {
      return true;
    }
    final res = await globalState.showMessage(
      message: TextSpan(text: appLocalizations.saveChanges),
    );
    if (res == true && mounted) {
      _handleEditorSave(context, title, content, script: script, url: script?.url);
    } else {
      return true;
    }
    return false;
  }

  void _handleToEditor({Script? script, String? initialContent, String? url, bool delayedFocus = false}) {
    final title = script?.label ?? '';
    final raw = script?.content ?? initialContent ?? scriptTemplate;
    String? importedUrl = url ?? script?.url;
    BaseNavigator.push(
      context,
      EditorPage(
        titleEditable: true,
        title: title,
        supportRemoteDownload: true,
        delayedFocus: delayedFocus,
        onUrlImport: (downloadedUrl) {
          importedUrl = downloadedUrl;
        },
        onSave: (context, title, content) {
          final scriptToSave = script != null
              ? script.copyWith(url: importedUrl)
              : null;
          _handleEditorSave(context, title, content, script: scriptToSave, url: importedUrl);
        },
        onPop: (context, title, content) {
          return _handleEditorPop(context, title, content, raw, script: script);
        },
        languages: const [Language.javaScript],
        content: raw,
      ),
    );
  }

  Future<void> _handleImport() async {
    final option = await globalState.showCommonDialog<ImportOption>(
      child: const _ScriptImportOptionsDialog(),
    );
    if (option == null) {
      return;
    }

    switch (option) {
      case ImportOption.code:
        _handleToEditor(delayedFocus: true);
      case ImportOption.url:
        await _handleUrlImport();
      case ImportOption.file:
        await _handleFileImport();
    }
  }

  Future<void> _handleUrlImport() async {
    final url = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.importUrl,
        value: '',
        labelText: appLocalizations.url,
        delayedFocus: true,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip(appLocalizations.value);
          }
          if (!value.isUrl) {
            return appLocalizations.urlTip(appLocalizations.value);
          }
          return null;
        },
      ),
    );
    if (url == null || url.isEmpty) {
      return;
    }

    try {
      final res = await request.getTextResponseForUrl(url);
      if (mounted) {
        _handleToEditor(initialContent: res.data, url: url);
      }
    } catch (e) {
      globalState.showMessage(
        message: TextSpan(text: '${appLocalizations.importFailed}: $e'),
        cancelable: false,
      );
    }
  }

  Future<void> _handleFileImport() async {
    final file = await picker.pickerFile();
    if (file == null) {
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      return;
    }
    final content = utf8.decode(bytes);
    if (mounted) {
      _handleToEditor(initialContent: content);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _handleImport();
        },
        child: Icon(Icons.add),
      ),
      actions: [
        IconButton(
          onPressed: _handleShowScriptSettings,
          icon: Icon(Icons.settings),
        ),
      ],
      body: _buildContent(),
      title: appLocalizations.script,
    );
  }
}

class _ScriptSettingsSheet extends ConsumerWidget {
  final SheetType type;

  const _ScriptSettingsSheet({
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final currentProfileId = ref.watch(currentProfileIdProvider);
    return AdaptiveSheetScaffold(
      type: type,
      body: profiles.isEmpty
          ? NullStatus(label: appLocalizations.nullProfileDesc)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: profiles.length,
              itemBuilder: (_, index) {
                final profile = profiles[index];
                final isCurrentProfile = profile.id == currentProfileId;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: CommonCard(
                    type: CommonCardType.filled,
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(left: 16, right: 16),
                      title: Text(profile.label ?? profile.id),
                      trailing: Switch(
                        value: profile.useScriptOverride,
                        onChanged: (value) async {
                          ref.read(profilesProvider.notifier).updateProfile(
                            profile.id,
                            (p) => p.copyWith(useScriptOverride: value),
                          );
                          if (isCurrentProfile) {
                            await globalState.appController.applyProfile(silence: true);
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
      title: appLocalizations.useGlobalScriptOverride,
    );
  }
}

class _ScriptImportOptionsDialog extends StatelessWidget {
  const _ScriptImportOptionsDialog();

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: appLocalizations.import,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Wrap(
        children: [
          ListItem(
            onTap: () {
              Navigator.of(context).pop(ImportOption.code);
            },
            leading: const Icon(Icons.code),
            title: Text(appLocalizations.importFromCode),
          ),
          ListItem(
            onTap: () {
              Navigator.of(context).pop(ImportOption.url);
            },
            leading: const Icon(Icons.link),
            title: Text(appLocalizations.importUrl),
          ),
          ListItem(
            onTap: () {
              Navigator.of(context).pop(ImportOption.file);
            },
            leading: const Icon(Icons.file_open),
            title: Text(appLocalizations.importFile),
          ),
        ],
      ),
    );
  }
}

class _ScriptCustomOptionsSheet extends ConsumerStatefulWidget {
  final SheetType type;
  final Script script;
  final Map<String, bool> initialOptions;
  final Map<String, String> icons;

  const _ScriptCustomOptionsSheet({
    required this.type,
    required this.script,
    required this.initialOptions,
    required this.icons,
  });

  @override
  ConsumerState<_ScriptCustomOptionsSheet> createState() =>
      __ScriptCustomOptionsSheetState();
}

class __ScriptCustomOptionsSheetState
    extends ConsumerState<_ScriptCustomOptionsSheet> {
  late Map<String, bool> _options;
  bool _dirty = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _options = Map<String, bool>.from(widget.initialOptions);
  }

  bool get _hasUnsavedChanges => _dirty;

  Future<void> _handleSave() async {
    if (_isSaving) return;
    final scripts = ref.read(scriptStateProvider).scripts;
    final index = scripts.indexWhere((item) => item.id == widget.script.id);
    if (index == -1) {
      _dirty = false;
      if (mounted) setState(() {});
      return;
    }
    final currentScript = scripts[index];
    final updatedScript = currentScript.copyWith(
      customOptions: Map<String, bool>.from(_options),
    );
    ref.read(scriptStateProvider.notifier).setScript(updatedScript);
    _dirty = false;
    if (mounted) setState(() => _isSaving = true);
    final applyFuture = ref.read(scriptStateProvider).currentId == widget.script.id
        ? globalState.appController.applyProfile(silence: true)
        : Future.value();
    await Future.wait([
      applyFuture,
      Future.delayed(_kMinLoadingDuration),
    ]);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleSort() async {
    final result = await showSheet<List<String>>(
      context: context,
      builder: (_, type) {
        return _ReorderableKeysSheet(
          type: type,
          keys: _options.keys.toList(),
          icons: widget.icons,
        );
      },
    );
    if (result == null) return;
    final newOptions = <String, bool>{};
    for (final key in result) {
      newOptions[key] = _options[key] ?? true;
    }
    setState(() {
      _options = newOptions;
      _dirty = true;
    });
  }

  void _onOptionChanged(String key, bool value) {
    setState(() {
      _options[key] = value;
      _dirty = true;
    });
  }

  Future<bool> _confirmDiscard() async {
    if (_isSaving) return false;
    if (!_hasUnsavedChanges) return true;
    final res = await globalState.showCommonDialog<bool>(
      child: CommonDialog(
        title: appLocalizations.saveChanges,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop<bool>(true),
            child: Text(appLocalizations.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop<bool>(true);
              await _handleSave();
            },
            child: Text(appLocalizations.save),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  bool _isValidIconUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:image/');
  }

  @override
  Widget build(BuildContext context) {
    final keys = _options.keys.toList();
    return CommonPopScope(
      onPop: _confirmDiscard,
      child: AbsorbPointer(
        absorbing: _isSaving,
        child: AdaptiveSheetScaffold(
          type: widget.type,
          title: appLocalizations.customScriptOptions,
          actions: [
            IconButton(
              onPressed: _isSaving ? null : _handleSort,
              icon: const Icon(Icons.sort),
              iconSize: 26,
              tooltip: appLocalizations.profilesSort,
            ),
            IconButton(
              onPressed: (_dirty && !_isSaving) ? _handleSave : null,
              icon: const Icon(Icons.save),
              tooltip: appLocalizations.save,
            ),
          ],
          body: Column(
            children: [
              if (_isSaving)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: context.colorScheme.primary,
                ),
              Expanded(
                child: keys.isEmpty
                    ? NullStatus(label: appLocalizations.noStatusAvailable)
                    : RepaintBoundary(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          itemCount: keys.length,
                          itemBuilder: (_, index) {
                            final key = keys[index];
                            final val = _options[key] ?? true;
                            final iconUrl = widget.icons[key];
                            return RepaintBoundary(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: CommonCard(
                                  type: CommonCardType.filled,
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.only(left: 16, right: 16),
                                    leading: _isValidIconUrl(iconUrl)
                                        ? CommonTargetIcon(src: iconUrl!, size: 24)
                                        : const Icon(Icons.alt_route),
                                    title: Text(key),
                                    trailing: Switch(
                                      value: val,
                                      onChanged: (v) {
                                        _onOptionChanged(key, v);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReorderableKeysSheet extends StatefulWidget {
  final SheetType type;
  final List<String> keys;
  final Map<String, String> icons;

  const _ReorderableKeysSheet({
    required this.type,
    required this.keys,
    required this.icons,
  });

  @override
  State<_ReorderableKeysSheet> createState() => _ReorderableKeysSheetState();
}

class _ReorderableKeysSheetState extends State<_ReorderableKeysSheet> {
  late List<String> keys;

  @override
  void initState() {
    super.initState();
    keys = List.from(widget.keys);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveSheetScaffold(
      type: widget.type,
      actions: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(keys),
          icon: const Icon(Icons.save),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.only(bottom: 32, top: 16),
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          // ignore: deprecated_member_use
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) newIndex -= 1;
              final key = keys.removeAt(oldIndex);
              keys.insert(newIndex, key);
            });
          },
          itemBuilder: (_, index) {
            final key = keys[index];
            final iconUrl = widget.icons[key];
            return Container(
              key: Key(key),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: CommonCard(
                type: CommonCardType.filled,
                child: ListTile(
                  contentPadding: const EdgeInsets.only(right: 16, left: 16),
                  leading: iconUrl != null && iconUrl.isNotEmpty
                      ? CommonTargetIcon(src: iconUrl, size: 24)
                      : const Icon(Icons.alt_route),
                  title: Text(key),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                ),
              ),
            );
          },
          itemCount: keys.length,
        ),
      ),
      title: appLocalizations.profilesSort,
    );
  }
}
