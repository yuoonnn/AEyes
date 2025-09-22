import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class OpenAIService {
  final String apiKey;

  OpenAIService(this.apiKey);

  /// Analyze an image (captured by ESP32-S3) for hazards
  Future<String> analyzeImage(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final url = Uri.parse("https://api.openai.com/v1/responses");

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "gpt-4.1-mini", // ✅ lightweight but vision-capable model
        "input": [
          {
            "role": "user",
            "content": [
              {
                "type": "input_text",
                "text":
                    "You are assisting a blind person. Analyze this image for navigation hazards like stairs, road debris, tables, chairs, street signs, or changes in elevation. Provide short, clear guidance to move safely.",
              },
              {"type": "input_image", "image_data": base64Image},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      try {
        // Extract the text output from the API response
        return decoded["output"][0]["content"][0]["text"];
      } catch (e) {
        throw Exception("Unexpected OpenAI response format: ${response.body}");
      }
    } else {
      throw Exception("OpenAI error: ${response.statusCode} ${response.body}");
    }
  }
}
