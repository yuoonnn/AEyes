import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() => runApp(CameraAnalyzerApp());

class CameraAnalyzerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'ESP32-CAM Analyzer', home: ImageCaptureScreen());
  }
}

class ImageCaptureScreen extends StatefulWidget {
  @override
  _ImageCaptureScreenState createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen> {
  BluetoothConnection? connection;
  String gptResponse = "";
  bool loading = false;

  Future<void> connectAndCapture(String address, String prompt) async {
    setState(() => loading = true);
    try {
      connection = await BluetoothConnection.toAddress(address);
      print('Connected to the device');

      connection!.output.add(utf8.encode("snap\n"));
      await connection!.output.allSent;

      // Wait for start marker
      Uint8List? imageData;
      List<int> buffer = [];

      while (true) {
        int byte = connection!.input!.readByteSync();
        if (byte == 0xAA && connection!.input!.readByteSync() == 0x55) {
          // Read length (4 bytes)
          Uint8List lenBytes = connection!.input!.read(4)!;
          int length = ByteData.sublistView(
            lenBytes,
          ).getUint32(0, Endian.little);
          buffer = connection!.input!.read(length)!.toList();

          // Read end marker
          if (connection!.input!.readByteSync() == 0x55 &&
              connection!.input!.readByteSync() == 0xAA) {
            imageData = Uint8List.fromList(buffer);
            break;
          }
        }
      }

      // Save image to temp file
      final dir = await getTemporaryDirectory();
      final imagePath = '${dir.path}/esp32_image.jpg';
      File imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageData!);

      // Send to OpenAI
      final responseText = await sendToOpenAI(imageData, prompt);
      setState(() => gptResponse = responseText);
    } catch (e) {
      print('Error: $e');
    } finally {
      connection?.dispose();
      setState(() => loading = false);
    }
  }

  Future<String> sendToOpenAI(Uint8List imageBytes, String prompt) async {
    final base64Image = base64Encode(imageBytes);
    const apiKey = "sk-..."; // Replace with your OpenAI API key

    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "gpt-4o",
        "messages": [
          {
            "role": "user",
            "content": [
              {"type": "text", "text": prompt},
              {
                "type": "image_url",
                "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["choices"][0]["message"]["content"].toString();
    } else {
      return "Error: ${response.body}";
    }
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController promptController = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: Text('ESP32-CAM GPT-4o')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: promptController,
              decoration: InputDecoration(labelText: 'Enter prompt/question'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () => connectAndCapture(
                      "00:00:00:00:00:00",
                      promptController.text,
                    ),
              child: Text('Capture & Ask'),
            ),
            SizedBox(height: 20),
            loading ? CircularProgressIndicator() : Text(gptResponse),
          ],
        ),
      ),
    );
  }
}
