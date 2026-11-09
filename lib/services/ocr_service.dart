import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<String> extractText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  List<double> extractNumbers(String text) {
    final RegExp numRegex = RegExp(r'\b\d{1,4}[.,]\d{1,3}\b');
    final matches = numRegex.allMatches(text);
    List<double> numbers = [];

    for (var match in matches) {
      String raw = match.group(0)!.replaceAll(',', '.');
      double? val = double.tryParse(raw);
      if (val != null) numbers.add(val);
    }
    return numbers;
  }

  Map<String, double> parseReceipt(String text) {
    List<double> nums = extractNumbers(text);
    if (nums.isEmpty) return {'liters': 0.0, 'pricePerLiter': 0.0, 'totalCost': 0.0};

    nums.sort();

    double totalCost = nums.last;
    double pricePerLiter = 0.0;
    double liters = 0.0;

    for (var n in nums) {
      if (n >= 1.10 && n <= 2.80 && pricePerLiter == 0.0) {
        pricePerLiter = n;
      }
    }

    if (pricePerLiter > 0 && totalCost > pricePerLiter) {
      liters = double.parse((totalCost / pricePerLiter).toStringAsFixed(2));
    }

    return {
      'liters': liters,
      'pricePerLiter': pricePerLiter,
      'totalCost': totalCost,
    };
  }

  double parseTripKm(String text) {
    List<double> nums = extractNumbers(text);
    for (var n in nums.reversed) {
      if (n >= 20.0 && n <= 1200.0) return n;
    }
    return 0.0;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
