import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rx_ble/rx_ble.dart';

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
  String macAddress;
  Exception returnError;
  final results = <String, ScanResult>{};
  final uuidControl = TextEditingController(
    text: "0000ff04-0000-1000-8000-00805f9b34fb",
  );
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
      results[scanResult.macAddress] = scanResult;
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

  Future<void> readChar() async {
    final value = await RxBle.readChar(macAddress, uuidControl.text);
    return value.toString() + "\n\n" + utf8.decode(value);
  }

  Future<void> writeChar() async {
    return await RxBle.writeChar(
      macAddress,
      uuidControl.text,
      utf8.encode(writeCharValueControl.text),
    );
  }

  Future<void> requestMtu() async {
    return await RxBle.requestMtu(macAddress, int.parse(mtuControl.text));
  }

  Future<void> randomWrite() async {
    final rand = new Random();
    final futures = List.generate(int.parse(randomWriteNum.text), (_) {
      return RxBle.writeChar(
        macAddress,
        uuidControl.text,
        Uint8List.fromList(
          List.generate(int.parse(randomWriteSize.text), (_) {
            return rand.nextInt(33) + 89;
          }),
        ),
      );
    });
    final start = DateTime.now().millisecondsSinceEpoch;
    await Future.wait(futures);
    final end = DateTime.now().millisecondsSinceEpoch;
    return "${end - start} ms";
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
                    "connect(${scanResult.macAddress})",
                    style: TextStyle(fontFamily: 'DejaVuSansMono'),
                  ),
                  onPressed: wrapCall(() async {
                    await RxBle.stopScan();
                    setState(() {
                      macAddress = scanResult.macAddress;
                    });
                    await for (final state in RxBle.connect(macAddress)) {
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
                    "disconnect()",
                    style: TextStyle(fontFamily: 'DejaVuSansMono'),
                  ),
                  onPressed: wrapCall(() async {
                    await RxBle.disconnect();
                  }),
                ),
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
                )
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
