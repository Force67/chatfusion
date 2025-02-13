import 'package:flutter/material.dart';
import '../models/llm.dart';

class ModelSettingsSidebar extends StatefulWidget {
  final LLModel? model;
  final Map<String, dynamic> parameters;
  final ValueChanged<Map<String, dynamic>> onParametersChanged;
  final VoidCallback onDismissed;

  const ModelSettingsSidebar({
    super.key,
    required this.model,
    required this.parameters,
    required this.onParametersChanged,
    required this.onDismissed,
  });

  @override
  _ModelSettingsSidebarState createState() => _ModelSettingsSidebarState();
}

class _ModelSettingsSidebarState extends State<ModelSettingsSidebar> {
  Map<String, dynamic> _currentParameters = {};

  @override
  void initState() {
    super.initState();
    _currentParameters = Map.from(widget.parameters);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 300,
        color: Colors.grey[850],
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Model Settings',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: widget.onDismissed,
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: widget.model?.tunableParameters
                        .map((param) => _buildSettingControl(param))
                        .toList() ?? [],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingControl(String param) {
    const sliderHeight = 80.0;
    final currentValue = _currentParameters[param];

    void updateValue(dynamic value) {
      setState(() => _currentParameters[param] = value);
      widget.onParametersChanged(_currentParameters);
    }

    switch (param) {
      case 'temperature':
        return SizedBox(
          height: sliderHeight,
          child: Slider(
            value: (currentValue ?? 0.7).toDouble(),
            min: 0.0,
            max: 2.0,
            divisions: 20,
            label: 'Temperature: ${(currentValue ?? 0.7).toStringAsFixed(2)}',
            onChanged: (v) => updateValue(v),
          ),
        );

      case 'top_p':
        return SizedBox(
          height: sliderHeight,
          child: Slider(
            value: (currentValue ?? 1.0).toDouble(),
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: 'Top P: ${(currentValue ?? 1.0).toStringAsFixed(2)}',
            onChanged: (v) => updateValue(v),
          ),
        );

      case 'include_reasoning':
        return SwitchListTile(
          title: const Text('Include Reasoning', style: TextStyle(color: Colors.white)),
          value: currentValue ?? false,
          onChanged: (v) => updateValue(v),
        );

      case 'repetition_penalty':
      case 'frequency_penalty':
      case 'presence_penalty':
        return SizedBox(
          height: sliderHeight,
          child: Slider(
            value: (currentValue ?? 0.0).toDouble(),
            min: 0.0,
            max: 2.0,
            divisions: 20,
            label: '$param: ${(currentValue ?? 0.0).toStringAsFixed(2)}',
            onChanged: (v) => updateValue(v),
          ),
        );

      case 'top_k':
      case 'seed':
        return ListTile(
          title: TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: param,
              labelStyle: const TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
            controller: TextEditingController(text: currentValue?.toString() ?? ''),
            onChanged: (v) => updateValue(num.tryParse(v)),
          ),
        );

      default:
        return ListTile(
          title: Text(param,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        );
    }
  }
}
