class SettingsState {
  const SettingsState({
    this.apiKey = '',
    this.siteUrl = '',
    this.siteName = '',
    this.isLoading = false,
    this.errorMessage = '',
  });

  final String apiKey;
  final String siteUrl;
  final String siteName;
  final bool isLoading;
  final String errorMessage;

  SettingsState copyWith({
    String? apiKey,
    String? siteUrl,
    String? siteName,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SettingsState(
      apiKey: apiKey ?? this.apiKey,
      siteUrl: siteUrl ?? this.siteUrl,
      siteName: siteName ?? this.siteName,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
