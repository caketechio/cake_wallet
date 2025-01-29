import 'dart:convert';
import 'dart:io' show Directory, File, Platform;
import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/core/secure_storage.dart';
import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/haven_seed_store.dart';
import 'package:cake_wallet/haven/haven.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cake_wallet/entities/secret_store_key.dart';
import 'package:cw_core/root_dir.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:hive/hive.dart';
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
const cakeWalletSilentPaymentsElectrsUri = 'electrs.cakewallet.com:50001';
const publicBitcoinTestnetElectrumAddress = 'electrs.cakewallet.com';
const publicBitcoinTestnetElectrumPort = '50002';
const publicBitcoinTestnetElectrumUri =
    '$publicBitcoinTestnetElectrumAddress:$publicBitcoinTestnetElectrumPort';
const cakeWalletLitecoinElectrumUri = 'ltc-electrum.cakewallet.com:50002';
const havenDefaultNodeUri = 'nodes.havenprotocol.org:443';
const ethereumDefaultNodeUri = 'ethereum-rpc.publicnode.com';
const polygonDefaultNodeUri = 'polygon-bor-rpc.publicnode.com';
const cakeWalletBitcoinCashDefaultNodeUri = 'bitcoincash.stackwallet.com:50002';
const nanoDefaultNodeUri = 'nano.nownodes.io';
const nanoDefaultPowNodeUri = 'rpc.nano.to';
const solanaDefaultNodeUri = 'solana-mainnet.core.chainstack.com';
const tronDefaultNodeUri = 'api.trongrid.io';
const newCakeWalletBitcoinUri = 'btc-electrum.cakewallet.com:50002';
const wowneroDefaultNodeUri = 'node3.monerodevs.org:34568';
const zanoDefaultNodeUri = 'zano.cakewallet.com:11211';
const moneroWorldNodeUri = '.moneroworld.com';

