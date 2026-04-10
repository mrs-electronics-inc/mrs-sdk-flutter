import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Enforces the current Flutter widget member order.
///
/// The lifecycle portion follows the Flutter
/// [State](https://api.flutter.dev/flutter/widgets/State-class.html) docs.
///
/// The expected order is:
/// fields and constants, getters and setters, constructor, `initState`,
/// `didChangeDependencies`, `build`, `didUpdateWidget`, `reassemble`,
/// `deactivate`, `dispose`, public methods, private methods.
class WidgetMemberOrderRule extends AnalysisRule {
  WidgetMemberOrderRule()
    : super(
        name: 'widget_member_order',
        description:
            'Enforce member ordering in Flutter widget and State classes.',
      );

  @override
  bool get canUseParsedResult => false;

  @override
  DiagnosticCode get diagnosticCode => const LintCode(
    'widget_member_order',
    'Place members in the expected Flutter widget order.',
    correctionMessage: 'Move this member to its expected location.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(this, _WidgetMemberOrderVisitor(this));
  }
}

class _WidgetMemberOrderVisitor extends SimpleAstVisitor<void> {
  _WidgetMemberOrderVisitor(this.rule);

  final WidgetMemberOrderRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final fragment = node.declaredFragment;
    if (fragment == null || !_isTargetClass(fragment.element)) {
      return;
    }

    var highestOrder = -1;
    if (node.body case BlockClassBody body) {
      for (final member in body.members) {
        final order = _orderFor(member);
        if (order == null) {
          continue;
        }

        if (order < highestOrder) {
          rule.reportAtNode(member);
        } else {
          highestOrder = order;
        }
      }
    }
  }

  bool _isTargetClass(ClassElement element) {
    if (_isFlutterWidgetType(element, 'StatefulWidget') ||
        _isFlutterWidgetType(element, 'StatelessWidget') ||
        _isFlutterWidgetType(element, 'State')) {
      return true;
    }

    return element.allSupertypes.any(
      (type) =>
          _isFlutterWidgetType(type.element, 'StatefulWidget') ||
          _isFlutterWidgetType(type.element, 'StatelessWidget') ||
          _isFlutterWidgetType(type.element, 'State'),
    );
  }

  bool _isFlutterWidgetType(InterfaceElement element, String name) {
    final libraryUri = element.library.firstFragment.source.uri.toString();
    return element.name == name && libraryUri.startsWith('package:flutter/');
  }

  int? _orderFor(ClassMember member) {
    if (member is FieldDeclaration) {
      return 0;
    }

    if (member is ConstructorDeclaration) {
      return 2;
    }

    if (member is MethodDeclaration) {
      if (member.isGetter || member.isSetter) {
        return 1;
      }

      final name = member.name.lexeme;
      if (name == 'initState') {
        return 3;
      }
      if (name == 'didChangeDependencies') {
        return 4;
      }
      if (name == 'build') {
        return 5;
      }
      if (name == 'didUpdateWidget') {
        return 6;
      }
      if (name == 'reassemble') {
        return 7;
      }
      if (name == 'deactivate') {
        return 8;
      }
      if (name == 'dispose') {
        return 9;
      }
      return name.startsWith('_') ? 11 : 10;
    }

    return null;
  }
}
