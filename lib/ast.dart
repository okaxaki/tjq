import 'package:petitparser/petitparser.dart';
import 'package:tjq/grammar.dart';

List _flatten(List arr) => arr.fold(
      [],
      (value, element) => [
        ...value,
        ...(element is List ? _flatten(element) : [element])
      ],
    );

List<T> _filterAndCast<T>(List list) =>
    list.where((e) => e is T).cast<T>().toList();

class UnbraketedList {
  final List data;
  UnbraketedList._(this.data);

  static dynamic createOrSingleData(List data) {
    if (data.length == 0) {
      return null;
    }
    if (data.length == 1) {
      return data[0];
    }
    return UnbraketedList._(data);
  }

  get map => data.map;
  get where => data.where;
  get firstWhere => data.firstWhere;
  get any => data.any;
  get length => data.length;
  List operator [](dynamic key) {
    return data.map((e) => e[key]).toList();
  }

  toJson() => data;
}

abstract class TJQNode {
  dynamic eval(dynamic env);
  Map<String, dynamic> toJson();
}

class StatementNode extends TJQNode {
  final List<TJQNode> children;
  StatementNode(this.children) : assert(children.length > 2);

  dynamic eval(dynamic env) {
    var res = env;
    for (var child in children) {
      res = child.eval(res);
    }
    return res;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'children': children.map((e) => e.toJson()).toList(),
    };
  }
}

class ExprNode extends TJQNode {
  final List<TJQNode> children;
  ExprNode(this.children) : assert(children.length > 2);

  dynamic eval(dynamic env) {
    return UnbraketedList.createOrSingleData(
        children.map((e) => e.eval(env)).toList());
  }

  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'children': children.map((e) => e.toJson()).toList(),
    };
  }
}

class SelectNode extends TJQNode {
  final TJQNode expr;
  SelectNode(this.expr);
  dynamic eval(dynamic env) {
    if (env is UnbraketedList) {
      return UnbraketedList.createOrSingleData(
          env.where((e) => expr.eval(e) as bool).toList());
    }
    if (env is List || env is UnbraketedList) {
      return env.where((e) => expr.eval(e) as bool).toList();
    }
    throw "select operation cannot be applied to ${env.runtimeType}";
  }

  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'expr': expr.toJson(),
    };
  }
}

class LengthNode extends TJQNode {
  LengthNode();
  dynamic eval(dynamic env) {
    return env?.length ?? env;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
    };
  }
}

class ContainsNode extends TJQNode {
  final TJQNode expr;
  ContainsNode(this.expr);
  dynamic eval(dynamic env) {
    if (env is List || env is UnbraketedList) {
      final matcher = expr.eval(env);
      if (matcher is RegExp) {
        return env.any((e) => matcher.hasMatch(e));
      } else {
        return env.any((e) => matcher == e);
      }
    }
    throw "contains operation cannot be applied to ${env.runtimeType}";
  }

  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'expr': expr.toJson(),
    };
  }
}

class UnaryOperatorNode extends TJQNode {
  final TJQNode expr;
  final Function(dynamic o) op;
  UnaryOperatorNode(this.expr, this.op);
  dynamic eval(dynamic env) => this.op(expr.eval(env));
  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'expr': expr.toJson(),
    };
  }
}

class OperationNode extends TJQNode {
  final String op;
  final TJQNode lhs;
  final TJQNode rhs;
  OperationNode(this.op, this.lhs, this.rhs);
  dynamic eval(dynamic env) {
    final l = lhs.eval(env);
    final r = rhs.eval(env);
    switch (op) {
      case '||':
        return l || r;
      case '&&':
        return l && r;
      case '==':
        return l == r;
      case '!=':
        return l != r;
      case '<=':
        return l <= r;
      case '>=':
        return l >= r;
      case '<':
        return l < r;
      case '>':
        return l > r;
      case '+':
        return l + r;
      case '-':
        return l - r;
      case '*':
        return l * r;
      case '/':
        return l / r;
      case '%':
        return l % r;
      default:
        throw "Unknown operator $op";
    }
  }

