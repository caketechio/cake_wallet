import 'dart:convert';
import 'dart:io';
import 'utils/secret_key.dart';
import 'utils/utils.dart';

const baseConfigPath = 'tool/.secrets-config.json';
const evmChainsConfigPath = 'tool/.evm-secrets-config.json';
const bitcoinConfigPath = 'tool/.bitcoin-secrets-config.json';
const solanaConfigPath = 'tool/.solana-secrets-config.json';
const nanoConfigPath = 'tool/.nano-secrets-config.json';
const tronConfigPath = 'tool/.tron-secrets-config.json';

Future<void> main(List<String> args) async => generateSecretsConfig(args);

Future<void> writeConfig(
  File configFile,
  List<SecretKey> newSecrets, {
  Map<String, dynamic>? existingSecrets,
}) async {
  final secrets = existingSecrets ?? <String, dynamic>{};
  newSecrets.forEach((sec) {
    if (secrets[sec.name] != null) {
      return;
    }
    secrets[sec.name] = sec.generate();
  });
  String secretsJson = JsonEncoder.withIndent(' ').convert(secrets);
  await configFile.writeAsString(secretsJson);
  secrets.clear();
}

Future<void> generateSecretsConfig(List<String> args) async {
  final extraInfo = args.fold(<String, dynamic>{}, (Map<String, dynamic> acc, String arg) {
    final parts = arg.split('=');
    final key = normalizeKeyName(parts[0]);
    acc[key] = acc[key] = parts.length > 1 ? parts[1] : 1;
    return acc;
  });

  final baseConfigFile = File(baseConfigPath);
  final evmChainsConfigFile = File(evmChainsConfigPath);
  final bitcoinConfigFile = File(bitcoinConfigPath);
  final solanaConfigFile = File(solanaConfigPath);
  final nanoConfigFile = File(nanoConfigPath);
  final tronConfigFile = File(tronConfigPath);

  final secrets = <String, dynamic>{};

  secrets.addAll(extraInfo);
  secrets.removeWhere((key, dynamic value) {
    if (key.contains('--')) {
      return true;
    }
    return false;
  });

  if (baseConfigFile.existsSync()) {
    if (extraInfo['--force'] == 1) {
      await baseConfigFile.delete();
    } else {
      return;
    }
  }
  
  await writeConfig(baseConfigFile, SecretKey.base, existingSecrets: secrets);
  
  await writeConfig(evmChainsConfigFile, SecretKey.evmChainsSecrets);
  await writeConfig(solanaConfigFile, SecretKey.solanaSecrets);
  await writeConfig(nanoConfigFile, SecretKey.nanoSecrets);
  await writeConfig(tronConfigFile, SecretKey.tronSecrets);
  await writeConfig(bitcoinConfigFile, SecretKey.bitcoinSecrets);
}
