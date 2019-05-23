import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rx_ble/rx_ble.dart';

int time() => DateTime.now().millisecondsSinceEpoch;

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Rx BLE example'),
        ),
        body: MyApp(),
      ),
    ),
  );
}

class YesNoDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Location Permission Required'),
      content: Text(
        "This app needs location permission in order to access Bluetooth.\n"
        "Continue?",
      ),
      actions: <Widget>[
        SimpleDialogOption(
          child: Text(
            "NO",
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
        SimpleDialogOption(
          child: Text(
            "YES",
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        )
      ],
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var returnValue;
  String deviceId;
  Exception returnError;
  final results = <String, ScanResult>{};
  var chars = Map<String, List<String>>();
  final uuidControl = TextEditingController();
  final mtuControl = TextEditingController();
  final writeCharValueControl = TextEditingController();
  final randomWriteNum = TextEditingController(text: '100');
  final randomWriteSize = TextEditingController(text: '100');
  var connectionState = BleConnectionState.disconnected;
  var isWorking = false;

  Function wrapCall(Function fn) {
    return () async {
      var value, error;
      setState(() {
        returnError = returnValue = null;
        isWorking = true;
      });
      try {
        value = await fn();
        print('returnValue: $value');
      } catch (e, trace) {
        print('returnError: $e\n$trace');
        error = e;
      } finally {
        if (mounted) {
          setState(() {
            isWorking = false;
            returnError = error;
            returnValue = value;
          });
        }
      }
    };
  }

  Future<void> requestAccessRationale() async {
    return await RxBle.requestAccess(
      showRationale: () async {
        return await showDialog(
              context: context,
              builder: (context) => YesNoDialog(),
            ) ??
            false;
      },
    );
  }

  Future<void> startScan() async {
    await for (final scanResult in RxBle.startScan()) {
      results[scanResult.deviceId] = scanResult;
      if (!mounted) return;
      setState(() {
        returnValue = JsonEncoder.withIndent(" " * 2, (o) {
          if (o is ScanResult) {
            return o.toString();
          } else {
            return o;
          }
        }).convert(results);
      });
    }
  }

  Future<String> discoverChars() async {
    final value = await RxBle.discoverChars(deviceId);
    if (!mounted) return null;
    setState(() {
      chars = value;
    });
    return JsonEncoder.withIndent(" " * 2).convert(chars);
  }

  Future<void> readChar() async {
    final value = await RxBle.readChar(deviceId, uuidControl.text);
    return value.toString() +
        "\n\n" +
        RxBle.charToString(value, allowMalformed: true);
  }

  Future<void> observeChar() async {
    var start = time();
    await for (final value in RxBle.observeChar(deviceId, uuidControl.text)) {
      final end = time();
      if (!mounted) return;
      setState(() {
        returnValue = value.toString() +
            "\n\n" +
            RxBle.charToString(value, allowMalformed: true) +
            "\n\nDelay: ${(end - start)} ms";
      });
      start = time();
    }
  }

  Future<void> writeChar() async {
    return await RxBle.writeChar(
      deviceId,
      uuidControl.text,
      RxBle.stringToChar(writeCharValueControl.text),
    );
  }

  Future<void> requestMtu() async {
    return await RxBle.requestMtu(deviceId, int.parse(mtuControl.text));
  }

  Future<void> randomWrite() async {
    final rand = new Random();
    final futures = List.generate(int.parse(randomWriteNum.text), (_) {
      return RxBle.writeChar(
        deviceId,
        uuidControl.text,
        Uint8List.fromList(
          List.generate(int.parse(randomWriteSize.text), (_) {
            return rand.nextInt(33) + 89;
          }),
        ),
      );
    });
    final start = time();
    await Future.wait(futures);
    final end = time();
    return "${end - start} ms";
  }

  Future<void> continuousRead() async {
    while (true) {
      final start = time();
      final value = await RxBle.readChar(deviceId, uuidControl.text);
      final end = time();
      if (!mounted) return;
      setState(() {
        returnValue = value.toString() +
            "\n\n" +
            RxBle.charToString(value, allowMalformed: true) +
            "\n\nDelay: ${start - end} ms";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListView(
            children: <Widget>[
              Text("Return Value:"),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  color: Colors.black,
                  child: Text(
                    "$returnValue",
                    style: TextStyle(
                      fontFamily: 'DejaVuSansMono',
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Divider(),
              Text("Error:"),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  color: Colors.black,
                  child: Text(
                    "$returnError",
                    style: TextStyle(
                      fontFamily: 'DejaVuSansMono',
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Divider(),
              Container(
                color: Colors.black,
                child: Text(
                  connectionState.toString(),
                  style: TextStyle(
                    fontFamily: 'DejaVuSansMono',
                    color: Colors.white,
                  ),
                ),
              ),
              Divider(),
              RaisedButton(
                child: Text(
                  "requestAccess()",
                  style: TextStyle(fontFamily: 'DejaVuSansMono'),
                ),
                onPressed: wrapCall(RxBle.requestAccess),
              ),
              RaisedButton(
                child: Text(
                  "requestAccess(showRationale)",
                  style: TextStyle(fontFamily: 'DejaVuSansMono'),
                ),
                onPressed: wrapCall(requestAccessRationale),
              ),
              RaisedButton(
                child: Text(
                  "hasAccess()",
                  style: TextStyle(fontFamily: 'DejaVuSansMono'),
                ),
                onPressed: wrapCall(RxBle.hasAccess),
              ),
              RaisedButton(
                child: Text(
                  "openAppSettings()",
                  style: TextStyle(fontFamily: 'DejaVuSansMono'),
                ),
                onPressed: wrapCall(RxBle.openAppSettings),
              ),
              Divider(),
              RaisedButton(
                child: Text(
                  "startScan()",
                  style: TextStyle(fontFamily: 'DejaVuSansMono'),
                ),
                onPressed: wrapCall(startScan),
              ),
              RaisedButton(
                child: Text(
                  "stopScan()",
                  style: TextStyle(fontFamily: 'DejaVuSansMono'),
                ),
                onPressed: wrapCall(RxBle.stopScan),
              ),
              Divider(),
              if (results.isEmpty)
                Text('Start scanning to connect to a device'),
              for (final scanResult in results.values)
                RaisedButton(
                  child: Text(
                    "connect(${scanResult.deviceId})",
                    style: TextStyle(fontFamily: 'DejaVuSansMono'),
                  ),
                  onPressed: wrapCall(() async {
                    await RxBle.stopScan();
                    setState(() {
                      deviceId = scanResult.deviceId;
                    });
                    await for (final state in RxBle.connect(deviceId)) {
                      print("device state: $state");
                      if (!mounted) return;
                      setState(() {
                        connectionState = state;
                      });
                    }
                  }),
                ),
              Divider(),
              if (connectionState != BleConnectionState.connected)
                Text("Connect to a device to perform GATT operations.")
              else ...[
                RaisedButton(
                  child: Text(
                    "discoverChars()",
                    style: TextStyle(fontFamily: 'DejaVuSansMono'),
                  ),
                  onPressed: wrapCall(discoverChars),
                ),
                RaisedButton(
                  child: Text(
                    "disconnect()",
                    style: TextStyle(fontFamily: 'DejaVuSansMono'),
                  ),
                  onPressed: wrapCall(RxBle.disconnect),
                ),
                Divider(),
                if (chars.isNotEmpty) Text("Characteristic Picker"),
                for (final i in chars.values)
                  for (final j in i)
                    RaisedButton(
                      child: Text(j),
                      onPressed: () {
                        setState(() {
                          uuidControl.text = j;
                        });
                      },
                    ),
                Divider(),
                TextField(
                  controller: uuidControl,
                  decoration: InputDecoration(
                    labelText: "uuid",
                  ),
                ),
                RaisedButton(
                  child: Text(
                    "device.readChar()",
                    style: TextStyle(fontFamily: 'DejaVuSansMono'),
                  ),
                  onPressed: wrapCall(readChar),
                ),
                RaisedButton(
                  child: Text(
                    "device.observeChar()",
                    style: TextStyle(fontFamily: 'DejaVuSansMono'),
                  ),
                  onPressed: wrapCall(observeChar),
                ),
                TextField(
                  controller: writeCharValueControl,
                  decoration: InputDecoration(
                    labelText: "writeChar value",
                  ),
                ),
                RaisedButton(
                  child: Text(
                    "device.writeChar()",
                    style: TextStyle(fontFamily: 'DejaVuSansMono'),
                  ),
                  onPressed: wrapCall(writeChar),
                ),
                TextField(
                  controller: mtuControl,
                  decoration: InputDecoration(
                    labelText: "mtu",
                  ),
                ),
                RaisedButton(
                  child: Text(
                    "device.requestMtu()",
                    style: TextStyle(fontFamily: 'DejaVuSansMono'),
                  ),
                  onPressed: wrapCall(requestMtu),
                ),
                Divider(),
                TextField(
                  controller: randomWriteSize,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Random write batch size",
                  ),
                ),
                TextField(
                  controller: randomWriteNum,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Random Write no of batches",
                  ),
                ),
                RaisedButton(
                  child: Text(
                    'Test random writes',
                    style: TextStyle(fontFamily: 'DejaVuSansMono'),
                  ),
                  onPressed: wrapCall(randomWrite),
                ),
                RaisedButton(
                  child: Text(
                    'Test continuous read',
                    style: TextStyle(fontFamily: 'DejaVuSansMono'),
                  ),
                  onPressed: wrapCall(continuousRead),
                ),
              ],
            ],
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            if (isWorking) LinearProgressIndicator(value: null),
          ],
        ),
      ],
    );
  }
}