  // lhs & (op & rhs)* => [lhs, [[op, rhs]] | [lhs, []]
  // lhs & (op & rhs)? => [lhs, rhs] | [lhs, null]

  static buildLeftAssoc(List values) {
    final args = _flatten(values).where((e) => e != null).toList();
    if (args.length == 1) {
      return args[0];
    }
    assert(args.length >= 3);
    var node = OperationNode((args[1] as Token).value, args[0], args[2]);
    for (int i = 3; i < args.length; i += 2) {
      node = OperationNode((args[i] as Token).value, node, args[i + 1]);
    }
    return node;
  }

  static buildRightAssoc(List values) {
    final args = _flatten(values).where((e) => e != null).toList();
    if (args.length == 1) {
      return args[0];
    }
    assert(args.length >= 3);

    var node = OperationNode((args[args.length - 2] as Token).value,
        args[args.length - 3], args[args.length - 1]);
    for (int i = args.length - 4; i >= 0; i -= 2) {
      node = OperationNode((args[i] as Token).value, args[i - 1], node);
    }
    return node;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'op': op,
      'lhs': lhs.toJson(),
      'rhs': rhs.toJson(),
    };
  }
}

class PostfixNode extends TJQNode {
  final TJQNode expr;
  final TJQNode suffix;
  PostfixNode(this.expr, this.suffix);

  dynamic eval(dynamic env) => suffix.eval(expr.eval(env));

  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'expr': expr,
    };
  }
}

class SelectorNode extends TJQNode {
  final List<TJQNode> children;
  SelectorNode(this.children);

  dynamic eval(dynamic env) {
    dynamic cur = env;
    for (var child in children) {
      if (cur == null) break;

      if (child is SubscriptionNode) {
        cur = child.eval(cur, env);
      } else if (child is PropertyAccessNode) {
        cur = child.eval(cur);
      } else {
        throw "Internal Error";
      }
    }
    return cur;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'children': children.map((e) => e.toJson()).toList(),
    };
  }
}

class IdentifierNode extends TJQNode {
  final String value;
  IdentifierNode(this.value);
  dynamic eval(dynamic env) => null;
  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'value': value,
    };
  }
}

class PropertyAccessNode extends TJQNode {
  final IdentifierNode? identifier;
  PropertyAccessNode(this.identifier);
  dynamic eval(dynamic env) {
    if (identifier != null) {
      return env?[identifier!.value];
    }
    return env;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'identifier': identifier?.value,
    };
  }
}

class SubscriptionNode extends TJQNode {
  final TJQNode? expr;
  SubscriptionNode(this.expr);

  @override
  dynamic eval(dynamic env, [dynamic outerEnv]) {
    if (expr != null) {
      final key = expr!.eval(outerEnv);
      return env[key];
    }

    if (env is List) {
      return UnbraketedList.createOrSingleData(env);
    } else if (env is Map) {
      return env.values;
    }
    throw "[] operator cannot be applied on ${env.runtimeType}";
  }

  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      if (expr != null) 'expr': expr!.toJson(),
    };
  }
}

class ListBuilderNode extends TJQNode {
  final List<TJQNode> children;
  ListBuilderNode(this.children);

  dynamic eval(dynamic env) {
    return children.map((e) => e.eval(env)).fold<List>(
        [],
        (value, element) => [
              ...value,
              if (element is UnbraketedList) ...element.data else element,
            ]);
  }

  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'children': children.map((e) => e.toJson()).toList(),
    };
  }
}

class MapBuilderNode extends TJQNode {
  final List<KeyValuePairNode> children;
  MapBuilderNode(this.children);

  dynamic eval(dynamic env) {
    final res = {};
    for (final child in children) {
      res[child.key.value] = child.value.eval(env);
    }
    return res;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'children': children.map((e) => e.toJson()).toList(),
    };
  }
}

