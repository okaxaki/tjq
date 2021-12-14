# tjq
Tiny JSON Query for Dart 
(Just a Study, not for production)

# Use from CLI
```
$ cat test.json | pub run tjq:main <expr>
```

**expr** is a subset of `jq` query expression.

# Use as Library
```dart
void main(List<String> args) async {
  if (args.length == 0) {
    print('Usage: cat test.json | tjq <expr>');
    exit(0);
  }

  try {
    String input = readAsStringSyncFromStdin();
    final json = JsonDecoder().convert(input);
    final ast = TJQParser().parse(args[0]);
    final res = ast.eval(json);
    print(res);

  } catch (e) {
    print(e);
  }
}
```