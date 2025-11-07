import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class OpenAIService {
  final String apiKey;

  OpenAIService(this.apiKey);

  /// Analyze an image (captured by ESP32-S3) for navigation hazards
  Future<String> analyzeImage(Uint8List imageBytes) async {
    // Convert image to Base64 and wrap in data URI
    final base64Image = base64Encode(imageBytes);
    final dataUri = "data:image/jpeg;base64,$base64Image";

    final url = Uri.parse("https://api.openai.com/v1/responses");

    final body = {
      "model": "gpt-4.1-mini",
      "input": [
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text":
                  "You are helping a blind person navigate. Analyze this image for potential hazards like stairs, debris, or obstacles. Give short and safe verbal guidance.",
            },
            {"type": "image_url", "image_url": dataUri},
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
