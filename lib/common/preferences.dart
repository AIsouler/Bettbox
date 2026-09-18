import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bett_box/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';
import 'path.dart';
import 'print.dart';

class Preferences {
  static Preferences? _instance;
  Completer<SharedPreferences?> sharedPreferencesCompleter = Completer();

  Future<bool> get isInit async => await sharedPreferencesCompleter.future != null;

  Preferences._internal() {
    SharedPreferences.getInstance()
        .then((value) => sharedPreferencesCompleter.complete(value))
        .onError((_, _) => sharedPreferencesCompleter.complete(null));
  }

  factory Preferences() {
    _instance ??= Preferences._internal();
    return _instance!;
  }

  Future<ClashConfig?> getClashConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    final clashConfigString = preferences?.getString(clashConfigKey);
    if (clashConfigString == null) return null;
    try {
      final clashConfigMap = json.decode(clashConfigString);
      return ClashConfig.fromJson(clashConfigMap);
    } catch (e, stackTrace) {
      commonPrint.log('Failed to parse clash config from preferences: $e\n$stackTrace');
      return null;
    }
  }

  Future<Config?> getConfig() async {
    final preferences = await sharedPreferencesCompleter.future;

    try {
      final configFilePath = await appPath.appConfigPath;
      final configFile = File(configFilePath);
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        if (content.isNotEmpty) {
          final configMap = json.decode(content);
          final config = Config.compatibleFromJson(configMap);

          if (preferences?.getBool('autoLaunch') != config.appSetting.autoLaunch) {
            await preferences?.setBool('autoLaunch', config.appSetting.autoLaunch);
          }

          return config;
        }
      }
    } catch (e, stackTrace) {
      commonPrint.log('Failed to parse config from file: $e\n$stackTrace');
    }

    final configString = preferences?.getString(configKey);
    if (configString == null) return null;
    try {
      final configMap = json.decode(configString);
      final config = Config.compatibleFromJson(configMap);

      await saveConfig(config);
      await preferences?.remove(configKey);
      await preferences?.remove('ip_detail_cache');

      return config;
    } catch (e, stackTrace) {
      commonPrint.log('Failed to parse config from preferences: $e\n$stackTrace');
      return null;
    }
  }

  Future<bool> saveConfig(Config config) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setBool('autoLaunch', config.appSetting.autoLaunch);

    try {
      final configFilePath = await appPath.appConfigPath;
      final targetFile = File(configFilePath);
      final tempFile = File('$configFilePath.tmp');
      await tempFile.parent.create(recursive: true);
      await tempFile.writeAsString(json.encode(config), flush: true);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(configFilePath);
      return true;
    } catch (e, stackTrace) {
      commonPrint.log('Failed to save config to file: $e\n$stackTrace');
      return false;
    }
  }

  Future<void> clearClashConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    preferences?.remove(clashConfigKey);
  }

  Future<void> clearPreferences() async {
    final sharedPreferencesIns = await sharedPreferencesCompleter.future;
    await sharedPreferencesIns?.clear();
    try {
      final file = File(await appPath.appConfigPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    try {
      final ipFile = File(await appPath.ipCacheFilePath);
      if (await ipFile.exists()) {
        await ipFile.delete();
      }
    } catch (_) {}
  }
}

final preferences = Preferences();
