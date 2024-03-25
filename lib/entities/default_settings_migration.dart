import 'dart:io' show Directory, File, Platform;
import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cake_wallet/entities/secret_store_key.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/node.dart';
import 'package:cake_wallet/entities/balance_display_mode.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/entities/node_list.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/entities/contact.dart';
import 'package:cake_wallet/entities/fs_migration.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:collection/collection.dart';

const newCakeWalletMoneroUri = 'xmr-node.cakewallet.com:18081';
const cakeWalletBitcoinElectrumUri = 'electrum.cakewallet.com:50002';
const publicBitcoinTestnetElectrumAddress = 'electrum.blockstream.info';
const publicBitcoinTestnetElectrumPort = '60002';
const publicBitcoinTestnetElectrumUri =
    '$publicBitcoinTestnetElectrumAddress:$publicBitcoinTestnetElectrumPort';
const cakeWalletLitecoinElectrumUri = 'ltc-electrum.cakewallet.com:50002';
const havenDefaultNodeUri = 'nodes.havenprotocol.org:443';
const ethereumDefaultNodeUri = 'ethereum.publicnode.com';
const polygonDefaultNodeUri = 'polygon-bor.publicnode.com';
const cakeWalletBitcoinCashDefaultNodeUri = 'bitcoincash.stackwallet.com:50002';
const nanoDefaultNodeUri = 'rpc.nano.to';
const nanoDefaultPowNodeUri = 'rpc.nano.to';
const solanaDefaultNodeUri = 'rpc.ankr.com';
const newCakeWalletBitcoinUri = 'btc-electrum.cakewallet.com:50002';

Future<void> defaultSettingsMigration(
    {required int version,
    required SharedPreferences sharedPreferences,
    required FlutterSecureStorage secureStorage,
    required Box<Node> nodes,
    required Box<Node> powNodes,
    required Box<WalletInfo> walletInfoSource,
    required Box<Trade> tradeSource,
    required Box<Contact> contactSource}) async {
  if (Platform.isIOS) {
    await ios_migrate_v1(walletInfoSource, tradeSource, contactSource);
  }

  // check current nodes for nullability regardless of the version
  await checkCurrentNodes(nodes, powNodes, sharedPreferences);

  final isNewInstall =
      sharedPreferences.getInt(PreferencesKey.currentDefaultSettingsMigrationVersion) == null;

  await _validateWalletInfoBoxData(walletInfoSource);

  await sharedPreferences.setBool(PreferencesKey.isNewInstall, isNewInstall);

  final currentVersion =
      sharedPreferences.getInt(PreferencesKey.currentDefaultSettingsMigrationVersion) ?? 0;

  if (currentVersion >= version) {
    return;
  }

  final migrationVersionsLength = version - currentVersion;
  final migrationVersions =
      List<int>.generate(migrationVersionsLength, (i) => currentVersion + (i + 1));

  /// When you add a new case, increase the initialMigrationVersion parameter in the main.dart file.
  /// This ensures that this switch case runs the newly added case.
  await Future.forEach(migrationVersions, (int version) async {
    try {
      switch (version) {
        case 1:
          await sharedPreferences.setString(
              PreferencesKey.currentFiatCurrencyKey, FiatCurrency.usd.toString());
          await sharedPreferences.setInt(PreferencesKey.currentTransactionPriorityKeyLegacy,
              monero!.getDefaultTransactionPriority().raw);
          await sharedPreferences.setInt(
              PreferencesKey.currentBalanceDisplayModeKey, BalanceDisplayMode.availableBalance.raw);
          await sharedPreferences.setBool('save_recipient_address', true);
          await resetToDefault(nodes);
          await changeMoneroCurrentNodeToDefault(
              sharedPreferences: sharedPreferences, nodes: nodes);
          await changeBitcoinCurrentElectrumServerToDefault(
              sharedPreferences: sharedPreferences, nodes: nodes);
          await changeLitecoinCurrentElectrumServerToDefault(
              sharedPreferences: sharedPreferences, nodes: nodes);
          await changeHavenCurrentNodeToDefault(sharedPreferences: sharedPreferences, nodes: nodes);
          await changeBitcoinCashCurrentNodeToDefault(
              sharedPreferences: sharedPreferences, nodes: nodes);

          break;
        case 2:
          await replaceNodesMigration(nodes: nodes);
          await replaceDefaultNode(sharedPreferences: sharedPreferences, nodes: nodes);

          break;
        case 3:
          await updateNodeTypes(nodes: nodes);
          await addBitcoinElectrumServerList(nodes: nodes);

          break;
        case 4:
          await changeBitcoinCurrentElectrumServerToDefault(
              sharedPreferences: sharedPreferences, nodes: nodes);
          break;

        case 5:
          await addAddressesForMoneroWallets(walletInfoSource);
          break;

        case 6:
          await updateDisplayModes(sharedPreferences);
          break;

        case 9:
          await generateBackupPassword(secureStorage);
          break;

        case 10:
          await changeTransactionPriorityAndFeeRateKeys(sharedPreferences);
          break;

        case 11:
          await changeDefaultMoneroNode(nodes, sharedPreferences);
          break;

        case 12:
          await checkCurrentNodes(nodes, powNodes, sharedPreferences);
          break;

        case 13:
          await resetBitcoinElectrumServer(nodes, sharedPreferences);
          break;

        case 15:
          await addLitecoinElectrumServerList(nodes: nodes);
          await changeLitecoinCurrentElectrumServerToDefault(
              sharedPreferences: sharedPreferences, nodes: nodes);
          await checkCurrentNodes(nodes, powNodes, sharedPreferences);
          break;

        case 16:
          await addHavenNodeList(nodes: nodes);
          await changeHavenCurrentNodeToDefault(sharedPreferences: sharedPreferences, nodes: nodes);
          await checkCurrentNodes(nodes, powNodes, sharedPreferences);
          break;

        case 17:
          await changeDefaultHavenNode(nodes);
          break;

        case 18:
          await addOnionNode(nodes);
          break;

        case 19:
          await validateBitcoinSavedTransactionPriority(sharedPreferences);
          break;
        case 20:
          await migrateExchangeStatus(sharedPreferences);
          break;
        case 21:
          await addEthereumNodeList(nodes: nodes);
          await changeEthereumCurrentNodeToDefault(
              sharedPreferences: sharedPreferences, nodes: nodes);
          break;
        case 22:
          await addNanoNodeList(nodes: nodes);
          await addNanoPowNodeList(nodes: powNodes);
          await changeNanoCurrentNodeToDefault(sharedPreferences: sharedPreferences, nodes: nodes);
          await changeNanoCurrentPowNodeToDefault(
              sharedPreferences: sharedPreferences, nodes: powNodes);
          break;
        case 23:
          await addBitcoinCashElectrumServerList(nodes: nodes);
          await changeBitcoinCurrentElectrumServerToDefault(
              sharedPreferences: sharedPreferences, nodes: nodes);
          break;
        case 24:
          await addPolygonNodeList(nodes: nodes);
          await changePolygonCurrentNodeToDefault(
              sharedPreferences: sharedPreferences, nodes: nodes);
          break;
        case 25:
          await rewriteSecureStoragePin(secureStorage: secureStorage);
          break;
        case 26:

        /// commented out as it was a probable cause for some users to have white screen issues
        /// maybe due to multiple access on Secure Storage at once
        /// or long await time on start of the app
        // await insecureStorageMigration(secureStorage: secureStorage, sharedPreferences: sharedPreferences);
        case 27:
          await addSolanaNodeList(nodes: nodes);
          await changeSolanaCurrentNodeToDefault(
              sharedPreferences: sharedPreferences, nodes: nodes);
          break;

        case 28:
          await _updateMoneroPriority(sharedPreferences);
          break;

        case 29:
          await changeDefaultBitcoinNode(nodes, sharedPreferences);
          break;

        case 30:
          await migrateTorPreferences(sharedPreferences: sharedPreferences);
          await addOnionNode(nodes);
          break;

        default:
          break;
      }

      await sharedPreferences.setInt(
          PreferencesKey.currentDefaultSettingsMigrationVersion, version);
    } catch (e) {
      print('Migration error: ${e.toString()}');
    }
  });

  await sharedPreferences.setInt(PreferencesKey.currentDefaultSettingsMigrationVersion, version);
}

