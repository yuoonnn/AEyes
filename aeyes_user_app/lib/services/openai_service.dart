import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

class OpenAIService {
  final String apiKey;

  OpenAIService(this.apiKey);

  /// Analyze an image with a custom prompt (voice command)
  /// If prompt is null, uses default navigation/hazard detection prompt
  Future<String> analyzeImageWithPrompt(
    Uint8List imageBytes, {
    String? customPrompt,
  }) async {
    return analyzeImage(imageBytes, prompt: customPrompt);
  }

  /// Analyze an image (captured by ESP32-S3) for navigation hazards
  /// [prompt] - Optional custom prompt from voice command. If null, uses default.
  Future<String> analyzeImage(Uint8List imageBytes, {String? prompt}) async {
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

    // Use standard OpenAI Chat Completions API with Vision
    final url = Uri.parse("https://api.openai.com/v1/chat/completions");

    final body = {
      "model": "gpt-4o",
      "max_tokens": 300,
      "messages": [
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text":
                  prompt ??
                  "You are acting as an assistive device for a blind individual. I need you to narrate what's in front of me. Point out any potential hazard or obstacles and provide a brief explanation and safe guidance if needed. If there are any signage, what do they say? If there's none disregard.",
            },
            {
              "type": "image_url",
              "image_url": {"url": dataUri},
            },
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
        // Extract text from standard OpenAI response format
        return decoded["choices"][0]["message"]["content"] as String;
      } catch (e) {
        throw Exception("Unexpected response format: ${response.body}");
      }
    } else {
      throw Exception("OpenAI error ${response.statusCode}: ${response.body}");
    }
  }

  /// Transcribe audio file to text using OpenAI Whisper API
  Future<String> transcribeAudio(String audioFilePath) async {
    final url = Uri.parse("https://api.openai.com/v1/audio/transcriptions");

    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw Exception("Audio file not found: $audioFilePath");
    }

    final audioBytes = await file.readAsBytes();

    // Create multipart request
    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $apiKey';

    // Add audio file
    request.files.add(
      http.MultipartFile.fromBytes('file', audioBytes, filename: 'audio.m4a'),
    );

    // Add model parameter
    request.fields['model'] = 'whisper-1';
    request.fields['language'] = 'en'; // Optional: specify language

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['text'] as String? ?? '';
    } else {
      throw Exception(
        "OpenAI Whisper error ${response.statusCode}: ${response.body}",
      );
    }
  }
}
