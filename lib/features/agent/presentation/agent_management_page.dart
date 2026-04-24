import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/agent/character_runtime_state.dart';
import '../../../core/models/agent/scene_model.dart';
import '../../../core/services/workspace_path_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/theme_tokens.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/glass_panel_card.dart';
import 'agent_character_editor_page.dart';
import 'agent_scene_editor_page.dart';

const String _agentDataDir = 'agent';

Future<Directory> _workspaceDir() async {
  return WorkspacePathService.resolveWorkspaceDirectory();
}

class AgentManagementPage extends ConsumerWidget {
  const AgentManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = Theme.of(context).extension<AppUiTheme>() ?? AppUiTheme.fallback(brightness: Brightness.dark);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: TabBar(
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ui.textStrong,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ui.textSecondary,
              ),
              labelColor: ui.textStrong,
              unselectedLabelColor: ui.textSecondary,
              indicatorColor: ui.primary,
              indicatorWeight: 2,
              dividerColor: ui.border,
              tabs: const [
                Tab(text: '角色档案'),
                Tab(text: '场景设定'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CharacterListTab(),
                _SceneListTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterListTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CharacterListTab> createState() => _CharacterListTabState();
}

class _CharacterListTabState extends ConsumerState<_CharacterListTab> {
  List<CharacterRuntimeState> _characters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    final dir = Directory(p.join((await _workspaceDir()).path, _agentDataDir, 'characters'));
    if (!await dir.exists()) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final characters = <CharacterRuntimeState>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          characters.add(CharacterRuntimeState.fromJson(json));
        } catch (_) {}
      }
    }

    setState(() {
      _characters = characters;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            PrimaryPillButton(
              label: '新建角色',
              onPressed: () => _createCharacter(context),
            ),
            const SizedBox(width: 8),
            SecondaryOutlineButton(
              label: '刷新',
              onPressed: _loadCharacters,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_characters.isEmpty)
          EmptyStateView(
            title: '暂无角色档案',
            description: '点击"新建角色"创建Agent模式下的角色',
            actionLabel: '新建角色',
            onAction: () => _createCharacter(context),
          )
        else
          ..._characters.map((character) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CharacterCard(
                  character: character,
                  onEdit: () => _editCharacter(context, character),
                  onDelete: () => _deleteCharacter(character),
                ),
              )),
      ],
    );
  }

  Future<void> _createCharacter(BuildContext context) async {
    final saved = await Navigator.of(context).push<CharacterRuntimeState>(
      MaterialPageRoute<CharacterRuntimeState>(
        fullscreenDialog: true,
        builder: (_) => const AgentCharacterEditorPage(),
      ),
    );
    if (saved == null) return;
    await _saveCharacter(saved);
    await _loadCharacters();
  }

  Future<void> _editCharacter(
      BuildContext context, CharacterRuntimeState character) async {
    final saved = await Navigator.of(context).push<CharacterRuntimeState>(
      MaterialPageRoute<CharacterRuntimeState>(
        fullscreenDialog: true,
        builder: (_) => AgentCharacterEditorPage(initialState: character),
      ),
    );
    if (saved == null) return;
    await _saveCharacter(saved);
    await _loadCharacters();
  }

  Future<void> _saveCharacter(CharacterRuntimeState state) async {
    final dir = Directory(p.join((await _workspaceDir()).path, _agentDataDir, 'characters'));
    await dir.create(recursive: true);

    final file = File(p.join(dir.path, '${state.characterId}.json'));
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(state.toJson()));
  }

  Future<void> _deleteCharacter(CharacterRuntimeState character) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => AlertDialog(
        title: const Text('删除角色'),
        content: Text('确定删除角色"${character.characterId}"？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final file = File(p.join(
        (await _workspaceDir()).path, _agentDataDir, 'characters', '${character.characterId}.json'));
    if (await file.exists()) {
      await file.delete();
    }
    await _loadCharacters();
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.onEdit,
    required this.onDelete,
  });

  final CharacterRuntimeState character;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassPanelCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.characterId,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '物种: ${character.baselineBodyProfile.species} · '
                  '特质: ${character.profile.traits.length} · '
                  '目标: ${character.currentGoals.shortTerm.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '编辑',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneListTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SceneListTab> createState() => _SceneListTabState();
}

class _SceneListTabState extends ConsumerState<_SceneListTab> {
  List<SceneModel> _scenes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadScenes();
  }

  Future<void> _loadScenes() async {
    final dir = Directory(p.join((await _workspaceDir()).path, _agentDataDir, 'scenes'));
    if (!await dir.exists()) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final scenes = <SceneModel>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          scenes.add(SceneModel.fromJson(json));
        } catch (_) {}
      }
    }

    setState(() {
      _scenes = scenes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            PrimaryPillButton(
              label: '新建场景',
              onPressed: () => _createScene(context),
            ),
            const SizedBox(width: 8),
            SecondaryOutlineButton(
              label: '刷新',
              onPressed: _loadScenes,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_scenes.isEmpty)
          EmptyStateView(
            title: '暂无场景设定',
            description: '点击"新建场景"创建Agent模式下的场景',
            actionLabel: '新建场景',
            onAction: () => _createScene(context),
          )
        else
          ..._scenes.map((scene) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SceneCard(
                  scene: scene,
                  onEdit: () => _editScene(context, scene),
                  onDelete: () => _deleteScene(scene),
                ),
              )),
      ],
    );
  }

  Future<void> _createScene(BuildContext context) async {
    final saved = await Navigator.of(context).push<SceneModel>(
      MaterialPageRoute<SceneModel>(
        fullscreenDialog: true,
        builder: (_) => const AgentSceneEditorPage(),
      ),
    );
    if (saved == null) return;
    await _saveScene(saved);
    await _loadScenes();
  }

  Future<void> _editScene(BuildContext context, SceneModel scene) async {
    final saved = await Navigator.of(context).push<SceneModel>(
      MaterialPageRoute<SceneModel>(
        fullscreenDialog: true,
        builder: (_) => AgentSceneEditorPage(initialScene: scene),
      ),
    );
    if (saved == null) return;
    await _saveScene(saved);
    await _loadScenes();
  }

  Future<void> _saveScene(SceneModel scene) async {
    final dir = Directory(p.join((await _workspaceDir()).path, _agentDataDir, 'scenes'));
    await dir.create(recursive: true);

    final file = File(p.join(dir.path, '${scene.sceneId}.json'));
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(scene.toJson()));
  }

  Future<void> _deleteScene(SceneModel scene) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => AlertDialog(
        title: const Text('删除场景'),
        content: Text('确定删除场景"${scene.sceneId}"？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final file = File(
        p.join((await _workspaceDir()).path, _agentDataDir, 'scenes', '${scene.sceneId}.json'));
    if (await file.exists()) {
      await file.delete();
    }
    await _loadScenes();
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.scene,
    required this.onEdit,
    required this.onDelete,
  });

  final SceneModel scene;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassPanelCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scene.sceneId,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '类型: ${scene.spatialLayout.sceneType.label} · '
                  '光照: ${scene.lighting.overallLevel.label} · '
                  '实体: ${scene.entities.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '编辑',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