Future<void> _updateMoneroPriority(SharedPreferences sharedPreferences) async {
  final currentPriority =
      await sharedPreferences.getInt(PreferencesKey.moneroTransactionPriority) ??
          monero!.getDefaultTransactionPriority().serialize();

  // was set to automatic but automatic should be 0
  if (currentPriority == 1) {
    sharedPreferences.setInt(PreferencesKey.moneroTransactionPriority,
        monero!.getDefaultTransactionPriority().serialize()); // 0
  }
}

Future<void> _validateWalletInfoBoxData(Box<WalletInfo> walletInfoSource) async {
  try {
    final root = await getApplicationDocumentsDirectory();

    for (var type in WalletType.values) {
      if (type == WalletType.none) {
        continue;
      }

      String prefix = walletTypeToString(type).toLowerCase();
      Directory walletsDir = Directory('${root.path}/wallets/$prefix/');

      if (!walletsDir.existsSync()) {
        continue;
      }

      List<String> walletNames = walletsDir.listSync().map((e) => e.path.split("/").last).toList();

      for (var name in walletNames) {
        final Directory dir;
        try {
          dir = Directory(await pathForWalletDir(name: name, type: type));
        } catch (_) {
          continue;
        }

        final walletFiles = dir.listSync();
        final hasCacheFile = walletFiles.any((element) => element.path.contains("$name/$name"));

        if (!hasCacheFile) {
          continue;
        }

        if (type == WalletType.monero || type == WalletType.haven) {
          final hasKeysFile = walletFiles.any((element) => element.path.contains(".keys"));

          if (!hasKeysFile) {
            continue;
          }
        }

        final id = prefix + '_' + name;
        final exist = walletInfoSource.values.any((el) => el.id == id);

        if (exist) {
          continue;
        }

        final walletInfo = WalletInfo.external(
          id: id,
          type: type,
          name: name,
          isRecovery: true,
          restoreHeight: 0,
          date: DateTime.now(),
          dirPath: dir.path,
          path: '${dir.path}/$name',
          address: '',
          showIntroCakePayCard: false,
        );

        walletInfoSource.add(walletInfo);
      }
    }
  } catch (_) {}
}

