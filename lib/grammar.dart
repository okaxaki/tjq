import 'package:petitparser/petitparser.dart';

class TJQGrammerDefinition extends GrammarDefinition {
  Parser start() => ref0(statement).trim().end();

  Parser newlineLexicalToken() => pattern('\n\r');

  Parser hiddenWhitespace() => ref0(hiddenStuffWhitespace).plus();

  Parser hiddenStuffWhitespace() =>
      ref0(visibleWhitespace) |
      ref0(singleLineComment) |
      ref0(multiLineComment);

  Parser visibleWhitespace() => whitespace();

  Parser singleLineComment() =>
      string('//') &
      ref0(newlineLexicalToken).neg().star() &
      ref0(newlineLexicalToken).optional();

  Parser multiLineComment() =>
      string('/*') &
      (ref0(multiLineComment) | string('*/').neg()).star() &
      string('*/');

  Parser token(String input) {
    return input.toParser().token().trim(ref0(hiddenStuffWhitespace));
  }

  Parser stringLiteral() => (char('"') & pattern('^"').star() & char('"') |
          char("'") & pattern("^'").star() & char("'"))
      .flatten();

  Parser identifier() =>
      ref0(stringLiteral) | (word() | char('-')).plus().flatten().token();
  Parser boolLiteral() => ref1(token, 'true') | ref1(token, 'false');
  Parser numberLiteral() =>
      (digit().plus() & (char('.') & digit().plus()).optional()).flatten();
  Parser regexpLiteral() =>
      char('/') &
      pattern('^/').plus().flatten() &
      char('/') &
      char('i').optional();

  Parser relOp() =>
      ref1(token, '<=') |
      ref1(token, '>=') |
      ref1(token, '<') |
      ref1(token, '>');

  Parser eqOp() => ref1(token, '==') | ref1(token, '!=');

  Parser statement() => ref0(expr) & (ref1(token, '|') & ref0(expr)).star();

  Parser expr() =>
      ref0(logicalOr) & (ref1(token, ',') & ref0(logicalOr)).star();

  Parser logicalOr() =>
      ref0(logicalAnd) & (ref1(token, '||') & ref0(logicalAnd)).star();

  Parser logicalAnd() =>
      ref0(equality) & (ref1(token, '&&') & ref0(equality)).star();

  Parser equality() =>
      ref0(relation) & (ref0(eqOp) & ref0(equality)).optional();

  Parser relation() => ref0(add) & (ref0(relOp) & ref0(add)).optional();

  Parser addOp() => ref1(token, '+') | ref1(token, '-');
  Parser mulOp() => ref1(token, '*') | ref1(token, '/') | ref1(token, '%');

  Parser add() => ref0(mul) & (ref0(addOp) & ref0(mul)).star();
  Parser mul() => ref0(unary) & (ref0(mulOp) & ref0(unary)).star();

  Parser prefixOp() => ref1(token, '!');

  Parser unary() => ref0(postfix) | ref0(prefixOp) & ref0(unary);

  Parser postfix() => ref0(prim) & ref0(selector).optional();

  Parser selector() => (ref0(subscript) | ref0(propertyAccess)).plus();

  Parser propertyAccess() => ref1(token, '.') & ref0(identifier).optional();

  Parser subscript() =>
      ref1(token, '[') & ref0(statement).optional() & ref1(token, ']');

  Parser prim() =>
      ref0(propertyAccess) |
      ref0(functions) |
      ref0(listBuilder) |
      ref0(mapBuilder) |
      ref0(parens) |
      ref0(constant);

  Parser constant() =>
      ref0(boolLiteral) |
      ref0(stringLiteral) |
      ref0(regexpLiteral) |
      ref0(numberLiteral);

  Parser functions() =>
      ref0(selectFunc) | ref0(containsFunc) | ref0(lengthFunc);

  Parser selectFunc() =>
      ref1(token, 'select') &
      char('(').trim() &
      ref0(statement) &
      char(')').trim();

  Parser lengthFunc() => ref1(token, 'length');

  Parser containsFunc() =>
      ref1(token, 'contains') &
      char('(').trim() &
      ref0(statement) &
      char(')').trim();

  Parser listBuilder() => ref1(token, '[') & ref0(statement) & ref1(token, ']');

  Parser mapBuilder() =>
      ref1(token, '{') & ref0(keyValueList) & ref1(token, '}');

  Parser keyValueList() =>
      ref0(keyValuePair) & (ref1(token, ",") & ref0(keyValuePair)).star();

  Parser keyValuePair() =>
      ref0(identifier) & ref1(token, ":") & ref0(statement);

  Parser parens() => ref1(token, '(') & ref0(statement) & ref1(token, ')');
}
