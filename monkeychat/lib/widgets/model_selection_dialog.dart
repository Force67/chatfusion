import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:monkeychat/services/ai_provider.dart';
import '../services/settings_service.dart';
import '../services/ai_provider_or.dart';
import '../models/llm_model.dart';

class ModelSelectionDialog extends StatefulWidget {
  final SettingsService settingsService;
  final AIProvider modelService;
  final Function(LLMModel) onModelSelected;

  const ModelSelectionDialog({
    super.key,
    required this.settingsService,
    required this.modelService,
    required this.onModelSelected,
  });

  @override
  State<ModelSelectionDialog> createState() => _ModelSelectionDialogState();
}

class _ModelSelectionDialogState extends State<ModelSelectionDialog> {
  late Future<List<LLMModel>> _modelsFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _modelsFuture = widget.modelService.getModels();
  }

  void _refreshModels() async {
    setState(() {
      _modelsFuture = widget.modelService.getModels(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Column(
          children: [
            AppBar(
              title: const Text('Select Model'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _refreshModels();
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search models...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<LLMModel>>(
                future: _modelsFuture,
                builder: (context, modelsSnapshot) {
                  if (!modelsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final models = modelsSnapshot.data!;

                  return FutureBuilder<Set<String>>(
                    future: widget.settingsService.getPinnedModels(),
                    builder: (context, pinnedSnapshot) {
                      if (!pinnedSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final pinnedModelIds = pinnedSnapshot.data!;

                      return _buildModelList(models, pinnedModelIds);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelList(List<LLMModel> models, Set<String> pinnedModelIds) {
    final filteredPinned = models
        .where((model) =>
            pinnedModelIds.contains(model.id) &&
            (model.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                model.provider
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                model.description
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase())))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final filteredOthers = models
        .where((model) =>
            !pinnedModelIds.contains(model.id) &&
            (model.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                model.provider
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                model.description
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase())))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ListView(
      children: [
        if (filteredPinned.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Pinned Models',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...filteredPinned
              .map((model) => _buildModelTile(model, pinnedModelIds)),
        ],
        if (filteredOthers.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('All Models',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...filteredOthers
              .map((model) => _buildModelTile(model, pinnedModelIds)),
        ],
        if (filteredPinned.isEmpty && filteredOthers.isEmpty)
          const Center(child: Text('No models found')),
      ],
    );
  }

  Widget _buildModelTile(LLMModel model, Set<String> pinnedModelIds) {
    return ListTile(
      leading: CachedNetworkImage(
        imageUrl: model.iconUrl,
        width: 32,
        height: 32,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => const Icon(Icons.settings),
      ),
      title: Text(model.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(model.provider),
          Text(model.description, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              pinnedModelIds.contains(model.id)
                  ? Icons.push_pin
                  : Icons.push_pin_outlined,
              color: pinnedModelIds.contains(model.id) ? Colors.blue : null,
            ),
            onPressed: () async {
              if (pinnedModelIds.contains(model.id)) {
                await widget.settingsService.removePinnedModel(model.id);
              } else {
                await widget.settingsService.addPinnedModel(model.id);
              }
              setState(() {});
            },
          ),
        ],
      ),
      onTap: () {
        widget.onModelSelected(model);
        Navigator.pop(context);
      },
    );
  }
}
