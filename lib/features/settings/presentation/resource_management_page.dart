import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_state.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/glass_panel_card.dart';

class ResourceManagementPage extends ConsumerWidget {
  const ResourceManagementPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.icon,
    required this.optionsProvider,
  });

  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptyDescription;
  final IconData icon;
  final StateProvider<List<ManagedOption>> optionsProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(optionsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      children: [
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(subtitle),
              const SizedBox(height: 12),
              PrimaryPillButton(
                label: '新建',
                onPressed: () => _openEditDialog(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (options.isEmpty)
          GlassPanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emptyTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  emptyDescription,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          )
        else
          ...options.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassPanelCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: '编辑',
                          onPressed: () => _openEditDialog(
                            context,
                            ref,
                            source: item,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: '删除',
                          onPressed: () => _deleteItem(context, ref, item),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.description),
                    const SizedBox(height: 6),
                    Text(
                      'id: ${item.id} · updated: ${_formatTime(item.updatedAt)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WidgetRef ref, {
    ManagedOption? source,
  }) async {
    final nameController = TextEditingController(text: source?.name ?? '');
    final descController = TextEditingController(text: source?.description ?? '');
    final isEdit = source != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? '编辑$title' : '新建$title'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '描述'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (saved != true) {
      return;
    }

    final name = nameController.text.trim();
    final description = descController.text.trim();
    if (name.isEmpty) {
      return;
    }

    final notifier = ref.read(optionsProvider.notifier);
    final current = notifier.state;
    if (isEdit) {
      notifier.state = current
          .map(
            (item) => item.id == source.id
                ? item.copyWith(
                    name: name,
                    description: description.isEmpty ? '无描述' : description,
                    updatedAt: DateTime.now(),
                  )
                : item,
          )
          .toList(growable: false);
      return;
    }

    final idBase = _slugify(name);
    final idSuffix = DateTime.now().millisecondsSinceEpoch.toString();
    final next = ManagedOption(
      id: '$idBase-$idSuffix',
      name: name,
      description: description.isEmpty ? '无描述' : description,
      updatedAt: DateTime.now(),
    );
    notifier.state = <ManagedOption>[next, ...current];
  }

  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    ManagedOption item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除$title'),
        content: Text('确定删除“${item.name}”？此操作不可撤销。'),
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
    if (confirmed != true) {
      return;
    }
    final notifier = ref.read(optionsProvider.notifier);
    notifier.state = notifier.state
        .where((element) => element.id != item.id)
        .toList(growable: false);
  }

  String _slugify(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(' ', '-');
    return normalized.replaceAll(RegExp(r'[^a-z0-9\-_]'), '');
  }

  String _formatTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}
