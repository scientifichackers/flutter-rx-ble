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

  Future<void> requestAccess() async {
    final value = await RxBle.requestAccess();
    if (!mounted) return;
    setState(() {
      returnValue = value;
    });
  }

  Future<void> requestAccessRationale() async {
    final value = await RxBle.requestAccess(
      showRationale: () async {
        return await showDialog(
              context: context,
              builder: (context) => YesNoDialog(),
            ) ??
            false;
      },
    );
    if (!mounted) return;
    setState(() {
      returnValue = value;
    });
  }

  Future<void> hasAccess() async {
    final value = await RxBle.hasAccess();
    if (!mounted) return;
    setState(() {
      returnValue = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Text(returnValue?.toString() ?? "Return values appear here."),
        Divider(),
        RaisedButton(
          child: Text("requestAccess()"),
          onPressed: requestAccess,
        ),
        RaisedButton(
          child: Text("requestAccess(showRationale)"),
          onPressed: requestAccessRationale,
        ),
        RaisedButton(
          child: Text("hasAccess()"),
          onPressed: hasAccess,
        ),
        RaisedButton(
          child: Text("openAppSettings()"),
          onPressed: RxBle.openAppSettings,
        ),
      ],
    );
  }
}
