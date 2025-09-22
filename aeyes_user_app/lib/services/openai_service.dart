import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class OpenAIService {
  final String apiKey;

  OpenAIService(this.apiKey);

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
        "model": "gpt-4.1-mini",
        "input": [
          {
            "role": "user",
            "content": [
              {
                "type": "input_text",
                "text":
                    "Analyze this image for hazards a blind person should avoid.",
              },
              {"type": "input_image", "image_data": base64Image},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded["output"][0]["content"][0]["text"];
    } else {
      throw Exception("OpenAI error: ${response.body}");
    }
  }
}
