import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monkeychat/screens/settings/settings_cubit.dart';
import 'package:monkeychat/screens/settings/settings_state.dart';

class CustomColors {
  static const Color darkPurple =
      Color(0xFF6B0D83); // Example dark purple.  Adjust to your needs.
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _siteUrlController = TextEditingController();
  final _siteNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<SettingsCubit>().loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _siteUrlController.dispose();
    _siteNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
          title: const Text('App Settings',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.onSurface),
          titleTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, fontSize: 20)),
      body: BlocConsumer<SettingsCubit, SettingsState>(
        listener: (context, state) {
          if (state.errorMessage.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.errorMessage),
                  behavior: SnackBarBehavior.floating),
            );
          }
          if (!state.isLoading) {
            _apiKeyController.text = state.apiKey;
            _siteUrlController.text = state.siteUrl;
            _siteNameController.text = state.siteName;
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      Text(
                        'Update Settings',
                        style:
                            Theme.of(context).textTheme.headlineSmall!.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                      ),
                      const SizedBox(height: 24),
                      // API Key Input
                      _buildSettingsTile(
                        context: context,
                        title: 'OpenRouter API Key',
                        hintText: 'Enter your API key',
                        controller: _apiKeyController,
                        icon: Icons.vpn_key,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your API key';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),
                      // Save Button
                      _buildActionButton(
                        context: context,
                        label: 'Save Settings',
                        isLoading: state.isLoading,
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            context.read<SettingsCubit>().saveSettings(
                                  apiKey: _apiKeyController.text,
                                  siteUrl: _siteUrlController.text,
                                  siteName: _siteNameController.text,
                                );
                            Navigator.pop(context); //Pop context on save
                          }
                        },
                        isPrimary: true, // Use primary color scheme
                      ),
                      const SizedBox(height: 16),
                      // Erase Settings Button
                      _buildActionButton(
                        context: context,
                        label: 'Erase Settings',
                        isLoading: state.isLoading,
                        onPressed: () {
                          context.read<SettingsCubit>().clearSettings();
                        },
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 16),
                      // Erase Chat Database Button
                      _buildActionButton(
                        context: context,
                        label: 'Erase Chat Database',
                        isLoading: state.isLoading,
                        onPressed: () {
                          context.read<SettingsCubit>().clearChatDatabase();
                        },
                        color: Colors.orange.shade400,
                      ),
                      const SizedBox(height: 16),
                      // Clear Cached Data Button
                      _buildActionButton(
                        context: context,
                        label: 'Clear cached data',
                        isLoading: state.isLoading,
                        onPressed: () {
                          context.read<SettingsCubit>().clearCachedData();
                        },
                        color: CustomColors.darkPurple,
                      ),
                    ],
                  ),
                ),
              ),
              if (state.isLoading)
                const ColoredBox(
                  color: Color.fromRGBO(0, 0, 0, 0.5),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required String title,
    required String hintText,
    required TextEditingController controller,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.6)),
            prefixIcon: Icon(icon,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14), //Increased padding
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    required bool isLoading,
    Color? color,
    bool isPrimary = false,
  }) {
    final buttonStyle = ButtonStyle(
      padding:
          MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
      textStyle: MaterialStateProperty.all(const TextStyle(fontSize: 16)),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), //Rounded Corners
        ),
      ),
    );

    if (isPrimary) {
      return ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: buttonStyle.copyWith(
            backgroundColor: MaterialStateProperty.all(
                Theme.of(context).colorScheme.primary),
            foregroundColor: MaterialStateProperty.all(
                Theme.of(context).colorScheme.onPrimary)),
        child: Text(label),
      );
    }

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: buttonStyle.copyWith(
        side: MaterialStateProperty.all(BorderSide(
            color: color ?? Theme.of(context).colorScheme.secondary)),
        foregroundColor: MaterialStateProperty.all(
            color ?? Theme.of(context).colorScheme.secondary),
      ),
      child: Text(label),
    );
  }
}
