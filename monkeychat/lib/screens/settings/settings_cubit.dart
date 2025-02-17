import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:monkeychat/services/settings_service.dart';
import 'package:monkeychat/screens/settings/settings_state.dart';
import 'package:monkeychat/database/local_db.dart';


class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  final _settingsService = SettingsService();

  Future<void> loadSettings() async {
    emit(state.copyWith(isLoading: true));
    try {
      final apiKey = await _settingsService.getApiKey() ?? '';
      final siteUrl = await _settingsService.getSiteUrl() ?? '';
      final siteName = await _settingsService.getSiteName() ?? '';
      emit(state.copyWith(
        apiKey: apiKey,
        siteUrl: siteUrl,
        siteName: siteName,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load settings: $e',
      ));
    }
  }

  Future<void> saveSettings({
    required String apiKey,
    required String siteUrl,
    required String siteName,
  }) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _settingsService.saveSettings(
        apiKey: apiKey,
        siteUrl: siteUrl,
        siteName: siteName,
      );
      emit(state.copyWith(
        apiKey: apiKey,
        siteUrl: siteUrl,
        siteName: siteName,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to save settings: $e',
      ));
    }
  }

  Future<void> clearSettings() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _settingsService.saveSettings(
        apiKey: '',
        siteUrl: '',
        siteName: '',
      );
      emit(state.copyWith(apiKey: '', siteUrl: '', siteName: '', isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to clear settings: $e',
      ));
    }
  }

  Future<void> clearChatDatabase() async {
    emit(state.copyWith(isLoading: true));
    try {
      await DatabaseHelper.instance.clearAll();
      await DatabaseHelper.instance.getChats(); // Refreshing chats after clearing
      emit(state.copyWith(isLoading: false));
      //Potentially emit a new state that the chat database has been cleared for UI updates in other parts of your app if needed.
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to clear chat database: $e',
      ));
    }
  }
}
