import 'utils/translation/arb_file_utils.dart';
import 'utils/translation/translation_constants.dart';
import 'utils/translation/translation_utils.dart';

/// flutter packages pub run tool/append_translation.dart "hello_world" "Hello World!"

void main(List<String> args) async {
  if (args.length < 2 || args.length > 3) {
    throw Exception(
        'Insufficient arguments!\n\nTry to run `./append_translation.dart greetings "Hello World!" [--force]`');
  }

  final name = args[0];
  final text = args[1];
  final force = args.length == 3 && args[2] == '--force';

  print('Appending "$name": "$text"');

  // add translation to all languages:
  for (var lang in langs) {
    final fileName = getArbFileName(lang);
    final translation = await getTranslation(text, lang);

    appendStringToArbFile(fileName, name, translation, force: force);
  }

  print('Alphabetizing all files...');
  
  for (var lang in langs) {
    final fileName = getArbFileName(lang);
    alphabetizeArbFile(fileName);
  }

  print('Done!');
}