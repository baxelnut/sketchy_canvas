import 'dart:ui' as ui;
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:scribble/scribble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

class Canvas extends StatefulWidget {
  const Canvas({super.key});

  @override
  State<Canvas> createState() => _CanvasState();
}

class _CanvasState extends State<Canvas> {
  late ScribbleNotifier notifier;
  final GlobalKey _canvasKey = GlobalKey();

  Color pickerColor = const Color(0xff9A22A5);
  Color currentColor = Colors.black;
  Color canvasColor = Colors.white;

  @override
  void initState() {
    notifier = ScribbleNotifier();
    super.initState();
  }

  // Change canvas color
  void _setCanvasColor(Color color) {
    setState(() {
      canvasColor = color;
    });
  }

  // Set appbar icon color
  bool isColorLight(Color color) {
    final double luminance = color.computeLuminance();
    return luminance > 0.5;
  }

  // Set pen color
  void _setColor(Color color) {
    setState(() {
      currentColor = color;
      notifier.setColor(color);
    });
  }

  // Change pen color from color picker
  void _changeColor(Color color) {
    setState(() => pickerColor = color);
  }

  // Change pen size
  void _setStrokeWidth(double value) {
    notifier.setStrokeWidth(value);
    setState(() {});
  }

  // Request storage permission
  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission not granted');
      }
    }
  }

  // Pick a directory where to save the file
  _pickSaveDirectory() async {
    try {
      String? directoryPath = await FilePicker.platform.getDirectoryPath();
      if (directoryPath == null) {
        _savedConfirmed(false, '', '');
      } else {
        // print('Selected directory: $directoryPath');
      }
    } catch (e) {
      // print('Error picking directory: $e');
    }
  }

  // Get file path from user
  Future<String?> _getFilePathFromUser() async {
    TextEditingController nameController = TextEditingController();
    String? fileName;

    await _requestPermission();

    if (!mounted) return null;

    // Show dialog to get file name
    fileName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text('Save as PNG', style: Theme.of(context).textTheme.titleMedium),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
              labelText: 'Enter name here...',
              labelStyle: Theme.of(context).textTheme.bodyMedium),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child:
                Text('Cancel', style: Theme.of(context).textTheme.bodyMedium),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(nameController.text.trim());
            },
            child: Text('Save', style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );

    if (!mounted) return null;

    if (fileName != null) {
      // Pick directory after file name dialog is closed
      String? directoryPath = await _pickSaveDirectory();

      if (directoryPath != null) {
        // Combine directory path and file name
        return '$directoryPath/$fileName.png';
      }
    }

    return null;
  }

  void _exportCanvas(String format) async {
    switch (format) {
      case 'png':
        try {
          RenderRepaintBoundary boundary = _canvasKey.currentContext!
              .findRenderObject() as RenderRepaintBoundary;
          ui.Image image = await boundary.toImage(
              pixelRatio: MediaQuery.of(context).devicePixelRatio);
          ByteData? byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          Uint8List bytes = byteData!.buffer.asUint8List();

          if (!mounted) return;

          // Prompt user for file name and location
          String? filePath = await _getFilePathFromUser();

          if (filePath != null) {
            // Write the file
            File file = File(filePath);
            await file.writeAsBytes(bytes);

            // Show confirmation dialog with file details
            String fileName = filePath.split('/').last;
            if (mounted) _savedConfirmed(true, fileName, filePath);
          }
        } catch (e) {
          // Error handling
          if (mounted) _savedConfirmed(false, '', '');
        }
        break;
      case 'pdf':
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Apologies :(',
                  style: Theme.of(context).textTheme.titleMedium),
              content: Text(
                'Currently, conversion to PDF is not supported in this demo. Please stay tuned for future updates as we work to enhance our features.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (mounted) Navigator.of(context).pop();
                  },
                  child: Text('Close',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          );
        }
        break;

      case 'json':
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Sketch as JSON',
                  style: Theme.of(context).textTheme.titleMedium),
              content: SizedBox(
                child: SelectableText(
                  jsonEncode(notifier.currentSketch.toJson()),
                  autofocus: true,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Close',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                    final json = jsonEncode(notifier.currentSketch.toJson());
                    Clipboard.setData(ClipboardData(text: json));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                  child: Text('Copy',
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
              ],
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  void _savedConfirmed(
      bool successfullySaved, String fileName, String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(successfullySaved ? 'Sketch saved as PNG' : 'Error',
            style: Theme.of(context).textTheme.titleMedium),
        content: Text(
          successfullySaved
              ? 'The sketch has been saved as $fileName\n\nThe sketch has been saved in $filePath'
              : 'Failed to save sketch as PNG',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) Navigator.of(context).pop();
            },
            child: Text('OK', style: Theme.of(context).textTheme.bodyMedium),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isLight = isColorLight(canvasColor);
    Color iconColor = isLight ? Colors.black : Colors.white;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: canvasColor,
        leadingWidth: 50,
        leading: Builder(
          builder: (context) => IconButton(
            icon: ColorFiltered(
              colorFilter: ColorFilter.mode(
                iconColor,
                BlendMode.srcIn,
              ),
              child: SvgPicture.asset(
                'assets/icons/menu.svg',
              ),
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          _buildSize(),
          IconButton(
            onPressed: () {
              notifier.undo();
            },
            icon: SvgPicture.asset(
              'assets/icons/undo.svg',
              width: 35,
              height: 35,
            ),
          ),
          IconButton(
            onPressed: () {
              notifier.redo();
            },
            icon: SvgPicture.asset(
              'assets/icons/redo.svg',
              width: 35,
              height: 35,
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_rounded, size: 40, color: iconColor),
            onPressed: () => notifier.clear(),
          ),
        ],
      ),
      drawer: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).orientation == Orientation.landscape
              ? MediaQuery.of(context).size.width / 3
              : MediaQuery.of(context).size.width * 2 / 3,
          height: MediaQuery.of(context).orientation == Orientation.landscape
              ? MediaQuery.of(context).size.height * 1.5
              : MediaQuery.of(context).size.height,
          child: Drawer(
            backgroundColor: const Color(0xff87D3EC),
            child: Padding(
              padding:
                  MediaQuery.of(context).orientation == Orientation.landscape
                      ? const EdgeInsets.symmetric(horizontal: 10)
                      : const EdgeInsets.only(
                          top: 80, bottom: 20, left: 10, right: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Colors',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Divider(color: Colors.black, thickness: 0.5),
                  _buildColors(),
                  _buildColorPicker('color'),
                  Text('Canvas color',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Divider(color: Colors.black, thickness: 0.5),
                  _buildCanvasColors(),
                  _buildColorPicker('canvas'),
                  Text('Export as',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Divider(color: Colors.black, thickness: 0.5),
                  _buildExport(),
                  if (MediaQuery.of(context).orientation ==
                      Orientation.portrait)
                    const Spacer()
                  else
                    const SizedBox(height: 40),
                  Text(
                    'by Basilius Tengang',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        color: canvasColor,
        child: RepaintBoundary(
          key: _canvasKey,
          child: Scribble(
            notifier: notifier,
          ),
        ),
      ),
    );
  }

  Widget _buildColors() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(spacing: 0, children: [
        for (var color in [
          Colors.red,
          Colors.pinkAccent,
          Colors.deepOrange,
          Colors.orange,
          Colors.yellow,
          Colors.amberAccent,
          Colors.amber,
          Colors.green,
          Colors.lightGreen,
          Colors.lime,
          Colors.limeAccent,
          Colors.lightGreenAccent,
          Colors.teal,
          Colors.cyan,
          Colors.blue,
          Colors.lightBlue,
          Colors.indigo,
          Colors.blueAccent,
          Colors.purple,
          Colors.deepPurple,
          Colors.brown,
          Colors.grey,
          Colors.blueGrey,
          Colors.white,
          Colors.black,
        ])
          GestureDetector(
            onTap: () => _setColor(color),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: currentColor == color
                        ? Colors.white
                        : Colors.transparent,
                    width: 5,
                    strokeAlign: BorderSide.strokeAlignInside),
              ),
              child: CircleAvatar(
                backgroundColor: color,
                radius: 20,
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildColorPicker(String what) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: CircleAvatar(
        radius: 20,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: SvgPicture.asset(
            'assets/icons/color_wheel.svg',
            fit: BoxFit.fill,
          ),
          onPressed: () {
            Navigator.of(context).pop();
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xff87D3EC),
                title: Text(
                  'Pick a color',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                content: SingleChildScrollView(
                  child: ColorPicker(
                    pickerColor: pickerColor,
                    onColorChanged: _changeColor,
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text(
                      'SET COLOR',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    onPressed: () {
                      switch (what) {
                        case 'color':
                          setState(() => currentColor = pickerColor);
                          _setColor(currentColor);
                          break;
                        case 'canvas':
                          setState(() => canvasColor = pickerColor);
                          _setCanvasColor(canvasColor);
                          break;
                        default:
                          break;
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCanvasColors() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(spacing: 0, children: [
        for (var color in [
          Colors.white,
          Colors.black,
          Colors.grey,
          Colors.blueGrey,
        ])
          GestureDetector(
            onTap: () => _setCanvasColor(color),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: canvasColor == color
                        ? Colors.white
                        : Colors.transparent,
                    width: 5,
                    strokeAlign: BorderSide.strokeAlignInside),
              ),
              child: CircleAvatar(
                backgroundColor: color,
                radius: 20,
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildSize() {
    return Slider(
      value: notifier.value.selectedWidth.toDouble(),
      min: 1,
      max: 20,
      onChanged: (value) => _setStrokeWidth(value),
      activeColor: const Color(0xff9A22A5),
    );
  }

  Widget _buildExport() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        TextButton(
          onPressed: () => _exportCanvas('png'),
          child: Text('PNG', style: Theme.of(context).textTheme.labelMedium),
        ),
        TextButton(
          onPressed: () => _exportCanvas('pdf'),
          child: Text('PDF', style: Theme.of(context).textTheme.labelMedium),
        ),
        TextButton(
          onPressed: () => _exportCanvas('json'),
          child: Text('JSON', style: Theme.of(context).textTheme.labelMedium),
        ),
      ],
    );
  }
}