Future<void> validateBitcoinSavedTransactionPriority(SharedPreferences sharedPreferences) async {
  if (bitcoin == null) {
    return;
  }
  final int? savedBitcoinPriority =
      sharedPreferences.getInt(PreferencesKey.bitcoinTransactionPriority);
  if (!bitcoin!.getTransactionPriorities().any((element) => element.raw == savedBitcoinPriority)) {
    await sharedPreferences.setInt(PreferencesKey.bitcoinTransactionPriority,
        bitcoin!.getMediumTransactionPriority().serialize());
  }
}

Future<void> addOnionNode(Box<Node> nodes) async {
  final onionNodeUri = "cakexmrl7bonq7ovjka5kuwuyd3f7qnkz6z6s6dmsy3uckwra7bvggyd.onion:18081";
  final onionNodeUri2 = "sfprpc5klzs5vyitq2mrooicgk2wcs5ho2nm3niqduvzn5o6ylaslaqd.onion:18089";

  // check if the user has this node before (added it manually)
  if (nodes.values.firstWhereOrNull((element) => element.uriRaw == onionNodeUri) == null) {
    await nodes.add(Node(uri: onionNodeUri, type: WalletType.monero));
  }

  if (nodes.values.firstWhereOrNull((element) => element.uriRaw == onionNodeUri2) == null) {
    await nodes.add(Node(uri: onionNodeUri2, type: WalletType.monero));
  }
}

Future<void> replaceNodesMigration({required Box<Node> nodes}) async {
  final replaceNodes = <String, Node>{
    'eu-node.cakewallet.io:18081':
        Node(uri: 'xmr-node-eu.cakewallet.com:18081', type: WalletType.monero),
    'node.cakewallet.io:18081':
        Node(uri: 'xmr-node-usa-east.cakewallet.com:18081', type: WalletType.monero),
    'node.xmr.ru:13666': Node(uri: 'node.monero.net:18081', type: WalletType.monero)
  };

  nodes.values.forEach((Node node) async {
    final nodeToReplace = replaceNodes[node.uri];

    if (nodeToReplace != null) {
      node.uriRaw = nodeToReplace.uriRaw;
      node.login = nodeToReplace.login;
      node.password = nodeToReplace.password;
      await node.save();
    }
  });
}

Future<void> changeMoneroCurrentNodeToDefault(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  final node = getMoneroDefaultNode(nodes: nodes);
  final nodeId = node.key as int? ?? 0; // 0 - England

  await sharedPreferences.setInt(PreferencesKey.currentNodeIdKey, nodeId);
}

Node? getBitcoinDefaultElectrumServer({required Box<Node> nodes}) {
  return nodes.values
          .firstWhereOrNull((Node node) => node.uriRaw == cakeWalletBitcoinElectrumUri) ??
      nodes.values.firstWhereOrNull((node) => node.type == WalletType.bitcoin);
}

Node? getBitcoinTestnetDefaultElectrumServer({required Box<Node> nodes}) {
  return nodes.values
          .firstWhereOrNull((Node node) => node.uriRaw == publicBitcoinTestnetElectrumUri) ??
      nodes.values.firstWhereOrNull((node) => node.type == WalletType.bitcoin);
}

Node? getLitecoinDefaultElectrumServer({required Box<Node> nodes}) {
  return nodes.values
          .firstWhereOrNull((Node node) => node.uriRaw == cakeWalletLitecoinElectrumUri) ??
      nodes.values.firstWhereOrNull((node) => node.type == WalletType.litecoin);
}

Node? getHavenDefaultNode({required Box<Node> nodes}) {
  return nodes.values.firstWhereOrNull((Node node) => node.uriRaw == havenDefaultNodeUri) ??
      nodes.values.firstWhereOrNull((node) => node.type == WalletType.haven);
}

Node? getEthereumDefaultNode({required Box<Node> nodes}) {
  return nodes.values.firstWhereOrNull((Node node) => node.uriRaw == ethereumDefaultNodeUri) ??
      nodes.values.firstWhereOrNull((node) => node.type == WalletType.ethereum);
}

Node? getPolygonDefaultNode({required Box<Node> nodes}) {
  return nodes.values.firstWhereOrNull((Node node) => node.uriRaw == polygonDefaultNodeUri) ??
      nodes.values.firstWhereOrNull((node) => node.type == WalletType.polygon);
}

Node? getNanoDefaultNode({required Box<Node> nodes}) {
  return nodes.values.firstWhereOrNull((Node node) => node.uriRaw == nanoDefaultNodeUri) ??
      nodes.values.firstWhereOrNull((node) => node.type == WalletType.nano);
}

Node? getNanoDefaultPowNode({required Box<Node> nodes}) {
  return nodes.values.firstWhereOrNull((Node node) => node.uriRaw == nanoDefaultPowNodeUri) ??
      nodes.values.firstWhereOrNull((node) => (node.type == WalletType.nano));
}