Future<void> defaultSettingsMigration(
    {required int version,
    required SharedPreferences sharedPreferences,
    required SecureStorage secureStorage,
    required Box<Node> nodes,
    required Box<Node> powNodes,
    required Box<WalletInfo> walletInfoSource,
    required Box<Trade> tradeSource,
    required Box<Contact> contactSource,
    required Box<HavenSeedStore> havenSeedStore}) async {
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
          await updateWalletTypeNodesWithNewNode(
            nodes: nodes,
            newNodeUri: "cakexmrl7bonq7ovjka5kuwuyd3f7qnkz6z6s6dmsy3uckwra7bvggyd.onion:18081",
            type: WalletType.monero,
          );
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
          await disableServiceStatusFiatDisabled(sharedPreferences);
          break;
        case 31:
          await updateNanoNodeList(nodes: nodes);
          break;
        case 32:
          await updateBtcNanoWalletInfos(walletInfoSource);
          break;
        case 33:
          await addTronNodeList(nodes: nodes);
          await changeTronCurrentNodeToDefault(sharedPreferences: sharedPreferences, nodes: nodes);
          break;
        case 34:
          await _addElectRsNode(nodes, sharedPreferences);
        case 35:
          await _switchElectRsNode(nodes, sharedPreferences);
          break;
        case 36:
          await addWowneroNodeList(nodes: nodes);
          await changeWowneroCurrentNodeToDefault(
              sharedPreferences: sharedPreferences, nodes: nodes);
          break;
        case 37:
          await replaceTronDefaultNode(sharedPreferences: sharedPreferences, nodes: nodes);
          break;
        case 38:
          await fixBtcDerivationPaths(walletInfoSource);
          break;
        case 39:
          _fixNodesUseSSLFlag(nodes);
          await changeDefaultNanoNode(nodes, sharedPreferences);
          break;
        case 40:
          await removeMoneroWorld(sharedPreferences: sharedPreferences, nodes: nodes);
          break;
        case 41:
          _changeExchangeProviderAvailability(
            sharedPreferences,
            providerName: "Quantex",
            enabled: false,
          );
          await _addSethNode(nodes, sharedPreferences);
          await updateTronNodesWithNowNodes(sharedPreferences: sharedPreferences, nodes: nodes);
          break;
        case 42:
          _fixNodesUseSSLFlag(nodes);
          break;
        case 43:
          _fixNodesUseSSLFlag(nodes);
          _changeExchangeProviderAvailability(
            sharedPreferences,
            providerName: "THORChain",
            enabled: false,
          );
          _changeExchangeProviderAvailability(
            sharedPreferences,
            providerName: "SimpleSwap",
            enabled: false,
          );
          break;
        case 44:
          _fixNodesUseSSLFlag(nodes);
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.bitcoin,
            newDefaultUri: newCakeWalletBitcoinUri,
            currentNodePreferenceKey: PreferencesKey.currentBitcoinElectrumSererIdKey,
            useSSL: true,
            oldUri: ['cakewallet.com'],
          );
          _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.tron,
            newDefaultUri: tronDefaultNodeUri,
            currentNodePreferenceKey: PreferencesKey.currentTronNodeIdKey,
            useSSL: true,
            oldUri: [
              'tron-rpc.publicnode.com:443',
              'api.trongrid.io',
            ],
          );
          break;
        case 45:
          await _backupHavenSeeds(havenSeedStore);

          updateWalletTypeNodesWithNewNode(
            newNodeUri: 'matic.nownodes.io',
            nodes: nodes,
            type: WalletType.polygon,
            useSSL: true,
          );
          updateWalletTypeNodesWithNewNode(
            newNodeUri: 'eth.nownodes.io',
            nodes: nodes,
            type: WalletType.ethereum,
            useSSL: true,
          );

          _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.tron,
            newDefaultUri: tronDefaultNodeUri,
            currentNodePreferenceKey: PreferencesKey.currentTronNodeIdKey,
            useSSL: true,
            oldUri: [
              'tron-rpc.publicnode.com:443',
              'trx.nownodes.io',
            ],
          );
          _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.solana,
            newDefaultUri: solanaDefaultNodeUri,
            currentNodePreferenceKey: PreferencesKey.currentSolanaNodeIdKey,
            useSSL: true,
            oldUri: ['rpc.ankr.com'],
          );
          break;
        case 46:
          await _fixNodesUseSSLFlag(nodes);
          await updateWalletTypeNodesWithNewNode(
            newNodeUri: 'litecoin.stackwallet.com:20063',
            nodes: nodes,
            type: WalletType.litecoin,
            useSSL: true,
          );
          await updateWalletTypeNodesWithNewNode(
            newNodeUri: 'electrum-ltc.bysh.me:50002',
            nodes: nodes,
            type: WalletType.litecoin,
            useSSL: true,
          );
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.solana,
            newDefaultUri: solanaDefaultNodeUri,
            currentNodePreferenceKey: PreferencesKey.currentSolanaNodeIdKey,
            useSSL: true,
            oldUri: [
              'rpc.ankr.com',
              'api.mainnet-beta.solana.com:443',
              'solana-rpc.publicnode.com:443',
            ],
          );
          await _updateNode(
            nodes: nodes,
            currentUri: "ethereum.publicnode.com",
            newUri: "ethereum-rpc.publicnode.com",
            useSSL: true,
          );
          await _updateNode(
            nodes: nodes,
            currentUri: "polygon-bor.publicnode.com",
            newUri: "polygon-bor-rpc.publicnode.com",
            useSSL: true,
          );
          break;
        case 47:
          await addZanoNodeList(nodes: nodes);
			    await changeZanoCurrentNodeToDefault(sharedPreferences: sharedPreferences, nodes: nodes);
          _changeExchangeProviderAvailability(
            sharedPreferences,
            providerName: "SimpleSwap",
            enabled: true,
          );
			    break;
        default:
          break;
      }

      await sharedPreferences.setInt(
          PreferencesKey.currentDefaultSettingsMigrationVersion, version);
    } catch (e) {
      printV('Migration error: ${e.toString()}');
    }
  });

  await sharedPreferences.setInt(PreferencesKey.currentDefaultSettingsMigrationVersion, version);
}

Future<void> _updateNode({
  required Box<Node> nodes,
  required String currentUri,
  String? newUri,
  bool? useSSL,
}) async {
  for (Node node in nodes.values) {
    if (node.uriRaw == currentUri) {
      if (newUri != null) {
        node.uriRaw = newUri;
      }
      if (useSSL != null) {
        node.useSSL = useSSL;
      }
      await node.save();
    }
  }
}

