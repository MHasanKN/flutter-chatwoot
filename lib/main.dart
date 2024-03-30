import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:webview_flutter_android/webview_flutter_android.dart'
    as webview_flutter_android;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:file_picker/file_picker.dart';

void main() => runApp(MaterialApp(home: const PreviewWebpage()));
final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

class PreviewWebpage extends StatefulWidget {
  const PreviewWebpage({super.key});

  @override
  State<PreviewWebpage> createState() => _PreviewWebpageState();
}

class _PreviewWebpageState extends State<PreviewWebpage> {
  late WebViewController _controller;
  HttpServer? _server;
  String? _localUrl;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (int progress) {},
        onPageStarted: (String url) {},
        onPageFinished: (String url) {},
        onWebResourceError: (WebResourceError error) {},
      ));

    // Start the local server and load the local webpage
    _startLocalServer();
    initFilePicker();
  }

  initFilePicker() async {
    if (Platform.isAndroid) {
      final androidController = (_controller.platform
          as webview_flutter_android.AndroidWebViewController);
      await androidController.setOnShowFileSelector(_androidFilePicker);
    }
  }

  /// This method is called when the user tries to upload a file from the webview.
  /// It will open the file picker and return the selected files.
  /// If the user cancels the file picker, it will return an empty list.
  ///
  /// Returns uri's of the selected files.
  Future<List<String>> _androidFilePicker(
      webview_flutter_android.FileSelectorParams params) async {
    final BuildContext? context = _scaffoldKey.currentContext;
    // Function to pick image from source
    Future<image_picker.XFile?> _pickImage(
        {required image_picker.ImageSource source}) async {
      final picker = image_picker.ImagePicker();
      return await picker.pickImage(source: source);
    }

    // Function to show choice dialog
    Future<image_picker.ImageSource?> _showImageSourceChoice(
        BuildContext context) async {
      return await showDialog<image_picker.ImageSource>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text('Choose image source'),
                actions: <Widget>[
                  TextButton(
                    child: Text('Camera'),
                    onPressed: () =>
                        Navigator.pop(context, image_picker.ImageSource.camera),
                  ),
                  TextButton(
                    child: Text('Gallery'),
                    onPressed: () => Navigator.pop(
                        context, image_picker.ImageSource.gallery),
                  ),
                ],
              ));
    }

// Ensure we have a non-null context before proceeding
    if (context == null) {
      print('No valid context to show dialog.');
      return []; // Return empty list or handle accordingly
    }
    if (params.acceptTypes.any((type) => type == 'image/*')) {
      final source = await _showImageSourceChoice(context);
      if (source == null) return []; // User cancelled the choice dialog

      final photo = await _pickImage(source: source);
      if (photo == null) return []; // No photo was picked
      return [Uri.file(photo.path).toString()];
    } else {
      try {
        if (params.mode ==
            webview_flutter_android.FileSelectorMode.openMultiple) {
          final attachments =
              await FilePicker.platform.pickFiles(allowMultiple: true);
          if (attachments == null) return [];

          return attachments.files
              .where((element) => element.path != null)
              .map((e) => Uri.file(e.path!).toString())
              .toList();
        } else {
          final attachment = await FilePicker.platform.pickFiles();
          if (attachment == null) return [];
          return [Uri.file(attachment.files.single.path!).toString()];
        }
      } catch (e) {
        return [];
      }
    }
  }

  Future<void> _startLocalServer() async {
    final router = shelf_router.Router();

    router.get('/', (shelf.Request request) async {
      String fileText = await DefaultAssetBundle.of(context)
          .loadString('assets/chatwoot.html');
      const String userEmail = 'testingemail3@example.com';
      const String userName = 'Test Human';
      const String userId = 'test_user_id_3';
      fileText = fileText
          .replaceFirst('user_email_replace', userEmail)
          .replaceFirst('user_name_replace', userName)
          .replaceFirst('user_id_replace', userId);
      return shelf.Response.ok(fileText,
          headers: {'content-type': 'text/html'});
    });

    _server = await shelf_io.serve(router, 'localhost', 0);
    setState(() {
      _localUrl = 'http://localhost:${_server!.port}';
      // After the server is started, load the local webpage
      _controller.loadRequest(Uri.parse(_localUrl!));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Attach files Iframe [Flutter]"),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }
}