Node? getBitcoinCashDefaultElectrumServer({required Box<Node> nodes}) {
  return nodes.values
          .firstWhereOrNull((Node node) => node.uriRaw == cakeWalletBitcoinCashDefaultNodeUri) ??
      nodes.values.firstWhereOrNull((node) => node.type == WalletType.bitcoinCash);
}

Node getMoneroDefaultNode({required Box<Node> nodes}) {
  final timeZone = DateTime.now().timeZoneOffset.inHours;
  var nodeUri = '';

  if (timeZone >= 1) {
    // Eurasia
    nodeUri = 'xmr-node-eu.cakewallet.com:18081';
  } else if (timeZone <= -4) {
    // America
    nodeUri = 'xmr-node-usa-east.cakewallet.com:18081';
  }

  try {
    return nodes.values.firstWhere((Node node) => node.uriRaw == nodeUri);
  } catch (_) {
    return nodes.values.first;
  }
}

Future<void> migrateTorPreferences({required SharedPreferences sharedPreferences}) async {
  if (sharedPreferences.getInt(PreferencesKey.currentFiatApiModeKey) == 1) {
    await sharedPreferences.setInt(PreferencesKey.currentFiatApiModeKey, 0);
  }

  if (sharedPreferences.getInt(PreferencesKey.exchangeStatusKey) == 1) {
    await sharedPreferences.setInt(PreferencesKey.exchangeStatusKey, 0);
  }
}

Node? getSolanaDefaultNode({required Box<Node> nodes}) {
  return nodes.values.firstWhereOrNull((Node node) => node.uriRaw == solanaDefaultNodeUri) ??
      nodes.values.firstWhereOrNull((node) => node.type == WalletType.solana);
}

Future<void> insecureStorageMigration({
  required SharedPreferences sharedPreferences,
  required FlutterSecureStorage secureStorage,
}) async {
  bool? allowBiometricalAuthentication =
      sharedPreferences.getBool(SecureKey.allowBiometricalAuthenticationKey);
  bool? useTOTP2FA = sharedPreferences.getBool(SecureKey.useTOTP2FA);
  bool? shouldRequireTOTP2FAForAccessingWallet =
      sharedPreferences.getBool(SecureKey.shouldRequireTOTP2FAForAccessingWallet);
  bool? shouldRequireTOTP2FAForSendsToContact =
      sharedPreferences.getBool(SecureKey.shouldRequireTOTP2FAForSendsToContact);
  bool? shouldRequireTOTP2FAForSendsToNonContact =
      sharedPreferences.getBool(SecureKey.shouldRequireTOTP2FAForSendsToNonContact);
  bool? shouldRequireTOTP2FAForSendsToInternalWallets =
      sharedPreferences.getBool(SecureKey.shouldRequireTOTP2FAForSendsToInternalWallets);
  bool? shouldRequireTOTP2FAForExchangesToInternalWallets =
      sharedPreferences.getBool(SecureKey.shouldRequireTOTP2FAForExchangesToInternalWallets);
  bool? shouldRequireTOTP2FAForExchangesToExternalWallets =
      sharedPreferences.getBool(SecureKey.shouldRequireTOTP2FAForExchangesToExternalWallets);
  bool? shouldRequireTOTP2FAForAddingContacts =
      sharedPreferences.getBool(SecureKey.shouldRequireTOTP2FAForAddingContacts);
  bool? shouldRequireTOTP2FAForCreatingNewWallets =
      sharedPreferences.getBool(SecureKey.shouldRequireTOTP2FAForCreatingNewWallets);
  bool? shouldRequireTOTP2FAForAllSecurityAndBackupSettings =
      sharedPreferences.getBool(SecureKey.shouldRequireTOTP2FAForAllSecurityAndBackupSettings);
  int? selectedCake2FAPreset = sharedPreferences.getInt(SecureKey.selectedCake2FAPreset);
  String? totpSecretKey = sharedPreferences.getString(SecureKey.totpSecretKey);
  int? pinTimeOutDuration = sharedPreferences.getInt(SecureKey.pinTimeOutDuration);
  int? lastAuthTimeMilliseconds = sharedPreferences.getInt(SecureKey.lastAuthTimeMilliseconds);

  try {
    await secureStorage.write(
        key: SecureKey.allowBiometricalAuthenticationKey,
        value: allowBiometricalAuthentication.toString());
    await secureStorage.write(key: SecureKey.useTOTP2FA, value: useTOTP2FA.toString());
    await secureStorage.write(
        key: SecureKey.shouldRequireTOTP2FAForAccessingWallet,
        value: shouldRequireTOTP2FAForAccessingWallet.toString());
    await secureStorage.write(
        key: SecureKey.shouldRequireTOTP2FAForSendsToContact,
        value: shouldRequireTOTP2FAForSendsToContact.toString());
    await secureStorage.write(
        key: SecureKey.shouldRequireTOTP2FAForSendsToNonContact,
        value: shouldRequireTOTP2FAForSendsToNonContact.toString());
    await secureStorage.write(
        key: SecureKey.shouldRequireTOTP2FAForSendsToInternalWallets,
        value: shouldRequireTOTP2FAForSendsToInternalWallets.toString());
    await secureStorage.write(
        key: SecureKey.shouldRequireTOTP2FAForExchangesToInternalWallets,
        value: shouldRequireTOTP2FAForExchangesToInternalWallets.toString());
    await secureStorage.write(
        key: SecureKey.shouldRequireTOTP2FAForExchangesToExternalWallets,
        value: shouldRequireTOTP2FAForExchangesToExternalWallets.toString());
    await secureStorage.write(
        key: SecureKey.shouldRequireTOTP2FAForAddingContacts,
        value: shouldRequireTOTP2FAForAddingContacts.toString());
    await secureStorage.write(
        key: SecureKey.shouldRequireTOTP2FAForCreatingNewWallets,
        value: shouldRequireTOTP2FAForCreatingNewWallets.toString());
    await secureStorage.write(
        key: SecureKey.shouldRequireTOTP2FAForAllSecurityAndBackupSettings,
        value: shouldRequireTOTP2FAForAllSecurityAndBackupSettings.toString());
    await secureStorage.write(
        key: SecureKey.selectedCake2FAPreset, value: selectedCake2FAPreset.toString());
    await secureStorage.write(key: SecureKey.totpSecretKey, value: totpSecretKey.toString());
    await secureStorage.write(
        key: SecureKey.pinTimeOutDuration, value: pinTimeOutDuration.toString());
    await secureStorage.write(
        key: SecureKey.lastAuthTimeMilliseconds, value: lastAuthTimeMilliseconds.toString());
  } catch (e) {
    print("Error migrating shared preferences to secure storage!: $e");
    // this actually shouldn't be that big of a problem since we don't delete the old keys in this update
    // and we read and write to the new locations when loading storage, the migration is just for extra safety
  }
}

