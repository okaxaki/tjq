import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:tjq/tjq.dart';

prettyPrint(dynamic obj) {
  if (obj is UnbraketedList) {
    obj.data.forEach(prettyPrint);
  } else {
    print(JsonEncoder.withIndent('  ').convert(obj));
  }
}

Future<dynamic> readJsonFromStdin() async {
  var res;
  final completer = Completer();
  stdin.transform(utf8.decoder).transform(JsonDecoder()).listen(
    (obj) {
      res = obj;
    },
    onDone: () {
      completer.complete();
    },
  );
  await completer.future;
  return res;
}

void main(List<String> args) async {
  if (args.length == 0) {
    print('Usage: cat test.json | tjq <expr>');
    exit(0);
  }

  try {
    DateTime start = DateTime.now();
    final json = await readJsonFromStdin();
    print("json:decode ${DateTime.now().difference(start).inMilliseconds}ms");
    start = DateTime.now();
    final ast = TJQParser().parse(args[0]);
    print("ast:parse ${DateTime.now().difference(start).inMilliseconds}ms");
    // prettyPrint(ast);
    start = DateTime.now();
    final res = ast.eval(json);
    print("ast:eval ${DateTime.now().difference(start).inMilliseconds}ms");
    prettyPrint(res);

  } catch (e) {
    print(e);
    rethrow;
  }
}
