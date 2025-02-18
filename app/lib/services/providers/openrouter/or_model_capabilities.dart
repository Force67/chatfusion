// lib/services/providers/openrouter/or_model_capabilities.dart

class ORModelCapabilities {
  bool supportsTextInput = false;
  bool supportsImageInput = false;
  bool supportsTextOutput = false;
  bool supportsImageOutput = false;

  static ORModelCapabilities fromString(String ioString) {
    final parts = ioString.split('->').map((e) => e.trim()).toList();
    if (parts.length != 2) {
      throw ArgumentError('Invalid format: Use "input_types->output_types"');
    }

    final config = ORModelCapabilities();

    _processInputTypes(parts[0], config);
    _processOutputTypes(parts[1], config);

    return config;
  }

  static void _processInputTypes(String inputStr, ORModelCapabilities config) {
    final inputTypes = _parseAndValidateTypes(inputStr, 'input');
    config.supportsTextInput = inputTypes.contains('text');
    config.supportsImageInput = inputTypes.contains('image');
  }

  static void _processOutputTypes(String outputStr, ORModelCapabilities config) {
    final outputTypes = _parseAndValidateTypes(outputStr, 'output');
    config.supportsTextOutput = outputTypes.contains('text');
    config.supportsImageOutput = outputTypes.contains('image');
  }

  static List<String> _parseAndValidateTypes(String typeString, String category) {
    final types = typeString
        .split('+')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (types.isEmpty) {
      throw ArgumentError('Must specify at least one $category type');
    }

    const allowedTypes = {'text', 'image'};
    for (final type in types) {
      if (!allowedTypes.contains(type)) {
        throw ArgumentError('Invalid $category type: $type');
      }
    }

    return types;
  }
}