Future<void> rewriteSecureStoragePin({required FlutterSecureStorage secureStorage}) async {
  // the bug only affects ios/mac:
  if (!Platform.isIOS && !Platform.isMacOS) {
    return;
  }

  // first, get the encoded pin:
  final keyForPinCode = generateStoreKeyFor(key: SecretStoreKey.pinCodePassword);
  String? encodedPin;
  try {
    encodedPin = await secureStorage.read(key: keyForPinCode);
  } catch (e) {
    // either we don't have a pin, or we can't read it (maybe even because of the bug!)
    // the only option here is to abort the migration or we risk losing the pin and locking the user out
    return;
  }

  if (encodedPin == null) {
    return;
  }

  // ensure we overwrite by deleting the old key first:
  await secureStorage.delete(key: keyForPinCode);
  await secureStorage.write(
    key: keyForPinCode,
    value: encodedPin,
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );
}

Future<void> changeBitcoinCurrentElectrumServerToDefault(
    {required SharedPreferences sharedPreferences,
    required Box<Node> nodes,
    bool? isTestnet}) async {
  Node? server;
  if (isTestnet == true) {
    server = getBitcoinTestnetDefaultElectrumServer(nodes: nodes);
  } else {
    server = getBitcoinDefaultElectrumServer(nodes: nodes);
  }
  final serverId = server?.key as int? ?? 0;

  await sharedPreferences.setInt(PreferencesKey.currentBitcoinElectrumSererIdKey, serverId);
}

Future<void> changeLitecoinCurrentElectrumServerToDefault(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  final server = getLitecoinDefaultElectrumServer(nodes: nodes);
  final serverId = server?.key as int? ?? 0;

  await sharedPreferences.setInt(PreferencesKey.currentLitecoinElectrumSererIdKey, serverId);
}

Future<void> changeBitcoinCashCurrentNodeToDefault(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  final server = getBitcoinCashDefaultElectrumServer(nodes: nodes);
  final serverId = server?.key as int? ?? 0;

  await sharedPreferences.setInt(PreferencesKey.currentBitcoinCashNodeIdKey, serverId);
}

Future<void> changeHavenCurrentNodeToDefault(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  final node = getHavenDefaultNode(nodes: nodes);
  final nodeId = node?.key as int? ?? 0;

  await sharedPreferences.setInt(PreferencesKey.currentHavenNodeIdKey, nodeId);
}

Future<void> replaceDefaultNode(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  const nodesForReplace = <String>[
    'xmr-node-uk.cakewallet.com:18081',
    'eu-node.cakewallet.io:18081',
    'node.cakewallet.io:18081'
  ];
  final currentNodeId = sharedPreferences.getInt(PreferencesKey.currentNodeIdKey);
  final currentNode = nodes.values.firstWhereOrNull((Node node) => node.key == currentNodeId);
  final needToReplace = currentNode == null ? true : nodesForReplace.contains(currentNode.uriRaw);

  if (!needToReplace) {
    return;
  }

  await changeMoneroCurrentNodeToDefault(sharedPreferences: sharedPreferences, nodes: nodes);
}

Future<void> updateNodeTypes({required Box<Node> nodes}) async {
  nodes.values.forEach((node) async {
    if (node.type == null) {
      node.type = WalletType.monero;
      await node.save();
    }
  });
}