Future<void> _backupHavenSeeds(Box<HavenSeedStore> havenSeedStore) async {
  final future = haven?.backupHavenSeeds(havenSeedStore);
  if (future != null) {
    await future;
  }
  return;
}

/// generic function for changing any wallet default node
/// instead of making a new function for each change
Future<void> _changeDefaultNode({
  required Box<Node> nodes,
  required SharedPreferences sharedPreferences,
  required WalletType type,
  required String newDefaultUri,
  required String currentNodePreferenceKey,
  required bool useSSL,
  required List<String>
      oldUri, // leave empty if you want to force replace the node regardless of the user's current node
}) async {
  final currentNodeId = sharedPreferences.getInt(currentNodePreferenceKey);
  final currentNode = nodes.values.firstWhere((node) => node.key == currentNodeId);
  final shouldReplace = oldUri.any((e) => currentNode.uriRaw.contains(e));

  if (shouldReplace) {
    var newNodeId =
        nodes.values.firstWhereOrNull((element) => element.uriRaw == newDefaultUri)?.key;

    // new node doesn't exist, then add it
    if (newNodeId == null) {
      final newNode = Node(
        uri: newDefaultUri,
        type: type,
        useSSL: useSSL,
      );

      await nodes.add(newNode);
      newNodeId = newNode.key;
    }

    await sharedPreferences.setInt(currentNodePreferenceKey, newNodeId as int);
  }
}

/// Generic function for adding a new Node for a Wallet Type.
Future<void> updateWalletTypeNodesWithNewNode({
  required Box<Node> nodes,
  required WalletType type,
  required String newNodeUri,
  bool? useSSL,
}) async {
  // If it already exists in the box of nodes, no need to add it annymore.
  if (nodes.values.any((node) => node.uriRaw == newNodeUri)) return;

  await nodes.add(
    Node(
      uri: newNodeUri,
      type: type,
      useSSL: useSSL,
    ),
  );
}

void _changeExchangeProviderAvailability(SharedPreferences sharedPreferences,
    {required String providerName, required bool enabled}) {
  final Map<String, dynamic> exchangeProvidersSelection =
      json.decode(sharedPreferences.getString(PreferencesKey.exchangeProvidersSelection) ?? "{}")
          as Map<String, dynamic>;

  exchangeProvidersSelection[providerName] = enabled;

  sharedPreferences.setString(
    PreferencesKey.exchangeProvidersSelection,
    json.encode(exchangeProvidersSelection),
  );
}

Future<void> _fixNodesUseSSLFlag(Box<Node> nodes) async {
  for (Node node in nodes.values) {
    switch (node.uriRaw) {
      case cakeWalletLitecoinElectrumUri:
      case cakeWalletBitcoinElectrumUri:
      case newCakeWalletBitcoinUri:
      case newCakeWalletMoneroUri:
        node.useSSL = true;
        node.trusted = true;
        await node.save();
    }
  }
}

Future<void> updateNanoNodeList({required Box<Node> nodes}) async {
  final nodeList = await loadDefaultNanoNodes();
  var listOfNewEndpoints = <String>[
    "app.natrium.io",
    "rainstorm.city",
    "node.somenano.com",
    "nanoslo.0x.no",
    "www.bitrequest.app",
  ];
  // add new nodes:
  for (final node in nodeList) {
    if (listOfNewEndpoints.contains(node.uriRaw) && !nodes.values.contains(node)) {
      await nodes.add(node);
    }
  }

  // update the nautilus node:
  final nautilusNode =
      nodes.values.firstWhereOrNull((element) => element.uriRaw == "node.perish.co");
  if (nautilusNode != null) {
    nautilusNode.uriRaw = "node.nautilus.io";
    nautilusNode.path = "/api";
    nautilusNode.useSSL = true;
    await nautilusNode.save();
  }
}

