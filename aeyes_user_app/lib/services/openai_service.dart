import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

class OpenAIService {
  final String apiKey;

  OpenAIService(this.apiKey);

  /// Analyze an image (captured by ESP32-S3) for navigation hazards
  Future<String> analyzeImage(Uint8List imageBytes) async {
    // Attempt to decode and re-encode to ensure a valid JPEG payload
    Uint8List bytesForApi = imageBytes;
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded != null) {
        final jpg = img.encodeJpg(decoded, quality: 85);
        bytesForApi = Uint8List.fromList(jpg);
      }
    } catch (_) {
      // If decoding fails, fall back to original bytes
    }

    // Convert to Base64 and data URI
    final base64Image = base64Encode(bytesForApi);
    final dataUri = "data:image/jpeg;base64,$base64Image";

    final url = Uri.parse("https://api.openai.com/v1/responses");

    final body = {
      "model": "gpt-4.1-mini",
      "input": [
        {
          "role": "user",
          "content": [
            {
              "type": "input_text",
              "text":
                  "You are assisting a blind user. Do three things in order: 1) Briefly describe the scene in one short sentence. 2) Identify potential hazards or obstacles and provide concise, safe guidance with relative position/distance. 3) If currency/banknotes or coins are visible, state their denominations and the total amount visible. Keep the whole response clear and brief.",
            },
            {"type": "input_image", "image_url": dataUri},
          ],
        },
      ],
    };

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      try {
        // Extract text output from response
        return decoded["output"][0]["content"][0]["text"];
      } catch (e) {
        throw Exception("Unexpected response format: ${response.body}");
      }
    } else {
      throw Exception("OpenAI error ${response.statusCode}: ${response.body}");
    }
  }
}