Future<void> addBitcoinElectrumServerList({required Box<Node> nodes}) async {
  final serverList = await loadBitcoinElectrumServerList();
  for (var node in serverList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }
  }
}

Future<void> addLitecoinElectrumServerList({required Box<Node> nodes}) async {
  final serverList = await loadLitecoinElectrumServerList();
  for (var node in serverList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }
  }
}

Future<void> addBitcoinCashElectrumServerList({required Box<Node> nodes}) async {
  final serverList = await loadBitcoinCashElectrumServerList();
  for (var node in serverList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }
  }
}

Future<void> addHavenNodeList({required Box<Node> nodes}) async {
  final nodeList = await loadDefaultHavenNodes();
  for (var node in nodeList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }
  }
}

Future<void> addAddressesForMoneroWallets(Box<WalletInfo> walletInfoSource) async {
  final moneroWalletsInfo = walletInfoSource.values.where((info) => info.type == WalletType.monero);
  moneroWalletsInfo.forEach((info) async {
    try {
      final walletPath = await pathForWallet(name: info.name, type: WalletType.monero);
      final addressFilePath = '$walletPath.address.txt';
      final addressFile = File(addressFilePath);

      if (!addressFile.existsSync()) {
        return;
      }

      final addressText = await addressFile.readAsString();
      info.address = addressText;
      await info.save();
    } catch (e) {
      print(e.toString());
    }
  });
}

Future<void> updateDisplayModes(SharedPreferences sharedPreferences) async {
  final currentBalanceDisplayMode =
      sharedPreferences.getInt(PreferencesKey.currentBalanceDisplayModeKey) ?? -1;
  final balanceDisplayMode = currentBalanceDisplayMode < 2 ? 3 : 2;
  await sharedPreferences.setInt(PreferencesKey.currentBalanceDisplayModeKey, balanceDisplayMode);
}

Future<void> generateBackupPassword(FlutterSecureStorage secureStorage) async {
  final key = generateStoreKeyFor(key: SecretStoreKey.backupPassword);

  if ((await secureStorage.read(key: key))?.isNotEmpty ?? false) {
    return;
  }

  final password = encrypt.Key.fromSecureRandom(32).base16;
  await secureStorage.delete(key: key);
  await secureStorage.write(key: key, value: password);
}

Future<void> changeTransactionPriorityAndFeeRateKeys(SharedPreferences sharedPreferences) async {
  final legacyTransactionPriority =
      sharedPreferences.getInt(PreferencesKey.currentTransactionPriorityKeyLegacy)!;
  await sharedPreferences.setInt(
      PreferencesKey.moneroTransactionPriority, legacyTransactionPriority);
  await sharedPreferences.setInt(PreferencesKey.bitcoinTransactionPriority,
      bitcoin!.getMediumTransactionPriority().serialize());
}

Future<void> changeDefaultMoneroNode(
    Box<Node> nodeSource, SharedPreferences sharedPreferences) async {
  const cakeWalletMoneroNodeUriPattern = '.cakewallet.com';
  final currentMoneroNodeId = sharedPreferences.getInt(PreferencesKey.currentNodeIdKey);
  final currentMoneroNode = nodeSource.values.firstWhere((node) => node.key == currentMoneroNodeId);
  final needToReplaceCurrentMoneroNode =
      currentMoneroNode.uri.toString().contains(cakeWalletMoneroNodeUriPattern);

  nodeSource.values.forEach((node) async {
    if (node.type == WalletType.monero &&
        node.uri.toString().contains(cakeWalletMoneroNodeUriPattern)) {
      await node.delete();
    }
  });

  final newCakeWalletNode = Node(uri: newCakeWalletMoneroUri, type: WalletType.monero);

  await nodeSource.add(newCakeWalletNode);

  if (needToReplaceCurrentMoneroNode) {
    await sharedPreferences.setInt(PreferencesKey.currentNodeIdKey, newCakeWalletNode.key as int);
  }
}

Future<void> changeDefaultBitcoinNode(
    Box<Node> nodeSource, SharedPreferences sharedPreferences) async {
  const cakeWalletBitcoinNodeUriPattern = '.cakewallet.com';
  final currentBitcoinNodeId =
      sharedPreferences.getInt(PreferencesKey.currentBitcoinElectrumSererIdKey);
  final currentBitcoinNode =
      nodeSource.values.firstWhere((node) => node.key == currentBitcoinNodeId);
  final needToReplaceCurrentBitcoinNode =
      currentBitcoinNode.uri.toString().contains(cakeWalletBitcoinNodeUriPattern);

  final newCakeWalletBitcoinNode = Node(uri: newCakeWalletBitcoinUri, type: WalletType.bitcoin);

  await nodeSource.add(newCakeWalletBitcoinNode);

  if (needToReplaceCurrentBitcoinNode) {
    await sharedPreferences.setInt(
        PreferencesKey.currentBitcoinElectrumSererIdKey, newCakeWalletBitcoinNode.key as int);
  }
}