Future<void> disableServiceStatusFiatDisabled(SharedPreferences sharedPreferences) async {
  final currentFiat = await sharedPreferences.getInt(PreferencesKey.currentFiatApiModeKey) ?? -1;
  if (currentFiat == -1 || currentFiat == FiatApiMode.enabled.raw) {
    return;
  }

  if (currentFiat == FiatApiMode.disabled.raw || currentFiat == FiatApiMode.torOnly.raw) {
    await sharedPreferences.setBool(PreferencesKey.disableBulletinKey, true);
  }
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
    final root = await getAppDir();

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

Node? getZanoDefaultNode({required Box<Node> nodes}) {
    return nodes.values.firstWhereOrNull(
          (Node node) => node.uriRaw == zanoDefaultNodeUri)
          ?? nodes.values.firstWhereOrNull((node) => node.type == WalletType.zano);
}

Node getMoneroDefaultNode({required Box<Node> nodes}) {
  var nodeUri = newCakeWalletMoneroUri;

  try {
    return nodes.values.firstWhere((Node node) => node.uriRaw == nodeUri);
  } catch (_) {
    return nodes.values.first;
  }
}

Node? getSolanaDefaultNode({required Box<Node> nodes}) {
  return nodes.values.firstWhereOrNull((Node node) => node.uriRaw == solanaDefaultNodeUri) ??
      nodes.values.firstWhereOrNull((node) => node.type == WalletType.solana);
}

Node? getTronDefaultNode({required Box<Node> nodes}) {
  return nodes.values.firstWhereOrNull((Node node) => node.uriRaw == tronDefaultNodeUri) ??
      nodes.values.firstWhereOrNull((node) => node.type == WalletType.tron);
}

Node getWowneroDefaultNode({required Box<Node> nodes}) {
  final timeZone = DateTime.now().timeZoneOffset.inHours;
  var nodeUri = '';

  if (timeZone >= 1) {
    // Eurasia
    nodeUri = 'node2.monerodevs.org.lol:34568';
  } else if (timeZone <= -4) {
    // America
    nodeUri = 'node3.monerodevs.org:34568';
  }

  if (nodeUri == '') {
    return nodes.values.where((element) => element.type == WalletType.wownero).first;
  }

  try {
    return nodes.values.firstWhere(
      (Node node) => node.uriRaw == nodeUri,
      orElse: () => nodes.values.where((element) => element.type == WalletType.wownero).first,
    );
  } catch (_) {
    return nodes.values.where((element) => element.type == WalletType.wownero).first;
  }
}

Future<void> insecureStorageMigration({
  required SharedPreferences sharedPreferences,
  required SecureStorage secureStorage,
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
    printV("Error migrating shared preferences to secure storage!: $e");
    // this actually shouldn't be that big of a problem since we don't delete the old keys in this update
    // and we read and write to the new locations when loading storage, the migration is just for extra safety
  }
}

Future<void> rewriteSecureStoragePin({required SecureStorage secureStorage}) async {
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
    // TODO: find a way to add those with the generated secure storage
    // iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    // mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
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
      printV(e.toString());
    }
  });
}

Future<void> updateDisplayModes(SharedPreferences sharedPreferences) async {
  final currentBalanceDisplayMode =
      sharedPreferences.getInt(PreferencesKey.currentBalanceDisplayModeKey) ?? -1;
  final balanceDisplayMode = currentBalanceDisplayMode < 2 ? 3 : 2;
  await sharedPreferences.setInt(PreferencesKey.currentBalanceDisplayModeKey, balanceDisplayMode);
}

Future<void> generateBackupPassword(SecureStorage secureStorage) async {
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

  final newCakeWalletNode =
      Node(uri: newCakeWalletMoneroUri, type: WalletType.monero, trusted: true);

  await nodeSource.add(newCakeWalletNode);

  if (needToReplaceCurrentMoneroNode) {
    await sharedPreferences.setInt(PreferencesKey.currentNodeIdKey, newCakeWalletNode.key as int);
  }
}

Future<void> fixBtcDerivationPaths(Box<WalletInfo> walletsInfoSource) async {
  for (WalletInfo walletInfo in walletsInfoSource.values) {
    if (walletInfo.type == WalletType.bitcoin ||
        walletInfo.type == WalletType.bitcoinCash ||
        walletInfo.type == WalletType.litecoin) {
      if (walletInfo.derivationInfo?.derivationPath == "m/0'/0") {
        walletInfo.derivationInfo!.derivationPath = "m/0'";
        await walletInfo.save();
      }
    }
  }
}

