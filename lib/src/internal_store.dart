import 'dart:convert';

import 'disk_util/disk_util.dart';
import 'statsig_user.dart';

import 'probe.dart';

enum EvalReason {
  Loading,
  NetworkNotModified,
  Network,
  Cache,
  Uninitialized,
  NoValues
}

enum EvalStatus { Recognized, Unrecognized }

class InternalStore {
  Map featureGates = {};
  Map dynamicConfigs = {};
  Map layerConfigs = {};
  Map paramStores = {};
  int time = 0;
  int receivedAt = 0;
  Map derivedFields = {};
  String userHash = "";
  String hashUsed = "";
  EvalReason reason = EvalReason.Uninitialized;
  String? fullChecksum;

  int getSinceTime(StatsigUser user) {
    if (userHash != user.getFullHash()) {
      return 0;
    }
    return time;
  }

  Map getPreviousDerivedFields(StatsigUser user) {
    if (userHash != user.getFullHash()) {
      return {};
    }
    return derivedFields;
  }

  String? getFullChecksum(StatsigUser user) {
    if (userHash != user.getFullHash()) {
      return null;
    }
    return fullChecksum;
  }

  Future<void> load(StatsigUser user, [StatsigProbe? probe]) async {
    probe?.add("Store: loading");
    
    var store = await _read(user, probe);
    if (store == null) {
      probe?.add("Store: not loaded");
      return;
    }

    featureGates = store["feature_gates"] ?? {};
    dynamicConfigs = store["dynamic_configs"] ?? {};
    layerConfigs = store["layer_configs"] ?? {};
    paramStores = store["param_stores"] ?? {};
    time = store["time"] ?? 0;
    derivedFields = store["derived_fields"] ?? {};
    userHash = store["user_hash"] ?? "";
    hashUsed = store["hash_used"] ?? "";
    receivedAt = store["receivedAt"] ?? 0;
    fullChecksum = store["fullChecksum"];
    reason = EvalReason.Cache;

    probe?.add("Store: loaded");
  }

  finalize() {
    if (reason == EvalReason.Loading) {
      reason = EvalReason.NoValues;
    }
  }

  Future<void> save(StatsigUser user, Map? response, [StatsigProbe? probe]) async {
    probe?.add("Store: saving");

    featureGates = response?["feature_gates"] ?? {};
    dynamicConfigs = response?["dynamic_configs"] ?? {};
    layerConfigs = response?["layer_configs"] ?? {};
    paramStores = response?["param_stores"] ?? {};
    time = response?["time"] ?? 0;
    derivedFields = response?["derived_fields"] ?? {};
    userHash = user.getFullHash();
    hashUsed = response?["hash_used"] ?? "";
    reason = EvalReason.Network;
    receivedAt = DateTime.now().millisecondsSinceEpoch;
    fullChecksum = response?["full_checksum"];

    await _write(
        user,
        json.encode({
          "feature_gates": featureGates,
          "dynamic_configs": dynamicConfigs,
          "layer_configs": layerConfigs,
          "param_stores": paramStores,
          "time": time,
          "derived_fields": derivedFields,
          "user_hash": userHash,
          "hash_used": hashUsed,
          "receivedAt": receivedAt,
          "fullChecksum": fullChecksum,
        }), probe);
  }

  void clear() {
    featureGates = {};
    dynamicConfigs = {};
    layerConfigs = {};
    paramStores = {};
    time = 0;
    derivedFields = {};
    userHash = "";
    hashUsed = "";
    reason = EvalReason.Uninitialized;
    receivedAt = 0;
    fullChecksum = null;
  }

  Future<void> _write(StatsigUser user, String content, [StatsigProbe? probe]) async {
    probe?.add("Store: writing");
    try {
      String key = user.getCacheKey();
      await DiskUtil.instance.write("$key.statsig_store", content);
    } catch (e) {
      probe?.add("Store: write error: $e");
      rethrow;
    }
  }

  Future<Map?> _read(StatsigUser user, [StatsigProbe? probe]) async {
    probe?.add("Store: reading");
    try {
      String key = user.getCacheKey();
      var content = await DiskUtil.instance.read("$key.statsig_store");
      var data = json.decode(content);
      return data is Map ? data : null;
    } catch (e) {
      probe?.add("Store: read error: $e");
    }
    return null;
  }
}
