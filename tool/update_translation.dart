import 'dart:io';
import 'dart:convert';
import 'package:cw_core/utils/print_verbose.dart';

import 'utils/translation/arb_file_utils.dart';
import 'utils/translation/translation_constants.dart';
import 'utils/translation/translation_utils.dart';

void main(List<String> args) async {
  if (args.length < 2) {
    throw Exception(
        'Insufficient arguments!\n\nTry to run `./update_translation.dart "greetings" "New Hello World!"`');
  }

  final name = args.first;
  final newText = args[1];
  final force = args.last == "--force";

  printV('Updating "$name" to: "$newText"');

  for (var lang in langs) {
    final fileName = getArbFileName(lang);
    final file = File(fileName);
    final arbFile = await readArbFile(file);

    if (!arbFile.containsKey(name)) {
      printV('Key "$name" not found in $fileName - skipping');
      continue;
    }

    final newTranslation = await getTranslation(newText, lang);
    updateStringInArbFile(fileName, name, newTranslation, force: force);
  }

  printV('Alphabetizing all files...');

  for (var lang in langs) {
    final fileName = getArbFileName(lang);
    alphabetizeArbFile(fileName);
  }

  printV('Done!');
}

void updateStringInArbFile(String fileName, String key, String value, {bool force = false}) {
  final file = File(fileName);
  if (!file.existsSync()) {
    throw Exception('File $fileName does not exist!');
  }

  final content = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  if (!content.containsKey(key) && !force) {
    throw Exception('Key "$key" not found in $fileName and --force not specified');
  }

  content[key] = value;
  file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(content));
}
