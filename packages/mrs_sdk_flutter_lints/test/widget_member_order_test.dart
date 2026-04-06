// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:mrs_sdk_flutter_lints/mrs_sdk_flutter_lints.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

@reflectiveTest
class WidgetMemberOrderTest extends AnalysisRuleTest {
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

  void test_fields_getters_constructor_lifecycle_and_methods_are_allowed() async {
    await assertNoDiagnostics(
      r'''
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

  void dispose() {}

  Widget build() => const Widget();

  void publicHelper() {}

  void _privateHelper() {}
}
''',
    );
  }

  void test_reports_field_after_accessor() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';

class Example extends StatefulWidget {
  int get value => 1;

  final int count = 0;

  const Example({super.key});
}
''',
      [lint(104, 20)],
    );
  }

  void test_reports_dispose_before_build() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';

class ExampleState extends State<Example> {
  Widget build() => const Widget();

  void dispose() {}
}

class Example extends StatefulWidget {
  const Example({super.key});

  State<Example> createState() => ExampleState();
}
''',
      [lint(123, 17)],
    );
  }

  void test_reports_public_method_before_build() async {
    await assertDiagnostics(
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
      [lint(112, 33)],
    );
  }

  void test_reports_on_stateless_widgets_too() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';

class Example extends StatelessWidget {
  const Example({super.key});

  void publicHelper() {}

  Widget build() => const Widget();
}
''',
      [lint(139, 33)],
    );
  }
}

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(WidgetMemberOrderTest);
  });
}
