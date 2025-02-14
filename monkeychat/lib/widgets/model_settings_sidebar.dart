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
  State<ModelSettingsSidebar> createState() => _ModelSettingsSidebarState();
}

class _ModelSettingsSidebarState extends State<ModelSettingsSidebar> {
  Map<String, dynamic> _currentParameters = {};

  // Parameters that users most care about usually,
  // so we show them first
  final List<String> _commonParams = const [
    'include_reasoning',
    'temperature',
    'max_tokens',
  ];
  bool _advancedExpanded = false;

  final List<String> _blackListedParams = const [
    "logit_bias",
    "response_format",
    "stop", // i may deal w this later.
    "logprobs",
    "top_logprobs",
  ];

  @override
  void initState() {
    super.initState();
    _currentParameters = Map.from(widget.parameters);
    print(widget.parameters);
  }

  @override
  Widget build(BuildContext context) {
    final advancedParams = widget.model?.tunableParameters
            .where((param) => !_commonParams.contains(param))
            .toList() ??
        [];

    // Filter _commonParams to ensure they are in the paramsList
    final filteredCommonParams = _commonParams
        .where(
            (param) => widget.model?.tunableParameters.contains(param) ?? false)
        .toList();

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.grey[850],
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  children: [
                    ...filteredCommonParams
                        .map((param) => _buildControl(param)),
                    const SizedBox(height: 16),
                    _buildAdvancedSection(advancedParams),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text('Model Settings',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: widget.onDismissed,
            tooltip: 'Close settings',
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection(List<String> params) {
    final filteredParams = params
        .where((param) => !_blackListedParams.contains(param))
        .toList();

    return ExpansionTile(
      initiallyExpanded: _advancedExpanded,
      onExpansionChanged: (v) => setState(() => _advancedExpanded = v),
      tilePadding: EdgeInsets.zero,
      title: Text('Advanced Parameters',
          style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      children: [
        ...filteredParams.map((param) => _buildControl(param)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildControl(String param) {
    final currentValue = _currentParameters[param];

    void updateValue(dynamic value) {
      setState(() => _currentParameters[param] = value);
      widget.onParametersChanged(_currentParameters);
    }

    switch (param) {
      case 'temperature':
        return _buildSlider(
          title: 'Temperature',
          subtitle: 'Controls randomness (0 = precise, 2 = creative)',
          value: (currentValue ?? 0.7).toDouble(),
          min: 0,
          max: 2,
          divisions: 20,
          onChanged: updateValue,
        );

      case 'top_p':
        return _buildSlider(
          title: 'Top P',
          subtitle: 'Probability mass cutoff (0.1 = diverse, 1.0 = broad)',
          value: (currentValue ?? 1.0).toDouble(),
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: updateValue,
        );
      
      case 'min_p':
        return _buildSlider(
          title: 'Min P',
          subtitle: 'Probability mass cutoff (0.1 = diverse, 1.0 = broad)',
          value: (currentValue ?? 0.0).toDouble(),
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: updateValue,
        );

      case 'include_reasoning':
        return _buildSwitch(
          title: 'Include Reasoning',
          subtitle: 'Show step-by-step thinking in output',
          value: currentValue ?? false,
          onChanged: updateValue,
        );

      case 'repetition_penalty':
        return _buildSlider(
          title: 'Repetition Penalty',
          subtitle: 'Penalize repeated phrases (1.0 = off)',
          value: (currentValue ?? 1.0).toDouble(),
          min: 0,
          max: 2,
          divisions: 20,
          onChanged: updateValue,
        );

      case 'frequency_penalty':
        return _buildSlider(
          title: 'Frequency Penalty',
          subtitle: 'Penalize common phrases (0.0 = off)',
          value: (currentValue ?? 0.0).toDouble(),
          min: 0,
          max: 2,
          divisions: 20,
          onChanged: updateValue,
        );

      case 'presence_penalty':
        return _buildSlider(
          title: 'Presence Penalty',
          subtitle: 'Penalize missing phrases (0.0 = off)',
          value: (currentValue ?? 0.0).toDouble(),
          min: 0,
          max: 2,
          divisions: 20,
          onChanged: updateValue,
        );

      case 'top_logprobs':
        return _buildSlider(
          title: 'Top Log Probs',
          subtitle: 'Number of log probabilities to output',
          value: (currentValue ?? 0.0).toDouble(),
          min: 0,
          max: 20,
          divisions: 20,
          onChanged: updateValue,
        );

      case 'top_k':
        return _buildNumberInput(
          title: 'Top K',
          subtitle: 'Number of tokens to consider (0 = off)',
          value: currentValue,
          onChanged: updateValue,
        );

      case 'logprobs':
        return _buildSwitch(
          title: 'Include Log Probabilities',
          subtitle: 'Include log probabilities in output',
          value: currentValue ?? false,
          onChanged: updateValue,
        );


      case 'seed':
        return _buildNumberInput(
          title: 'Seed',
          subtitle: 'Random seed for reproducibility',
          value: currentValue,
          onChanged: updateValue,
        );
      case 'max_tokens':
        return _buildNumberInput(
          title: 'Max Tokens',
          subtitle: 'Maximum number of tokens to generate',
          value: currentValue,
          onChanged: updateValue,
        );

      default:
        return _buildSlider(
          title: param,
          value: (currentValue ?? 0.0).toDouble(),
          min: 0,
          max: 2,
          divisions: 20,
          onChanged: updateValue,
        );
    }
  }

  Widget _buildSlider({
    required String title,
    String? subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Function(double) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  TextSpan(
                    text: '\n$subtitle',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.blueAccent,
              inactiveTrackColor: Colors.blueGrey,
              thumbColor: Colors.blueAccent,
              overlayColor: Colors.blueAccent.withOpacity(0.2),
              valueIndicatorColor: Colors.blueAccent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: value.toStringAsFixed(2),
              onChanged: onChanged,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              value.toStringAsFixed(2),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch({
    required String title,
    String? subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SwitchListTile(
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 12))
            : null,
        value: value,
        activeColor: Colors.blueAccent,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildNumberInput({
    required String title,
    String? subtitle,
    required dynamic value,
    required Function(dynamic) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  TextSpan(
                    text: '\n$subtitle',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            controller: TextEditingController(text: value?.toString() ?? ''),
            onChanged: (v) => onChanged(num.tryParse(v)),
          ),
        ],
      ),
    );
  }
}
