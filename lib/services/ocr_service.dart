import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

enum OcrErrorCode {
  invalidImage,
  serviceClosed,
  recognitionFailed,
}

class OcrException implements Exception {
  const OcrException({
    required this.code,
    required this.message,
  });

  final OcrErrorCode code;

  /// Safe message that may be displayed in the UI.
  final String message;

  @override
  String toString() => message;
}

class OcrService {
  OcrService({
    TextRecognizer? textRecognizer,
  }) : _textRecognizer =
      textRecognizer ??
          TextRecognizer(
            script: TextRecognitionScript.latin,
          );

  final TextRecognizer _textRecognizer;

  bool _closed = false;

  Future<String> readTextFromImage(String imagePath) async {
    final safeImagePath = imagePath.trim();

    if (safeImagePath.isEmpty) {
      throw const OcrException(
        code: OcrErrorCode.invalidImage,
        message: 'The selected image could not be opened.',
      );
    }

    if (_closed) {
      throw const OcrException(
        code: OcrErrorCode.serviceClosed,
        message: 'Local text recognition is temporarily unavailable.',
      );
    }

    try {
      final inputImage = InputImage.fromFilePath(safeImagePath);

      final recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      return recognizedText.text
          .replaceAll(RegExp(r'\r\n?'), '\n')
          .trim();
    } catch (error, stackTrace) {
      _debugLog(
        'Local OCR failed.',
        error,
        stackTrace,
      );

      throw const OcrException(
        code: OcrErrorCode.recognitionFailed,
        message:
        'Local text recognition could not read this image. '
            'The prescription image can still be analyzed using the '
            'AI image-reading workflow.',
      );
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }

    _closed = true;

    try {
      await _textRecognizer.close();
    } catch (error, stackTrace) {
      _debugLog(
        'OCR recognizer could not be closed cleanly.',
        error,
        stackTrace,
      );
    }
  }

  void _debugLog(
      String message,
      Object error,
      StackTrace stackTrace,
      ) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(message);
    debugPrint('$error');
    debugPrintStack(stackTrace: stackTrace);
  }
}