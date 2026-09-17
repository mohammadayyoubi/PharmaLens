import 'package:flutter_test/flutter_test.dart';
import 'package:pharmalens/services/ai_handwriting_service.dart';

void main() {
  group('AiHandwritingException', () {
    test('keeps its safe UI message', () {
      const exception = AiHandwritingException(
        code: AiHandwritingErrorCode.serviceUnavailable,
        message: 'Prescription analysis is temporarily unavailable.',
      );

      expect(
        exception.toString(),
        'Prescription analysis is temporarily unavailable.',
      );

      expect(exception.code, AiHandwritingErrorCode.serviceUnavailable);

      expect(exception.retryable, isTrue);
    });

    test('supports non-retryable validation errors', () {
      const exception = AiHandwritingException(
        code: AiHandwritingErrorCode.invalidImage,
        message: 'The prescription image could not be processed.',
        retryable: false,
      );

      expect(exception.retryable, isFalse);

      expect(exception.code, AiHandwritingErrorCode.invalidImage);
    });
  });
}
