import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: ElevatedButton(
          onPressed: () {
            savePdfToGallery();
          },
          child: const Text('Save PDF to gallery'),
        ),
      ),
    );
  }
}

void savePdfToGallery() async {
  const pdfUrl = 'https://www.pref.kyoto.jp/kenkoshishin/documents/no_1.pdf';

  // Fetch the PDF from the URL.
  final pdfResponse = await http.get(Uri.parse(pdfUrl));
  final pdfPath = await tempPdfPath();
  final pdfFile = File(pdfPath);
  pdfFile.writeAsBytesSync(pdfResponse.bodyBytes);

  PdfDocument doc = await PdfDocument.openFile(pdfPath);
  debugPrint(doc.pageCount.toString());

  for (int i = 1; i <= doc.pageCount; i++) {
    PdfPage page = await doc.getPage(i);
    PdfPageImage pagePdfImage = await page.render();
    ui.Image pageImage = await pagePdfImage.createImageDetached();
    ByteData? imageBytes =
        await pageImage.toByteData(format: ui.ImageByteFormat.png);

    if (imageBytes != null) {
      final result = await ImageGallerySaver.saveImage(
          imageBytes.buffer.asUint8List(),
          name: 'page_${i}_${DateTime.now().millisecondsSinceEpoch}');
      // ignore: unnecessary_brace_in_string_interps
      debugPrint("${result}");
    }
  }
  pdfFile.delete();
}

Future<String> tempPdfPath() async {
  Directory tempDir = await getTemporaryDirectory();
  final dirExists = await tempDir.exists();

  if (!dirExists) {
    await tempDir.create();
  }

  String tempPath = tempDir.path;

  return '$tempPath/my-pdf.pdf';
}
