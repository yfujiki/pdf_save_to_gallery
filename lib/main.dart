import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;

import 'package:pdf_render/pdf_render_widgets.dart';

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
      home: const MyHomePage(title: 'PDF Save to Gallery'),
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
  PdfDocument? pdfDocument;
  File? pdfFile;

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
        actions: [
          IconButton(
              onPressed: () {
                savePdfToGallery();
              },
              icon: const Icon(Icons.save))
        ],
      ),
      body: FutureBuilder(
        future: loadPdf(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            pdfDocument = snapshot.data as PdfDocument;
            return PdfViewer(doc: pdfDocument!);
          } else if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString()),
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    pdfFile?.delete();
    super.dispose();
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

  Future<PdfDocument> loadPdf() async {
    const pdfUrl = 'https://www.irs.gov/pub/irs-pdf/fw4.pdf';

    // Fetch the PDF from the URL.
    final pdfResponse = await http.get(Uri.parse(pdfUrl));
    final pdfPath = await tempPdfPath();
    pdfFile = File(pdfPath);
    pdfFile?.writeAsBytesSync(pdfResponse.bodyBytes);

    pdfDocument = await PdfDocument.openFile(pdfPath);

    if (pdfDocument == null) {
      throw Exception('Unable to open PDF');
    }

    return pdfDocument!;
  }

  void savePdfToGallery() async {
    if (pdfDocument == null) {
      debugPrint('No PDF loaded yet');
      return;
    }

    debugPrint(pdfDocument!.pageCount.toString());

    for (int i = 1; i <= pdfDocument!.pageCount; i++) {
      PdfPage page = await pdfDocument!.getPage(i);
      debugPrint('Page $i size: ${page.width} x ${page.height}');

      // Converting PDF points into pixels for printing.
      // https://www.gdpicture.com/guides/gdpicture/About%20a%20PDF%20format.html#:~:text=In%20PDF%20documents%2C%20everything%20is,for%20DIN%20A4%20page%20size.
      //  1 point = 1/72 inch
      //  72 points per inch
      // https://printninja.com/printing-resource-center/printninja-file-setup-checklist/offset-printing-guidelines/recommended-resolution/
      // 300 dpi = 300 pixels per inch
      final width = (page.width * 300 / 72).ceil();
      final height = (page.height * 300 / 72).ceil();
      PdfPageImage pagePdfImage = await page.render(
          width: width, height: height, allowAntialiasingIOS: true);
      ui.Image pageImage = await pagePdfImage.createImageDetached();
      ByteData? imageBytes =
          await pageImage.toByteData(format: ui.ImageByteFormat.png);

      if (imageBytes != null) {
        final result = await ImageGallerySaver.saveImage(
            imageBytes.buffer.asUint8List(),
            quality: 100,
            name: 'page_${i}_${DateTime.now().millisecondsSinceEpoch}');
        // ignore: unnecessary_brace_in_string_interps
        debugPrint("${result}");
      }
    }
  }
}
