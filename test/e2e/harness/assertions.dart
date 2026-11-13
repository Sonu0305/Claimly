/// Reusable assertion helpers and lightweight test runner for Claimly Opaque-Box E2E tests.
import 'dart:async';
import 'dart:io';

class E2EAssertionException implements Exception {
  final String message;
  final dynamic expected;
  final dynamic actual;
  final StackTrace? stackTrace;

  E2EAssertionException(
    this.message, {
    this.expected,
    this.actual,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('E2EAssertionException: $message');
    if (expected != null || actual != null) {
      buffer.write('\n  Expected: $expected\n  Actual:   $actual');
    }
    return buffer.toString();
  }
}

class Assertions {
  static void equal<T>(T actual, T expected, [String? message]) {
    if (actual != expected) {
      throw E2EAssertionException(
        message ?? 'Values are not equal',
        expected: expected,
        actual: actual,
      );
    }
  }

  static void notEqual<T>(T actual, T expected, [String? message]) {
    if (actual == expected) {
      throw E2EAssertionException(
        message ?? 'Values must not be equal',
        expected: 'anything other than $expected',
        actual: actual,
      );
    }
  }

  static void isTrue(bool condition, [String? message]) {
    if (!condition) {
      throw E2EAssertionException(
        message ?? 'Condition is not true',
        expected: true,
        actual: false,
      );
    }
  }

  static void isFalse(bool condition, [String? message]) {
    if (condition) {
      throw E2EAssertionException(
        message ?? 'Condition is not false',
        expected: false,
        actual: true,
      );
    }
  }

  static void notNull(dynamic value, [String? message]) {
    if (value == null) {
      throw E2EAssertionException(
        message ?? 'Value is null',
        expected: 'non-null',
        actual: null,
      );
    }
  }

  static void isNull(dynamic value, [String? message]) {
    if (value != null) {
      throw E2EAssertionException(
        message ?? 'Value is not null',
        expected: null,
        actual: value,
      );
    }
  }

  static void inRange(num value, num min, num max, [String? message]) {
    if (value < min || value > max) {
      throw E2EAssertionException(
        message ?? 'Value is out of expected range [$min, $max]',
        expected: '[$min, $max]',
        actual: value,
      );
    }
  }

  static void greaterThan(num actual, num threshold, [String? message]) {
    if (actual <= threshold) {
      throw E2EAssertionException(
        message ?? 'Value is not greater than threshold',
        expected: '> $threshold',
        actual: actual,
      );
    }
  }

  static void contains(String haystack, String needle, [String? message]) {
    if (!haystack.contains(needle)) {
      throw E2EAssertionException(
        message ?? 'String does not contain substring',
        expected: 'substring: "$needle"',
        actual: haystack,
      );
    }
  }

  static void matches(String text, RegExp pattern, [String? message]) {
    if (!pattern.hasMatch(text)) {
      throw E2EAssertionException(
        message ?? 'String does not match pattern',
        expected: pattern.pattern,
        actual: text,
      );
    }
  }

  static void notEmpty(Iterable iterable, [String? message]) {
    if (iterable.isEmpty) {
      throw E2EAssertionException(
        message ?? 'Collection is empty',
        expected: 'non-empty collection',
        actual: 'empty',
      );
    }
  }

  static void empty(Iterable iterable, [String? message]) {
    if (iterable.isNotEmpty) {
      throw E2EAssertionException(
        message ?? 'Collection is not empty',
        expected: 'empty collection',
        actual: 'length ${iterable.length}',
      );
    }
  }

  static void length(Iterable iterable, int expectedLength, [String? message]) {
    if (iterable.length != expectedLength) {
      throw E2EAssertionException(
        message ?? 'Collection length mismatch',
        expected: expectedLength,
        actual: iterable.length,
      );
    }
  }

  static void jsonContainsKey(Map map, String key, [String? message]) {
    if (!map.containsKey(key)) {
      throw E2EAssertionException(
        message ?? 'Map does not contain expected key "$key"',
        expected: 'key: "$key"',
        actual: map.keys.toList(),
      );
    }
  }

  static void jsonValue(Map map, String key, dynamic expectedValue, [String? message]) {
    jsonContainsKey(map, key, message);
    if (map[key] != expectedValue) {
      throw E2EAssertionException(
        message ?? 'Map value for key "$key" mismatch',
        expected: expectedValue,
        actual: map[key],
      );
    }
  }