Future<void> checkCurrentNodes(
    Box<Node> nodeSource, Box<Node> powNodeSource, SharedPreferences sharedPreferences) async {
  final currentMoneroNodeId = sharedPreferences.getInt(PreferencesKey.currentNodeIdKey);
  final currentBitcoinElectrumSeverId =
      sharedPreferences.getInt(PreferencesKey.currentBitcoinElectrumSererIdKey);
  final currentLitecoinElectrumSeverId =
      sharedPreferences.getInt(PreferencesKey.currentLitecoinElectrumSererIdKey);
  final currentHavenNodeId = sharedPreferences.getInt(PreferencesKey.currentHavenNodeIdKey);
  final currentEthereumNodeId = sharedPreferences.getInt(PreferencesKey.currentEthereumNodeIdKey);
  final currentPolygonNodeId = sharedPreferences.getInt(PreferencesKey.currentPolygonNodeIdKey);
  final currentNanoNodeId = sharedPreferences.getInt(PreferencesKey.currentNanoNodeIdKey);
  final currentNanoPowNodeId = sharedPreferences.getInt(PreferencesKey.currentNanoPowNodeIdKey);
  final currentBitcoinCashNodeId =
      sharedPreferences.getInt(PreferencesKey.currentBitcoinCashNodeIdKey);
  final currentSolanaNodeId = sharedPreferences.getInt(PreferencesKey.currentSolanaNodeIdKey);
  final currentMoneroNode =
      nodeSource.values.firstWhereOrNull((node) => node.key == currentMoneroNodeId);
  final currentBitcoinElectrumServer =
      nodeSource.values.firstWhereOrNull((node) => node.key == currentBitcoinElectrumSeverId);
  final currentLitecoinElectrumServer =
      nodeSource.values.firstWhereOrNull((node) => node.key == currentLitecoinElectrumSeverId);
  final currentHavenNodeServer =
      nodeSource.values.firstWhereOrNull((node) => node.key == currentHavenNodeId);
  final currentEthereumNodeServer =
      nodeSource.values.firstWhereOrNull((node) => node.key == currentEthereumNodeId);
  final currentPolygonNodeServer =
      nodeSource.values.firstWhereOrNull((node) => node.key == currentPolygonNodeId);
  final currentNanoNodeServer =
      nodeSource.values.firstWhereOrNull((node) => node.key == currentNanoNodeId);
  final currentNanoPowNodeServer =
      powNodeSource.values.firstWhereOrNull((node) => node.key == currentNanoPowNodeId);
  final currentBitcoinCashNodeServer =
      nodeSource.values.firstWhereOrNull((node) => node.key == currentBitcoinCashNodeId);
  final currentSolanaNodeServer =
      nodeSource.values.firstWhereOrNull((node) => node.key == currentSolanaNodeId);
  if (currentMoneroNode == null) {
    final newCakeWalletNode = Node(uri: newCakeWalletMoneroUri, type: WalletType.monero);
    await nodeSource.add(newCakeWalletNode);
    await sharedPreferences.setInt(PreferencesKey.currentNodeIdKey, newCakeWalletNode.key as int);
  }

  if (currentBitcoinElectrumServer == null) {
    final cakeWalletElectrum = Node(uri: cakeWalletBitcoinElectrumUri, type: WalletType.bitcoin);
    await nodeSource.add(cakeWalletElectrum);
    await sharedPreferences.setInt(
        PreferencesKey.currentBitcoinElectrumSererIdKey, cakeWalletElectrum.key as int);
  }

  if (currentLitecoinElectrumServer == null) {
    final cakeWalletElectrum = Node(uri: cakeWalletLitecoinElectrumUri, type: WalletType.litecoin);
    await nodeSource.add(cakeWalletElectrum);
    await sharedPreferences.setInt(
        PreferencesKey.currentLitecoinElectrumSererIdKey, cakeWalletElectrum.key as int);
  }

  if (currentHavenNodeServer == null) {
    final node = Node(uri: havenDefaultNodeUri, type: WalletType.haven);
    await nodeSource.add(node);
    await sharedPreferences.setInt(PreferencesKey.currentHavenNodeIdKey, node.key as int);
  }

  if (currentEthereumNodeServer == null) {
    final node = Node(uri: ethereumDefaultNodeUri, type: WalletType.ethereum);
    await nodeSource.add(node);
    await sharedPreferences.setInt(PreferencesKey.currentEthereumNodeIdKey, node.key as int);
  }

  if (currentNanoNodeServer == null) {
    final node = Node(uri: nanoDefaultNodeUri, useSSL: true, type: WalletType.nano);
    await nodeSource.add(node);
    await sharedPreferences.setInt(PreferencesKey.currentNanoNodeIdKey, node.key as int);
  }

  if (currentNanoPowNodeServer == null) {
    Node? node = powNodeSource.values
        .firstWhereOrNull((node) => node.uri.toString() == nanoDefaultPowNodeUri);
    if (node == null) {
      node = Node(uri: nanoDefaultPowNodeUri, useSSL: true, type: WalletType.nano);
      await powNodeSource.add(node);
    }
    await sharedPreferences.setInt(PreferencesKey.currentNanoPowNodeIdKey, node.key as int);
  }

  if (currentBitcoinCashNodeServer == null) {
    final node = Node(uri: cakeWalletBitcoinCashDefaultNodeUri, type: WalletType.bitcoinCash);
    await nodeSource.add(node);
    await sharedPreferences.setInt(PreferencesKey.currentBitcoinCashNodeIdKey, node.key as int);
  }

  if (currentPolygonNodeServer == null) {
    final node = Node(uri: polygonDefaultNodeUri, type: WalletType.polygon);
    await nodeSource.add(node);
    await sharedPreferences.setInt(PreferencesKey.currentPolygonNodeIdKey, node.key as int);
  }

  if (currentSolanaNodeServer == null) {
    final node = Node(uri: solanaDefaultNodeUri, type: WalletType.solana);
    await nodeSource.add(node);
    await sharedPreferences.setInt(PreferencesKey.currentSolanaNodeIdKey, node.key as int);
  }
}

