import 'dart:async';

class SendEventManager {
  static SendEventManager? _instance;

  // final _events = <String>{};
  final _completers = <String, Completer<void>>{};

  // 私有构造函数，防止外部创建实例
  SendEventManager._();

  // 获取单例实例的方法
  static SendEventManager get instance {
    _instance ??= SendEventManager._();
    return _instance!;
  }

  Future<void> waitAndMarkEventCompleted(String eventName) async {
    // if (_events.contains(eventName)) {
    //   return Future.value();
    // }

    if (_completers.containsKey(eventName)) {
      return _completers[eventName]!.future;
    }

    final completer = Completer<void>();
    _completers[eventName] = completer;

    try {
      // 设置超时时间为10秒
      await completer.future.timeout(Duration(seconds: 10));
    } catch (e) {
      // 超时时，移除Completer，并抛出异常
      _completers.remove(eventName);
      rethrow;
    }

    return completer.future;
  }

  void markEventCompleted(String eventName) {
    // _events.add(eventName);
    if (_completers.containsKey(eventName)) {
      print("Event complete:${eventName}");
      _completers[eventName]!.complete();
      _completers.remove(eventName);
    }
  }
}