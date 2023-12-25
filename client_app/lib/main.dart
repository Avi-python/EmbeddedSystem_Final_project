import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'widgets/appbar.dart';
import 'utils/send_event_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.white,
        brightness: Brightness.light,
      )),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  FlutterLocalNotificationsPlugin localNotificaition = FlutterLocalNotificationsPlugin();
  final android = const AndroidInitializationSettings('@mipmap/ic_launcher');
  late final initializationSettings;
  final androidDetails = const AndroidNotificationDetails(
      '10086',
      'detect',
      importance: Importance.max,
      priority: Priority.high
  );

  late final details = NotificationDetails(
      android: androidDetails,
  );
  // Timer? _timer;
  // int _countdownSeconds = 0;

  late MqttClient client;
  final String broker = 'broker.hivemq.com';
  final int port = 1883;
  final String clientIdentifier = 'guard_black_box_client_app';
  final topic = 'guard_black_box/test1';

  bool isConnect = false;
  bool isTryChangeConnection = false;
  bool isSecondHandShack = false;
  bool isLock = true;
  bool isTryChangeLockType = false;
  bool isNoRespond = false;
  bool isDetect = false;
  bool isTryDisableAlarm = false;

  Timer? pollingTimer;


  Future<void> _checkConnectionPolling() async {
    isNoRespond = false;
    _checkConnectionPollingSingleRound();
  }

  Future<void> _checkConnectionPollingSingleRound() async {
    debugPrint("connectionPolling");
    if (isNoRespond) {
      localNotificaition.show(
          DateTime.now().millisecondsSinceEpoch >> 10,
          '裝置斷線!!!',
          '請重新連接',
          details  //剛才的訊息通知規格變數
      );
      client.disconnect();
      setState(() {
        isConnect = false;
        isSecondHandShack = false;
        isTryChangeConnection = false;
        isTryChangeLockType = false;
      });
      pollingTimer!.cancel();
    } else {
      isNoRespond = true;
      _sendMessage("1c");
      pollingTimer = Timer(Duration(seconds: 10), () async {
        await _checkConnectionPollingSingleRound();
      });
    }
  }

  Future<void> _sendMessage(String msg) async {
    final builder = MqttClientPayloadBuilder();
    builder.addString(msg);

    debugPrint("send");

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    } else {
      throw const FormatException('Failed to send message');
    }
  }

  Future<void> _initConnectMQTTServer() async {
    client = MqttServerClient(broker, clientIdentifier);
    client.port = port;

    final MqttConnectMessage connMess = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean()
        .withWillTopic('willtopic')
        .withWillMessage('Will message')
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      debugPrint('Exception: $e');
      client.disconnect();
      throw FormatException("cannot connect: $e");
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      debugPrint('Connected to the broker');
    } else {
      debugPrint(
          'Failed to connect to the broker (state=${client.connectionStatus?.state})');
      client.disconnect();
      throw FormatException(
          'Failed to connect to the broker (state=${client.connectionStatus?.state})');
    }
  }

  List<MqttReceivedMessage<MqttMessage>>? _listen(
      List<MqttReceivedMessage<MqttMessage?>>? c) {
    final recMess = c![0].payload as MqttPublishMessage;
    final pt =
        MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    // data.value = pt;
    var header = pt[0];
    if (header == '0') {
      isNoRespond = false;
      switch (pt[1]) {
        case 'a':
          if (pt[2] == "i") {
            if (pt[3] == "l") {
              // 0ail
              isLock = true;
            } else {
              isLock = false;
            }
            isSecondHandShack = true;
          }
          break;
        case 'l':
          if (pt[2] == "l") {
            isLock = true;
          } else {
            isLock = false;
          }
          SendEventManager.instance.markEventCompleted("_changeLockType");
        case 'd':
          if(pt[2] == "s") {
            localNotificaition.show(
                DateTime.now().millisecondsSinceEpoch >> 10,
                '物品被移動!!!!',
                '請盡速查看!!!!',
                details  //剛才的訊息通知規格變數
            );
            setState(() {
              isDetect = true;
              isLock = true;
            });
          } else {
            SendEventManager.instance.markEventCompleted("_disableAlarm");
          }
      }
      debugPrint(
          'MQTT_LOGS:: New data arrived: topic is <${c[0].topic}>, payload is $pt');
    }
    return null;
  }

  Future<void> _initConnectBlackBox() async {
    try {
      await _initConnectMQTTServer();
    } catch (e) {
      debugPrint("_initConnectMQTTServerError:$e");
      setState(() {
        isTryChangeConnection = false;
      });
      return;
    }

    debugPrint('MQTT_LOGS::Subscribing to the test/sample_1 topic');
    client.subscribe(topic, MqttQos.atMostOnce);

    client.updates!.listen(_listen);

    try {
      await _connecthandShake();
      setState(() {
        isConnect = true;
        isTryChangeConnection = false;
      });
      _checkConnectionPolling();
    } catch (e) {
      debugPrint("_initConnectionBlackBoxError: $e");
      client.disconnect();
      setState(() {
        isTryChangeConnection = false;
      });
      return;
    }
  }

  Future<void> _secondHandShake() async {
    int time = 5;
    while (!isSecondHandShack) {
      if (time < 0) {
        throw FormatException("_secondHandShakeError: Reply time out");
      }
      await Future.delayed(const Duration(seconds: 1));
      time--;
    }
  }

  Future<void> _connecthandShake() async {
    try {
      await _sendMessage("1s");
      await _secondHandShake();
      await _sendMessage("1ai");
    } catch (e) {
      throw FormatException("_handShakeError:$e");
    }
  }

  Future<void> _disconnect() async {
    try {
      await _sendMessage("1f");
      pollingTimer!.cancel();
      client.disconnect();
      setState(() {
        isConnect = false;
        isSecondHandShack = false;
        isTryChangeConnection = false;
        isTryChangeLockType = false;
      });
    } catch (e) {
      debugPrint("badDisconnect:$e");
    } finally {
      setState(() {
        isConnect = false;
        isTryChangeConnection = false;
        isSecondHandShack = false;
      });
    }
  }

  Future<void> _changeLockType() async {
    try {
      await _sendMessage("1l");
      await SendEventManager.instance
          .waitAndMarkEventCompleted("_changeLockType");
      setState(() {
        isTryChangeLockType = false;
      });
    } catch (e) {
      debugPrint("_disableAlarmError: $e");
      // _toaster("變更鎖時發生錯誤，請嘗試重新連線箱子");
    }
  }

  // Future<void> _startAlarmTimer() async {
  //   _timer ??= Timer.periodic(Duration(seconds: 1), (Timer timer) {
  //     if (_countdownSeconds > 0) {
  //       _countdownSeconds--;
  //     } else {
  //       // 计时结束后关闭计时器
  //       _timer!.cancel();
  //       _timer = null;
  //       setState(() {
  //         isDetect = false;
  //       });
  //     }
  //   });
  // }

  Future<void> _disableAlarm() async {
    try {
      await _sendMessage("1d");
      await SendEventManager.instance
          .waitAndMarkEventCompleted("_disableAlarm");
      setState(() {
        isTryDisableAlarm = false;
        isDetect = false;
      });
    } catch (e) {
      debugPrint("_disableAlarmError: $e");
    }
  }

  // void _toaster(String msg) {
  //   Fluttertoast.showToast(
  //       msg: msg,
  //       toastLength: Toast.LENGTH_SHORT,
  //       gravity: ToastGravity.CENTER,
  //       timeInSecForIosWeb: 1,
  //       backgroundColor: Theme.of(context).colorScheme.onSurface,
  //       textColor: Theme.of(context).colorScheme.onInverseSurface,
  //       fontSize: 16.0);
  // }

  @override
  void initState() {
    super.initState();
    // 初始化动画控制器
    initializationSettings = InitializationSettings(android: android);
    localNotificaition.initialize(InitializationSettings(android: android));

    _controller = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    // 初始化透明度动画
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() async {
    super.dispose();
    await _disconnect();
    // _timer?.cancel();
    pollingTimer?.cancel();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background.withOpacity(1),
      appBar: CustomTitle("Dashboard"),
      body: Container(
        child: Center(
          child: Stack(
            children: [
              isDetect && isConnect
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                          padding: const EdgeInsets.only(top: 80),
                          child: AnimatedBuilder(
                              animation: _opacity,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _opacity.value,
                                  child: IconButton(
                                      icon: Icon(
                                        Icons.warning_amber_outlined,
                                        size: 100.0,
                                        shadows: [
                                          Shadow(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onBackground,
                                            blurRadius: 1,
                                            offset: const Offset(2, 2),
                                          )
                                        ],
                                      ),
                                      color: Colors.redAccent,
                                      onPressed: () {
                                        if(!isTryDisableAlarm) {
                                          _disableAlarm();
                                          }
                                      }),
                                );
                              })),
                    )
                  : const SizedBox(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    isLock
                        ? 'lib/assets/guard_black_box_1_closed.png'
                        : 'lib/assets/guard_black_box_1_open.png',
                    width: 300.0, // Adjust width as needed
                    height: 300.0, // Adjust height as needed
                    fit: BoxFit.contain,
                    opacity: AlwaysStoppedAnimation(isConnect ? 1 : 0.3),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isConnect
                          ? Text(
                              "Connect",
                              style: TextStyle(color: Colors.greenAccent),
                            )
                          : Text(
                              "Disconnect",
                              style: TextStyle(
                                  color: Colors.grey.withOpacity(0.5)),
                            ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.check_circle_rounded,
                        color: isConnect
                            ? Colors.greenAccent
                            : Colors.grey.withOpacity(0.5),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 50,
                        child: TextButton(
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all<Color>(
                                Theme.of(context).colorScheme.surface),
                            foregroundColor: MaterialStateProperty.all<Color>(
                                isConnect
                                    ? Theme.of(context)
                                        .colorScheme
                                        .error
                                        .withOpacity(0.5)
                                    : Theme.of(context).colorScheme.primary),
                            padding:
                                MaterialStateProperty.all<EdgeInsetsGeometry>(
                              EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                            ),
                            textStyle: MaterialStateProperty.all<TextStyle>(
                              TextStyle(fontSize: 18),
                            ),
                            elevation:
                                MaterialStateProperty.resolveWith<double>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.pressed)) {
                                  return 0;
                                }
                                return 10;
                              },
                            ),
                            shadowColor: MaterialStateProperty.all<Color>(
                                Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5)),
                            // Add more properties as needed
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              isTryChangeConnection
                                  ? const CupertinoActivityIndicator()
                                  : const SizedBox(),
                              isTryChangeConnection
                                  ? Padding(padding: EdgeInsets.all(5))
                                  : const SizedBox(),
                              isConnect ? Text("Disconnect") : Text("Connect"),
                            ],
                          ),
                          onPressed: () async {
                            if (isTryChangeConnection == false) {
                              if (isConnect) {
                                setState(() {
                                  isTryChangeConnection = true;
                                });
                                // todo Disconnect
                                await _disconnect();
                              } else {
                                setState(() {
                                  isTryChangeConnection = true;
                                });
                                await _initConnectBlackBox();
                              }
                            }
                          },
                        ),
                      ),
                      isConnect
                          ? Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: Container(
                                height: 50,
                                child: TextButton(
                                  style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.all<
                                            Color>(
                                        Theme.of(context).colorScheme.surface),
                                    foregroundColor:
                                        MaterialStateProperty.all<Color>(
                                            isConnect
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                    .withOpacity(0.5)),
                                    padding: MaterialStateProperty.all<
                                        EdgeInsetsGeometry>(
                                      EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                    ),
                                    textStyle:
                                        MaterialStateProperty.all<TextStyle>(
                                      TextStyle(fontSize: 18),
                                    ),
                                    elevation: MaterialStateProperty
                                        .resolveWith<double>(
                                      (Set<MaterialState> states) {
                                        if (states
                                            .contains(MaterialState.pressed)) {
                                          return 0;
                                        }
                                        return 10;
                                      },
                                    ),
                                    shadowColor:
                                        MaterialStateProperty.all<Color>(
                                            Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.5)),
                                    // Add more properties as needed
                                  ),
                                  child: Container(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        isTryChangeLockType
                                            ? const CupertinoActivityIndicator()
                                            : const SizedBox(),
                                        isTryChangeLockType
                                            ? const Padding(
                                                padding: EdgeInsets.all(5))
                                            : const SizedBox(),
                                        !isLock ? Text("Lock") : Text("UnLock"),
                                        const Padding(
                                            padding: EdgeInsets.all(5)),
                                        !isLock
                                            ? const Icon(Icons.lock)
                                            : const Icon(Icons.lock_open),
                                      ],
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (!isTryChangeLockType) {
                                      setState(() {
                                        isTryChangeLockType = true;
                                      });
                                      await _changeLockType();
                                    }
                                  },
                                ),
                              ),
                            )
                          : const SizedBox(),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
