// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:mrs_sdk_flutter/lints.dart';
import 'package:test/test.dart';

class _WidgetMemberOrderHarness extends AnalysisRuleTest {
  @override
  void setUp() {
    final flutterPackage = newPackage('flutter');
    flutterPackage.addFile('lib/widgets.dart', r'''
library widgets;

class Widget {
  const Widget({this.key});

  final Object? key;
}

class StatefulWidget extends Widget {
  const StatefulWidget({super.key});
}

class StatelessWidget extends Widget {
  const StatelessWidget({super.key});
}

abstract class State<T extends StatefulWidget> {}
''');
    rule = WidgetMemberOrderRule();
    super.setUp();
  }
}

Future<void> _withHarness(
  Future<void> Function(_WidgetMemberOrderHarness harness) body,
) async {
  final harness = _WidgetMemberOrderHarness();
  harness.setUp();
  try {
    await body(harness);
  } finally {
    await harness.tearDown();
  }
}

void main() {
  group('WidgetMemberOrder', () {
    test(
      'fields getters constructor lifecycle and methods are allowed',
      () async {
        await _withHarness((harness) async {
          await harness.assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';

class Example extends StatefulWidget {
  final int count = 0;

  int get value => count;

  set value(int next) {}

  const Example({super.key});

  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  final int count = 0;

  int get value => count;

  set value(int next) {}

  _ExampleState();

  void initState() {}

  void didChangeDependencies() {}

  Widget build() => const Widget();

  void didUpdateWidget(Object oldWidget) {}

  void reassemble() {}

  void deactivate() {}

  void dispose() {}

  void publicHelper() {}

  void _privateHelper() {}
}
''');
        });
      },
    );

    test('reports field after accessor', () async {
      await _withHarness((harness) async {
        await harness.assertDiagnostics(
          r'''
import 'package:flutter/widgets.dart';

class Example extends StatefulWidget {
  int get value => 1;

  final int count = 0;

  const Example({super.key});
}
''',
          [harness.lint(104, 20)],
        );
      });
    });

    test('reports build before didChangeDependencies', () async {
      await _withHarness((harness) async {
        await harness.assertDiagnostics(
          r'''
import 'package:flutter/widgets.dart';

class ExampleState extends State<Example> {
  Widget build() => const Widget();

  void didChangeDependencies() {}
}

class Example extends StatefulWidget {
  const Example({super.key});

  State<Example> createState() => ExampleState();
}
''',
          [harness.lint(123, 31)],
        );
      });
    });

    test('reports dispose before deactivate', () async {
      await _withHarness((harness) async {
        await harness.assertDiagnostics(
          r'''
import 'package:flutter/widgets.dart';

class ExampleState extends State<Example> {
  void dispose() {}

  void deactivate() {}
}

class Example extends StatefulWidget {
  const Example({super.key});

  State<Example> createState() => ExampleState();
}
''',
          [harness.lint(107, 20)],
        );
      });
    });

    test('reports public method before build', () async {
      await _withHarness((harness) async {
        await harness.assertDiagnostics(
          r'''
import 'package:flutter/widgets.dart';

class ExampleState extends State<Example> {
  void publicHelper() {}

  Widget build() => const Widget();
}

class Example extends StatefulWidget {
  const Example({super.key});

  State<Example> createState() => ExampleState();
}
''',
          [harness.lint(112, 33)],
        );
      });
    });

    test('reports on stateless widgets too', () async {
      await _withHarness((harness) async {
        await harness.assertDiagnostics(
          r'''
import 'package:flutter/widgets.dart';

class Example extends StatelessWidget {
  const Example({super.key});

  void publicHelper() {}

  Widget build() => const Widget();
}
''',
          [harness.lint(139, 33)],
        );
      });
    });
  });
}
