import 'dart:convert';
import 'dart:io';

void appendStringToArbFile(String fileName, String name, String text, {bool force = false}) {
  final file = File(fileName);
  final arbObj = readArbFile(file);

  if (arbObj.containsKey(name) && !force) {
    print("String $name already exists in $fileName! Use --force to overwrite!");
    return;
  }

  arbObj.addAll({name: text});

  final outputContent = json
      .encode(arbObj)
      .replaceAll('","', '",\n  "')
      .replaceAll('{"', '{\n  "')
      .replaceAll('"}', '"\n}')
      .replaceAll('":"', '": "')
      .replaceAll('\$ {', '\${');

  file.writeAsStringSync(outputContent);
}

void appendStringsToArbFile(String fileName, Map<String, String> strings) {
  final file = File(fileName);
  final arbObj = readArbFile(file);

  arbObj.addAll(strings);

  final outputContent = json
      .encode(arbObj)
      .replaceAll('","', '",\n  "')
      .replaceAll('{"', '{\n  "')
      .replaceAll('"}', '"\n}')
      .replaceAll('":"', '": "')
      .replaceAll('\$ {', '\${');

  file.writeAsStringSync(outputContent);
}

Map<String, dynamic> readArbFile(File file) {
  final inputContent = file.readAsStringSync();

  return json.decode(inputContent) as Map<String, dynamic>;
}

String getArbFileName(String lang) {
  final shortLang = lang.split("-").first;
  return "./res/values/strings_$shortLang.arb";
}

List<String> getMissingKeysInArbFile(String fileName, Iterable<String> langKeys) {
  final file = File(fileName);
  final arbObj = readArbFile(file);
  final results = <String>[];

  for (var langKey in langKeys) {
    if (!arbObj.containsKey(langKey)) {
      results.add(langKey);
    }
  }

  return results;
}

void alphabetizeArbFile(String fileName) {
  final file = File(fileName);
  final arbObj = readArbFile(file);

  final sortedKeys = arbObj.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final Map<String, dynamic> sortedArbObj = {};
  for (var key in sortedKeys) {
    sortedArbObj[key] = arbObj[key];
  }

  final outputContent = json
      .encode(sortedArbObj)
      .replaceAll('","', '",\n  "')
      .replaceAll('{"', '{\n  "')
      .replaceAll('"}', '"\n}')
      .replaceAll('":"', '": "')
      .replaceAll('\$ {', '\${');

  file.writeAsStringSync(outputContent);
}
