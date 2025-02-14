import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // Add this
import 'package:http/http.dart' as http; // Add this
import 'package:monkeychat/services/ai_provider.dart';
import '../services/settings_service.dart';
import '../models/llm.dart';

class ModelSelectionDialog extends StatefulWidget {
  final SettingsService settingsService;
  final AIProvider modelService;
  final Function(LLModel) onModelSelected;

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
  late Future<List<LLModel>> _modelsFuture;
  String _searchQuery = '';
  final _cacheManager = CacheManager(Config('svg_cache',
      maxNrOfCacheObjects: 20, stalePeriod: const Duration(days: 7)));

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
              child: FutureBuilder<List<LLModel>>(
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

  Widget _buildModelList(List<LLModel> models, Set<String> pinnedModelIds) {
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

  Widget _buildModelTile(LLModel model, Set<String> pinnedModelIds) {
    return ListTile(
      leading: _buildImageWidget(model.iconUrl),
      title: Text(model.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(model.provider),
          Text(model.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (model.supportsImageInput || model.supportsImageOutput)
            Row(
              children: [
                if (model.supportsImageInput) ...[
                  Tooltip(
                    message: 'Supports Image Input',
                    child: const Icon(Icons.camera_alt, size: 16),
                  ),
                  const SizedBox(width: 4),
                ],
                if (model.supportsImageOutput) ...[
                  Tooltip(
                    message: 'Supports Image Output',
                    child: const Icon(Icons.image, size: 16),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
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

  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl.toLowerCase().endsWith('.svg')) {
      return FutureBuilder<String?>(
        future: _loadCachedSvg(imageUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          } else if (snapshot.hasError) {
            print('Error loading SVG: ${snapshot.error}'); // Log the error
            return const Icon(Icons.error); //Consider a different error icon
          } else if (snapshot.hasData && snapshot.data != null) {
            return SvgPicture.string(
              snapshot.data!,
              width: 32,
              height: 32,
              placeholderBuilder: (BuildContext context) =>
                  const CircularProgressIndicator(),
              // Disable network access for security
              //assetBundle: null,
              // Decoder specific properties
              //colorFilter: ColorFilter.mode(Colors.red, BlendMode.srcIn),
            );
          } else {
            return const Icon(Icons.error); // Handle case where data is null
          }
        },
      );
    } else {
      // If the image is not an SVG, use CachedNetworkImage as before
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: 32,
        height: 32,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => const Icon(Icons.settings),
      );
    }
  }

  Future<String?> _loadCachedSvg(String url) async {
    try {
      final file = await _cacheManager.getFileFromCache(url);
      if (file != null) {
        //print('SVG loaded from cache: $url');
        return await file.file.readAsString();
      }

      //print('Downloading SVG: $url');
      final response =
          await http.get(Uri.parse(url)); //Consider adding headers or timeout
      if (response.statusCode == 200) {
        await _cacheManager.putFile(url, response.bodyBytes,
            maxAge: const Duration(days: 7),
            fileExtension: 'svg'); //Cache for a week.
        //print('SVG downloaded and cached: $url');
        return response.body;
      } else {
        print(
            'Failed to download SVG: $url, status code: ${response.statusCode}');
        return null; //Or throw an exception
      }
    } catch (e) {
      print('Error loading or caching SVG: $url, error: $e');
      return null; //Or throw the exception to be handled by the caller
    }
  }

  @override
  void dispose() {
    _cacheManager.dispose();
    super.dispose();
  }
}
