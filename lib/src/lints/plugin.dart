import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'rules/widget_member_order.dart';

class MrsSdkFlutterPlugin extends Plugin {
  @override
  String get name => 'mrs_sdk_flutter';

  @override
  void register(PluginRegistry registry) {
    registry.registerLintRule(WidgetMemberOrderRule());
  }
}
