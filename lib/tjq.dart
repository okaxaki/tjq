import 'package:tjq/ast.dart';
export './grammar.dart';
export './ast.dart';

class TJQParser {
  late final _parser = TJQAstDefinition().build();
  static final _singleton = TJQParser._();
  TJQParser._();
  factory TJQParser() {
    return _singleton;
  }
  TJQNode parse(String input) {
    return _parser.parse(input).value;
  }
}