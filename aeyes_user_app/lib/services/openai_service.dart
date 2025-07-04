import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      MaterialApp(home: ImageAnalyzerApp(), debugShowCheckedModeBanner: false);
}

class ImageAnalyzerApp extends StatefulWidget {
  @override
  _ImageAnalyzerAppState createState() => _ImageAnalyzerAppState();
}

class _ImageAnalyzerAppState extends State<ImageAnalyzerApp> {
  BluetoothConnection? connection;
  Uint8List imageBytes = Uint8List(0);
  String responseText = "";
  bool loading = false;

  final String apiKey = 'sk-...'; // Your OpenAI key
  final String model = 'gpt-4o';
  final TextEditingController _questionController = TextEditingController();

  Future<void> connectToBluetooth() async {
    final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    final device = devices.firstWhere(
      (d) => d.name == 'ESP32-CAM',
      orElse: () => throw Exception("ESP32-CAM not found"),
    );

    connection = await BluetoothConnection.toAddress(device.address);
    print("Connected to ESP32-CAM");
  }

  Future<void> sendSnapCommandAndReceiveImage() async {
    if (connection == null) await connectToBluetooth();
    connection!.output.add(Uint8List.fromList("snap\n".codeUnits));
    await connection!.output.allSent;

    List<int> buffer = [];
    bool inImage = false;
    int imgLen = 0;

    await for (var data in connection!.input!) {
      buffer.addAll(data);

      if (!inImage &&
          buffer.length >= 2 &&
          buffer[buffer.length - 2] == 0xAA &&
          buffer.last == 0x55) {
        inImage = true;
        buffer.clear();
        print("[START] Detected image start marker");
      } else if (inImage && buffer.length >= 4 && imgLen == 0) {
        imgLen = ByteData.sublistView(
          Uint8List.fromList(buffer),
        ).getUint32(0, Endian.little);
        print("[INFO] Expecting $imgLen bytes");
        buffer = buffer.sublist(4);
      } else if (inImage && buffer.length >= imgLen + 2) {
        if (buffer[imgLen] == 0x55 && buffer[imgLen + 1] == 0xAA) {
          imageBytes = Uint8List.fromList(buffer.sublist(0, imgLen));
          print("[END] Image received");
          break;
        } else {
          print("[ERROR] Invalid end marker");
          break;
        }
      }
    }
  }

  Future<void> sendToGPT4() async {
    setState(() => loading = true);

    final question = _questionController.text.trim();
    if (question.isEmpty || imageBytes.isEmpty) return;

    final base64Image = base64Encode(imageBytes);

    final body = jsonEncode({
      "model": model,
      "messages": [
        {
          "role": "user",
          "content": [
            {"type": "text", "text": question},
            {
              "type": "image_url",
              "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
            },
          ],
        },
      ],
      "max_tokens": 500,
    });

    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final jsonResp = jsonDecode(response.body);
      setState(
        () => responseText = jsonResp['choices'][0]['message']['content'],
      );
    } else {
      print("GPT-4o Error: ${response.body}");
      setState(() => responseText = "Failed to get response from OpenAI.");
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text("Blind Nav Assistant")),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _questionController,
            decoration: InputDecoration(
              labelText: "Ask something about the image...",
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await sendSnapCommandAndReceiveImage();
              await sendToGPT4();
            },
            child: Text("Capture & Analyze Image"),
          ),
          if (loading) CircularProgressIndicator(),
          if (responseText.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: Text("\nGPT-4o's Response:\n$responseText"),
              ),
            ),
        ],
      ),
    ),
  );
}
