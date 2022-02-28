import 'package:another_brother/label_info.dart';
import 'package:another_brother/printer_info.dart';
import 'package:another_quickbase/another_quickbase.dart';
import 'package:another_quickbase/another_quickbase_models.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' as ui;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Another Quickbase',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Quickbase + Brother Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            Text(
              'Push the button to print contacts:',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _printContacts,
        tooltip: 'Print',
        child: const Icon(Icons.print),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future<void> _printContacts() async {

    //////////////////////////////////////////////////
    /// Request the Storage permissions required by
    /// another_brother to print.
    //////////////////////////////////////////////////
    if (!await Permission.storage.request().isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("Access to storage is needed in order print."),
        ),
      ));
      return;
    }


    //////////////////////////////////////////////////
    /// Configure printer
    /// Printer: QL1110NWB
    /// Connection: Bluetooth
    /// Paper Size: W62
    /// Important: Printer must be paired to the
    /// phone for the BT search to find it.
    //////////////////////////////////////////////////
    var printer = Printer();
    var printInfo = PrinterInfo();
    printInfo.printerModel = Model.QL_1110NWB;
    printInfo.printMode = PrintMode.FIT_TO_PAGE;
    printInfo.isAutoCut = true;
    printInfo.port = Port.BLUETOOTH;
    // Set the label type.
    printInfo.labelNameIndex = QL1100.ordinalFromID(QL1100.W62.getId());

    // Set the printer info so we can use the SDK to get the printers.
    await printer.setPrinterInfo(printInfo);

    // Get a list of printers with my model available in the network.
    List<BluetoothPrinter> printers = await printer.getBluetoothPrinters([Model.QL_1110NWB.getName()]);

    if (printers.isEmpty) {
      // Show a message if no printers are found.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("No paired printers found on your device."),
        ),
      ));

      // TODO Put back
      return;
    }
    // Get the IP Address from the first printer found.
    printInfo.macAddress = printers.single.macAddress;
    printer.setPrinterInfo(printInfo);

    //////////////////////////////////////////////////
    /// Fetch contact information from contacts table
    //////////////////////////////////////////////////

    String realm = "builderprogram-fhernandez2292";
    String appToken = "b6uehv_p3pr_0_4ce4fxdqtbrrfcba7rr6b989j25";
    String appId = "br68wk99f";

    QuickBaseClient client = QuickBaseClient(qBRealmHostname: realm, appToken: appToken);
    await client.initialize();

    var contactTable = await client.getTable(tableId:"br68wmaaw" ,appId: appId);

    var contacts = await client.runQuery(request: RecordsQueryRequest(
        from: contactTable.id!
    ));

    // Print each contact in a label.
    for (int i =0; i < contacts.data!.length; i++) {

      // TODO Create contact label image.
      var contact = contacts.data![i];
      String nameLine = "${contact["6"]["value"]} ${contact["7"]["value"]}";
      String streetLine = "${contact["9"]["value"]}";
      String stateLine = "${contact["11"]["value"]},${contact["12"]["value"]}";

      print ("$nameLine, $streetLine, $stateLine");
      ui.Image imageToPrint = await _generateContactLabel([nameLine, streetLine, stateLine]);
      // Print Invoice
      PrinterStatus status = await printer.printImage(imageToPrint);

      /*
      if (status.errorCode != ErrorCode.ERROR_NONE) {
        // Show toast with error.
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(
          content: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Print failed with error code: ${status.errorCode.getName()}"),
          ),
        ));

       */
    }

  }

  Future<ui.Image> _generateContactLabel(List<String> labelLines) async {
    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder);

    double baseSize = 200;
    double labelWidthPx = 9 * baseSize;
    //double labelHeightPx = 3 * baseSize;
    //double qrSizePx = labelHeightPx / 2;

    // Start Padding of the QR Code
    double qrPaddingStart = 30;
    // Start Padding of the Paragraph in relation to the QR Code
    double paraPaddingStart = 30;
    // Font Size for largest text
    double primaryFontSize = 100;


    // Create Paragraph
    ui.ParagraphBuilder paraBuilder = ui.ParagraphBuilder(new ui.ParagraphStyle(textAlign: TextAlign.start));

    labelLines.forEach((lineItem) {
      // Add heading to paragraph
      paraBuilder.pushStyle(ui.TextStyle(fontSize: primaryFontSize, color: Colors.black, fontWeight: FontWeight.bold));
      paraBuilder.addText("$lineItem\n");
      paraBuilder.pop();
    });

    Offset paraOffset = Offset.zero;
    ui.Paragraph infoPara = paraBuilder.build();
    // Layout the pargraph in the remaining space.
    infoPara.layout(ui.ParagraphConstraints(width: labelWidthPx));

    Paint paint = new Paint();
    paint.color = Color.fromRGBO(255, 255, 255, 1);
    Rect bounds = new Rect.fromLTWH(0, 0, labelWidthPx, infoPara.height);
    canvas.save();
    canvas.drawRect(bounds, paint);

    // Draw paragrpah on canvas.
    canvas.drawParagraph(infoPara, paraOffset);

    var picture = await recorder.endRecording().toImage(9 * 200, 3 * 200);

    return picture;
  }

}