class KeyValuePairNode extends TJQNode {
  final IdentifierNode key;
  final TJQNode value;
  KeyValuePairNode(this.key, this.value);
  dynamic eval(dynamic env) => value.eval(env);
  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'key': key.value,
      'value': value,
    };
  }
}

class ConstantNode extends TJQNode {
  final dynamic value;
  ConstantNode(this.value);
  dynamic eval(dynamic env) => value;
  Map<String, dynamic> toJson() {
    return {
      'type': this.runtimeType.toString(),
      'value': value.toString(),
    };
  }
}

class TJQAstDefinition extends TJQGrammerDefinition {
  Parser statement() => super.statement().map((values) {
        final args = _filterAndCast<TJQNode>(_flatten(values));
        if (values.length > 1) {
          return StatementNode(args);
        }
        return values[0];
      });

  Parser expr() => super.expr().map(
        (values) {
          final args = _filterAndCast<TJQNode>(_flatten(values));
          if (args.length > 1) {
            return ExprNode(args);
          }
          return values[0];
        },
      );

  Parser logicalOr() =>
      super.logicalOr().map((values) => OperationNode.buildLeftAssoc(values));
  Parser logicalAnd() =>
      super.logicalAnd().map((values) => OperationNode.buildLeftAssoc(values));

  Parser relation() =>
      super.relation().map((values) => OperationNode.buildLeftAssoc(values));
  Parser equality() =>
      super.equality().map((values) => OperationNode.buildLeftAssoc(values));

  Parser add() =>
      super.add().map((values) => OperationNode.buildLeftAssoc(values));
  Parser mul() =>
      super.mul().map((values) => OperationNode.buildLeftAssoc(values));

  Parser stringLiteral() => super.stringLiteral().map((value) {
        final s = value as String;
        return s.substring(1, s.length - 1);
      });

  Parser numberLiteral() =>
      super.numberLiteral().map((value) => num.parse(value));

  Parser boolLiteral() =>
      super.boolLiteral().map((token) => token.value == 'true');

  Parser regexpLiteral() => super
      .regexpLiteral()
      .map((values) => RegExp(values[1], caseSensitive: values[3] != 'i'));

  Parser subscript() => super.subscript().map((values) {
        return SubscriptionNode(values.length == 3 ? values[1] : null);
      });

  Parser postfix() => super.postfix().map((values) {
        final args = _filterAndCast<TJQNode>(values);
        if (args.length == 2) {
          return PostfixNode(args[0], args[1]);
        }
        return values;
      });

  Parser selector() => super.selector().map((values) {
        if (values is List) {
          return SelectorNode(_filterAndCast<TJQNode>(_flatten(values)));
        }
        return values;
      });

  Parser prim() => super.prim().map((values) {
        return values;
      });

  Parser propertyAccess() =>
      super.propertyAccess().map((values) => PropertyAccessNode(values[1]));

  Parser constant() => super.constant().map((values) {
        return ConstantNode(values);
      });

  Parser parens() => super.parens().map((values) => values[1]);

  Parser selectFunc() =>
      super.selectFunc().map((values) => SelectNode(values[2]));

  Parser containsFunc() =>
      super.containsFunc().map((values) => ContainsNode(values[2]));

  Parser lengthFunc() => super.lengthFunc().map((values) => LengthNode());

  Parser listBuilder() => super.listBuilder().map((values) {
        return ListBuilderNode(_filterAndCast<TJQNode>(values));
      });

  Parser identifier() => super.identifier().map((value) {
        if (value is Token) {
          return IdentifierNode(value.value);
        }
        return IdentifierNode(value);
      });

  Parser mapBuilder() => super.mapBuilder().map((values) {
        return MapBuilderNode(
            _filterAndCast<KeyValuePairNode>(_flatten(values)));
      });

  Parser keyValuePair() => super
      .keyValuePair()
      .map((values) => KeyValuePairNode(values[0], values[2]));
}