Future<void> resetBitcoinElectrumServer(
    Box<Node> nodeSource, SharedPreferences sharedPreferences) async {
  final currentElectrumSeverId =
      sharedPreferences.getInt(PreferencesKey.currentBitcoinElectrumSererIdKey);
  final oldElectrumServer = nodeSource.values
      .firstWhereOrNull((node) => node.uri.toString().contains('electrumx.cakewallet.com'));
  var cakeWalletNode = nodeSource.values
      .firstWhereOrNull((node) => node.uriRaw.toString() == cakeWalletBitcoinElectrumUri);

  if (cakeWalletNode == null) {
    cakeWalletNode = Node(uri: cakeWalletBitcoinElectrumUri, type: WalletType.bitcoin);
    await nodeSource.add(cakeWalletNode);
  }

  if (currentElectrumSeverId == oldElectrumServer?.key) {
    await sharedPreferences.setInt(
        PreferencesKey.currentBitcoinElectrumSererIdKey, cakeWalletNode.key as int);
  }

  await oldElectrumServer?.delete();
}

Future<void> changeDefaultHavenNode(Box<Node> nodeSource) async {
  const previousHavenDefaultNodeUri = 'vault.havenprotocol.org:443';
  final havenNodes = nodeSource.values.where((node) => node.uriRaw == previousHavenDefaultNodeUri);
  havenNodes.forEach((node) async {
    node.uriRaw = havenDefaultNodeUri;
    await node.save();
  });
}

Future<void> migrateExchangeStatus(SharedPreferences sharedPreferences) async {
  final isExchangeDisabled = sharedPreferences.getBool(PreferencesKey.disableExchangeKey);
  if (isExchangeDisabled == null) {
    return;
  }

  await sharedPreferences.setInt(PreferencesKey.exchangeStatusKey,
      isExchangeDisabled ? ExchangeApiMode.disabled.raw : ExchangeApiMode.enabled.raw);

  await sharedPreferences.remove(PreferencesKey.disableExchangeKey);
}

Future<void> addEthereumNodeList({required Box<Node> nodes}) async {
  final nodeList = await loadDefaultEthereumNodes();
  for (var node in nodeList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }
  }
}

Future<void> changeEthereumCurrentNodeToDefault(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  final node = getEthereumDefaultNode(nodes: nodes);
  final nodeId = node?.key as int? ?? 0;

  await sharedPreferences.setInt(PreferencesKey.currentEthereumNodeIdKey, nodeId);
}

Future<void> addNanoNodeList({required Box<Node> nodes}) async {
  final nodeList = await loadDefaultNanoNodes();
  for (var node in nodeList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }
  }
}

Future<void> addNanoPowNodeList({required Box<Node> nodes}) async {
  final nodeList = await loadDefaultNanoPowNodes();
  for (var node in nodeList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }
  }
}

Future<void> changeNanoCurrentNodeToDefault(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  final node = getNanoDefaultNode(nodes: nodes);
  final nodeId = node?.key as int? ?? 0;

  await sharedPreferences.setInt(PreferencesKey.currentNanoNodeIdKey, nodeId);
}

Future<void> changeNanoCurrentPowNodeToDefault(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  final node = getNanoDefaultPowNode(nodes: nodes);
  final nodeId = node?.key as int? ?? 0;
  await sharedPreferences.setInt(PreferencesKey.currentNanoPowNodeIdKey, nodeId);
}

Future<void> addPolygonNodeList({required Box<Node> nodes}) async {
  final nodeList = await loadDefaultPolygonNodes();
  for (var node in nodeList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }
  }
}

Future<void> changePolygonCurrentNodeToDefault(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  final node = getPolygonDefaultNode(nodes: nodes);
  final nodeId = node?.key as int? ?? 0;

  await sharedPreferences.setInt(PreferencesKey.currentPolygonNodeIdKey, nodeId);
}

Future<void> addSolanaNodeList({required Box<Node> nodes}) async {
  final nodeList = await loadDefaultSolanaNodes();
  for (var node in nodeList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }
  }
}

Future<void> changeSolanaCurrentNodeToDefault(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  final node = getSolanaDefaultNode(nodes: nodes);
  final nodeId = node?.key as int? ?? 0;

  await sharedPreferences.setInt(PreferencesKey.currentSolanaNodeIdKey, nodeId);
}
