class OpenAIService {
  // TODO: Implement OpenAI API communication methods

  // Mock process image method
  Future<String> processImage(String imageData) async {
    await Future.delayed(const Duration(seconds: 2));
    return 'OpenAI describes the image: A person wearing smart glasses, standing outdoors.';
  }
} 