Future<void> updateBtcNanoWalletInfos(Box<WalletInfo> walletsInfoSource) async {
  for (WalletInfo walletInfo in walletsInfoSource.values) {
    if (walletInfo.type == WalletType.nano || walletInfo.type == WalletType.bitcoin) {
      walletInfo.derivationInfo = DerivationInfo(
        derivationPath: walletInfo.derivationPath,
        derivationType: walletInfo.derivationType,
        address: walletInfo.address,
        transactionsCount: walletInfo.restoreHeight,
      );
      await walletInfo.save();
    }
  }
}

Future<void> changeDefaultNanoNode(
    Box<Node> nodeSource, SharedPreferences sharedPreferences) async {
  const oldNanoNodeUriPattern = 'rpc.nano.to';
  final currentNanoNodeId = sharedPreferences.getInt(PreferencesKey.currentNanoNodeIdKey);
  final currentNanoNode = nodeSource.values.firstWhere((node) => node.key == currentNanoNodeId);

  final newCakeWalletNode = Node(
    uri: nanoDefaultNodeUri,
    type: WalletType.nano,
    useSSL: true,
  );

  await nodeSource.add(newCakeWalletNode);

  if (currentNanoNode.uri.toString().contains(oldNanoNodeUriPattern)) {
    await sharedPreferences.setInt(
        PreferencesKey.currentNanoNodeIdKey, newCakeWalletNode.key as int);
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

  final newCakeWalletBitcoinNode =
      Node(uri: newCakeWalletBitcoinUri, type: WalletType.bitcoin, useSSL: true);

  if (!nodeSource.values.any((element) => element.uriRaw == newCakeWalletBitcoinUri)) {
    await nodeSource.add(newCakeWalletBitcoinNode);
  }

  if (needToReplaceCurrentBitcoinNode) {
    await sharedPreferences.setInt(
        PreferencesKey.currentBitcoinElectrumSererIdKey, newCakeWalletBitcoinNode.key as int);
  }
}

Future<void> _addSethNode(Box<Node> nodeSource, SharedPreferences sharedPreferences) async {
  _addBitcoinNode(
    nodeSource: nodeSource,
    sharedPreferences: sharedPreferences,
    nodeUri: "fulcrum.sethforprivacy.com:50002",
    useSSL: false,
  );
}

Future<void> _addElectRsNode(Box<Node> nodeSource, SharedPreferences sharedPreferences) async {
  _addBitcoinNode(
    nodeSource: nodeSource,
    sharedPreferences: sharedPreferences,
    nodeUri: cakeWalletSilentPaymentsElectrsUri,
  );
}

Future<void> _addBitcoinNode({
  required Box<Node> nodeSource,
  required SharedPreferences sharedPreferences,
  required String nodeUri,
  bool replaceExisting = false,
  bool useSSL = false,
}) async {
  bool isNodeExists = nodeSource.values.any((element) => element.uriRaw == nodeUri);
  if (isNodeExists) {
    return;
  }
  const cakeWalletBitcoinNodeUriPattern = '.cakewallet.com';
  final currentBitcoinNodeId =
      sharedPreferences.getInt(PreferencesKey.currentBitcoinElectrumSererIdKey);
  final currentBitcoinNode =
      nodeSource.values.firstWhere((node) => node.key == currentBitcoinNodeId);
  final needToReplaceCurrentBitcoinNode =
      currentBitcoinNode.uri.toString().contains(cakeWalletBitcoinNodeUriPattern);

  final newElectRsBitcoinNode = Node(uri: nodeUri, type: WalletType.bitcoin, useSSL: useSSL);

  await nodeSource.add(newElectRsBitcoinNode);

  if (needToReplaceCurrentBitcoinNode && replaceExisting) {
    await sharedPreferences.setInt(
        PreferencesKey.currentBitcoinElectrumSererIdKey, newElectRsBitcoinNode.key as int);
  }
}

Future<void> _switchElectRsNode(Box<Node> nodeSource, SharedPreferences sharedPreferences) async {
  final currentBitcoinNodeId =
      sharedPreferences.getInt(PreferencesKey.currentBitcoinElectrumSererIdKey);
  final currentBitcoinNode =
      nodeSource.values.firstWhere((node) => node.key == currentBitcoinNodeId);
  final needToReplaceCurrentBitcoinNode =
      currentBitcoinNode.uri.toString().contains('electrs.cakewallet.com');

  if (!needToReplaceCurrentBitcoinNode) return;

  final btcElectrumNode = nodeSource.values.firstWhereOrNull(
    (node) => node.uri.toString().contains('btc-electrum.cakewallet.com'),
  );

  if (btcElectrumNode == null) {
    final newBtcElectrumBitcoinNode = Node(
      uri: newCakeWalletBitcoinUri,
      type: WalletType.bitcoin,
      useSSL: false,
    );
    await nodeSource.add(newBtcElectrumBitcoinNode);
    await sharedPreferences.setInt(
      PreferencesKey.currentBitcoinElectrumSererIdKey,
      newBtcElectrumBitcoinNode.key as int,
    );
  } else {
    await sharedPreferences.setInt(
      PreferencesKey.currentBitcoinElectrumSererIdKey,
      btcElectrumNode.key as int,
    );
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
  final currentTronNodeId = sharedPreferences.getInt(PreferencesKey.currentTronNodeIdKey);
  final currentWowneroNodeId = sharedPreferences.getInt(PreferencesKey.currentWowneroNodeIdKey);
  final currentZanoNodeId = sharedPreferences.getInt(PreferencesKey.currentZanoNodeIdKey);
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
  final currentTronNodeServer =
      nodeSource.values.firstWhereOrNull((node) => node.key == currentTronNodeId);
  final currentWowneroNodeServer =
      nodeSource.values.firstWhereOrNull((node) => node.key == currentWowneroNodeId);
  final currentZanoNode = nodeSource.values.firstWhereOrNull((node) => node.key == currentZanoNodeId);

  if (currentMoneroNode == null) {
    final newCakeWalletNode = Node(uri: newCakeWalletMoneroUri, type: WalletType.monero);
    await nodeSource.add(newCakeWalletNode);
    await sharedPreferences.setInt(PreferencesKey.currentNodeIdKey, newCakeWalletNode.key as int);
  }

  if (currentBitcoinElectrumServer == null) {
    final cakeWalletElectrum =
        Node(uri: cakeWalletBitcoinElectrumUri, type: WalletType.bitcoin, useSSL: false);
    await nodeSource.add(cakeWalletElectrum);
    final cakeWalletElectrumTestnet =
        Node(uri: publicBitcoinTestnetElectrumUri, type: WalletType.bitcoin, useSSL: false);
    await nodeSource.add(cakeWalletElectrumTestnet);
    await sharedPreferences.setInt(
        PreferencesKey.currentBitcoinElectrumSererIdKey, cakeWalletElectrum.key as int);
  }

  if (currentLitecoinElectrumServer == null) {
    final cakeWalletElectrum =
        Node(uri: cakeWalletLitecoinElectrumUri, type: WalletType.litecoin, useSSL: false);
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
    final node =
        Node(uri: cakeWalletBitcoinCashDefaultNodeUri, type: WalletType.bitcoinCash, useSSL: false);
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

  if (currentTronNodeServer == null) {
    final node = Node(uri: tronDefaultNodeUri, type: WalletType.tron);
    await nodeSource.add(node);
    await sharedPreferences.setInt(PreferencesKey.currentTronNodeIdKey, node.key as int);
  }

  if (currentWowneroNodeServer == null) {
    final node = Node(uri: wowneroDefaultNodeUri, type: WalletType.wownero);
    await nodeSource.add(node);
    await sharedPreferences.setInt(PreferencesKey.currentWowneroNodeIdKey, node.key as int);
  }

  if (currentZanoNode == null) {
    final node = Node(uri: zanoDefaultNodeUri, type: WalletType.zano);
    await nodeSource.add(node);
    await sharedPreferences.setInt(PreferencesKey.currentZanoNodeIdKey, node.key as int);
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
    cakeWalletNode =
        Node(uri: cakeWalletBitcoinElectrumUri, type: WalletType.bitcoin, useSSL: false);
    // final cakeWalletElectrumTestnet =
    //     Node(uri: publicBitcoinTestnetElectrumUri, type: WalletType.bitcoin, useSSL: false);
    // await nodeSource.add(cakeWalletElectrumTestnet);
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

Future<void> addWowneroNodeList({required Box<Node> nodes}) async {
  final nodeList = await loadDefaultWowneroNodes();
  for (var node in nodeList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }
  }
}

Future<void> addZanoNodeList({required Box<Node> nodes}) async {
	final nodeList = await loadDefaultZanoNodes();
	for (var node in nodeList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }  
  }
}

Future<void> changeWowneroCurrentNodeToDefault(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  final node = getWowneroDefaultNode(nodes: nodes);
  final nodeId = node?.key as int? ?? 0;

  await sharedPreferences.setInt(PreferencesKey.currentWowneroNodeIdKey, nodeId);
}

Future<void> changeZanoCurrentNodeToDefault(
		{required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  final node = getZanoDefaultNode(nodes: nodes);
	final nodeId = node?.key as int? ?? 0;
	await sharedPreferences.setInt(PreferencesKey.currentZanoNodeIdKey, nodeId);
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

Future<void> addTronNodeList({required Box<Node> nodes}) async {
  final nodeList = await loadDefaultTronNodes();
  for (var node in nodeList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }
  }
}

Future<void> changeTronCurrentNodeToDefault(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  final node = getTronDefaultNode(nodes: nodes);
  final nodeId = node?.key as int? ?? 0;

  await sharedPreferences.setInt(PreferencesKey.currentTronNodeIdKey, nodeId);
}

Future<void> replaceTronDefaultNode({
  required SharedPreferences sharedPreferences,
  required Box<Node> nodes,
}) async {
  // Get the currently active node
  final currentTronNodeId = sharedPreferences.getInt(PreferencesKey.currentTronNodeIdKey);
  final currentTronNode =
      nodes.values.firstWhereOrNull((Node node) => node.key == currentTronNodeId);

  //Confirm if this node is part of the default nodes from CakeWallet
  final tronDefaultNodeList = [
    'tron-rpc.publicnode.com:443',
    'api.trongrid.io',
  ];
  bool needsToBeReplaced =
      currentTronNode == null ? true : tronDefaultNodeList.contains(currentTronNode.uriRaw);

  // If it's a custom node, return. We don't want to switch users from their custom nodes
  if (!needsToBeReplaced) {
    return;
  }

  // If it's not, we switch user to the new default node: NowNodes
  await changeTronCurrentNodeToDefault(sharedPreferences: sharedPreferences, nodes: nodes);
}

Future<void> removeMoneroWorld(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  const cakeWalletMoneroNodeUriPattern = '.moneroworld.com';
  final currentMoneroNodeId = sharedPreferences.getInt(PreferencesKey.currentNodeIdKey);
  final currentMoneroNode = nodes.values.firstWhere((node) => node.key == currentMoneroNodeId);
  final needToReplaceCurrentMoneroNode =
      currentMoneroNode.uri.toString().contains(cakeWalletMoneroNodeUriPattern);

  nodes.values.forEach((node) async {
    if (node.type == WalletType.monero &&
        node.uri.toString().contains(cakeWalletMoneroNodeUriPattern)) {
      await node.delete();
    }
  });

  if (needToReplaceCurrentMoneroNode) {
    await changeMoneroCurrentNodeToDefault(sharedPreferences: sharedPreferences, nodes: nodes);
  }
}

Future<void> updateTronNodesWithNowNodes({
  required SharedPreferences sharedPreferences,
  required Box<Node> nodes,
}) async {
  final tronNowNodesUri = 'trx.nownodes.io';

  if (nodes.values.any((node) => node.uriRaw == tronNowNodesUri)) return;

  await nodes.add(Node(uri: tronNowNodesUri, type: WalletType.tron));

  await replaceTronDefaultNode(sharedPreferences: sharedPreferences, nodes: nodes);
}