  static void httpStatus(int actual, int expected, [String? responseBody]) {
    if (actual != expected) {
      throw E2EAssertionException(
        'HTTP Status mismatch. Response body: ${responseBody ?? "(empty)"}',
        expected: 'HTTP $expected',
        actual: 'HTTP $actual',
      );
    }
  }

  static void httpSuccess(int statusCode, [String? responseBody]) {
    if (statusCode < 200 || statusCode >= 300) {
      throw E2EAssertionException(
        'Expected HTTP 2xx Success. Response body: ${responseBody ?? "(empty)"}',
        expected: 'HTTP 200..299',
        actual: 'HTTP $statusCode',
      );
    }
  }

  static Future<void> throwsAsync<T extends Object>(
    Future<void> Function() action, [
    String? message,
  ]) async {
    try {
      await action();
      throw E2EAssertionException(
        message ?? 'Expected exception of type $T was not thrown',
        expected: 'Throws $T',
        actual: 'No exception thrown',
      );
    } catch (e) {
      if (e is E2EAssertionException && e.message.contains('was not thrown')) {
        rethrow;
      }
      if (e is! T) {
        throw E2EAssertionException(
          'Threw unexpected exception type ${e.runtimeType} instead of $T: $e',
          expected: T.toString(),
          actual: e.runtimeType.toString(),
        );
      }
    }
  }
}

/// Lightweight test case structure and suite runner.
typedef TestCaseBody = Future<void> Function();

class TestCase {
  final String id;
  final String title;
  final TestCaseBody body;

  const TestCase({
    required this.id,
    required this.title,
    required this.body,
  });
}

class TestSuiteResult {
  final String suiteName;
  final int total;
  final int passed;
  final int failed;
  final int durationMs;
  final List<String> failureDetails;

  const TestSuiteResult({
    required this.suiteName,
    required this.total,
    required this.passed,
    required this.failed,
    required this.durationMs,
    required this.failureDetails,
  });

  bool get isSuccess => failed == 0;
}

class E2ETestRunner {
  final String suiteName;
  final List<TestCase> _testCases = [];

  E2ETestRunner(this.suiteName);

  void addTest(String id, String title, TestCaseBody body) {
    _testCases.add(TestCase(id: id, title: title, body: body));
  }

  Future<TestSuiteResult> run({bool verbose = false}) async {
    final stopwatch = Stopwatch()..start();
    int passed = 0;
    int failed = 0;
    final failureDetails = <String>[];

    print('════════════════════════════════════════════════════════════════');
    print('SUITE: $suiteName (${_testCases.length} cases)');
    print('════════════════════════════════════════════════════════════════');

    for (final tc in _testCases) {
      final caseWatch = Stopwatch()..start();
      try {
        await tc.body();
        caseWatch.stop();
        passed++;
        print('  ✓ [PASS] [${tc.id}] ${tc.title} (${caseWatch.elapsedMilliseconds}ms)');
      } catch (e, st) {
        caseWatch.stop();
        failed++;
        final detail = '  ✗ [FAIL] [${tc.id}] ${tc.title} (${caseWatch.elapsedMilliseconds}ms)\n    Error: $e';
        failureDetails.add(detail);
        print(detail);
        if (verbose) {
          print('    Stack trace:');
          for (final line in st.toString().split('\n').take(5)) {
            print('      $line');
          }
        }
      }
    }

    stopwatch.stop();
    print('----------------------------------------------------------------');
    print('Suite "$suiteName" Completed: $passed passed, $failed failed (${stopwatch.elapsedMilliseconds}ms)');
    print('════════════════════════════════════════════════════════════════\n');

    return TestSuiteResult(
      suiteName: suiteName,
      total: _testCases.length,
      passed: passed,
      failed: failed,
      durationMs: stopwatch.elapsedMilliseconds,
      failureDetails: failureDetails,
    );
  }

  /// Runs the suite and exits cleanly unless running under flutter test.
  Future<TestSuiteResult> runAndExit({bool verbose = false}) async {
    final result = await run(verbose: verbose);
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      exit(result.isSuccess ? 0 : 1);
    }
    return result;
  }
}

/// Helper function to safely exit with a test suite result without killing flutter test runner.
void safeExitWithResult(TestSuiteResult result) {
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    exit(result.isSuccess ? 0 : 1);
  }
}
