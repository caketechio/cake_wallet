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
const decredDefaultUri = "default-spv-nodes";

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

          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.monero,
            currentNodePreferenceKey: PreferencesKey.currentNodeIdKey,
            useSSL: true,
            trusted: true,
          );
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.bitcoin,
            currentNodePreferenceKey: PreferencesKey.currentBitcoinElectrumSererIdKey,
            useSSL: true,
          );
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.litecoin,
            currentNodePreferenceKey: PreferencesKey.currentLitecoinElectrumSererIdKey,
            useSSL: true,
          );
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.haven,
            currentNodePreferenceKey: PreferencesKey.currentHavenNodeIdKey,
          );
          break;
        case 2:
          await replaceNodesMigration(nodes: nodes);
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.monero,
            newDefaultUri: newCakeWalletMoneroUri,
            currentNodePreferenceKey: PreferencesKey.currentNodeIdKey,
            useSSL: true,
            trusted: true,
            oldUri: [
              'xmr-node-uk.cakewallet.com:18081',
              'eu-node.cakewallet.io:18081',
              'node.cakewallet.io:18081'
            ],
          );
          break;
        case 3:
          await updateNodeTypes(nodes: nodes);
          await addWalletNodeList(nodes: nodes, type: WalletType.bitcoin);

          break;
        case 4:
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.bitcoin,
            newDefaultUri: newCakeWalletBitcoinUri,
            currentNodePreferenceKey: PreferencesKey.currentBitcoinElectrumSererIdKey,
            useSSL: true,
          );
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
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.monero,
            newDefaultUri: newCakeWalletMoneroUri,
            currentNodePreferenceKey: PreferencesKey.currentNodeIdKey,
            trusted: true,
            oldUri: ['.cakewallet.com'],
          );
          break;

        case 12:
          await checkCurrentNodes(nodes, powNodes, sharedPreferences);
          break;

        case 13:
          await resetBitcoinElectrumServer(nodes, sharedPreferences);
          break;

        case 15:
          await addWalletNodeList(nodes: nodes, type: WalletType.litecoin);
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.litecoin,
            currentNodePreferenceKey: PreferencesKey.currentLitecoinElectrumSererIdKey,
          );
          await checkCurrentNodes(nodes, powNodes, sharedPreferences);
          break;

        case 16:
          await addWalletNodeList(nodes: nodes, type: WalletType.haven);
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.haven,
            currentNodePreferenceKey: PreferencesKey.currentHavenNodeIdKey,
          );
          await checkCurrentNodes(nodes, powNodes, sharedPreferences);
          break;

        case 17:
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.haven,
            currentNodePreferenceKey: PreferencesKey.currentHavenNodeIdKey,
          );
          break;

        case 18:
          addWalletNodeList(nodes: nodes, type: WalletType.monero);
          break;

        case 19:
          await validateBitcoinSavedTransactionPriority(sharedPreferences);
          break;
        case 20:
          await migrateExchangeStatus(sharedPreferences);
          break;
        case 21:
          await addWalletNodeList(nodes: nodes, type: WalletType.ethereum);
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.ethereum,
            currentNodePreferenceKey: PreferencesKey.currentEthereumNodeIdKey,
          );
          break;
        case 22:
          await addWalletNodeList(nodes: nodes, type: WalletType.nano);
          await addNanoPowNodeList(nodes: powNodes);
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.nano,
            currentNodePreferenceKey: PreferencesKey.currentNanoNodeIdKey,
          );
          await _changeDefaultNode(
            nodes: powNodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.nano,
            currentNodePreferenceKey: PreferencesKey.currentNanoPowNodeIdKey,
            newDefaultUri: nanoDefaultPowNodeUri,
          );
          break;
        case 23:
          await addWalletNodeList(nodes: nodes, type: WalletType.bitcoinCash);
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.bitcoinCash,
            currentNodePreferenceKey: PreferencesKey.currentBitcoinCashNodeIdKey,
          );
          break;
        case 24:
          await addWalletNodeList(nodes: nodes, type: WalletType.polygon);
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.polygon,
            currentNodePreferenceKey: PreferencesKey.currentPolygonNodeIdKey,
          );
          break;
        case 25:
          await rewriteSecureStoragePin(secureStorage: secureStorage);
          break;
        case 26:

          /// commented out as it was a probable cause for some users to have white screen issues
          /// maybe due to multiple access on Secure Storage at once
          /// or long await time on start of the app
          // await insecureStorageMigration(secureStorage: secureStorage, sharedPreferences: sharedPreferences);
          break;
        case 27:
          await addWalletNodeList(nodes: nodes, type: WalletType.solana);
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.solana,
            currentNodePreferenceKey: PreferencesKey.currentSolanaNodeIdKey,
          );
          break;

        case 28:
          await _updateMoneroPriority(sharedPreferences);
          break;
        case 29:
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.bitcoin,
            newDefaultUri: newCakeWalletBitcoinUri,
            currentNodePreferenceKey: PreferencesKey.currentBitcoinElectrumSererIdKey,
            useSSL: true,
            oldUri: ['.cakewallet.com'],
          );
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
          await addWalletNodeList(nodes: nodes, type: WalletType.tron);
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.tron,
            currentNodePreferenceKey: PreferencesKey.currentTronNodeIdKey,
          );
          break;
        case 34:
          addWalletNodeList(nodes: nodes, type: WalletType.bitcoin);
        case 35:
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.bitcoin,
            newDefaultUri: newCakeWalletBitcoinUri,
            currentNodePreferenceKey: PreferencesKey.currentBitcoinElectrumSererIdKey,
            useSSL: true,
            oldUri: ['electrs.cakewallet.com'],
          );
          break;
        case 36:
          await addWalletNodeList(nodes: nodes, type: WalletType.wownero);
          await changeWowneroCurrentNodeToDefault(
              sharedPreferences: sharedPreferences, nodes: nodes);
          break;
        case 37:
          // removed as it would be replaced again anyway
          // await replaceTronDefaultNode(sharedPreferences: sharedPreferences, nodes: nodes);
          break;
        case 38:
          await fixBtcDerivationPaths(walletInfoSource);
          break;
        case 39:
          _fixNodesUseSSLFlag(nodes);
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.nano,
            newDefaultUri: nanoDefaultNodeUri,
            currentNodePreferenceKey: PreferencesKey.currentNanoNodeIdKey,
            useSSL: true,
            oldUri: ['rpc.nano.to'],
          );
          break;
        case 40:
          await removeMoneroWorld(sharedPreferences: sharedPreferences, nodes: nodes);
          break;
        case 41:
          _changeExchangeProviderAvailability(
            sharedPreferences,
            providerName: "SwapTrade",
            enabled: false,
          );
          addWalletNodeList(nodes: nodes, type: WalletType.bitcoin);
          addWalletNodeList(nodes: nodes, type: WalletType.tron);
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

          addWalletNodeList(nodes: nodes, type: WalletType.polygon);
          addWalletNodeList(nodes: nodes, type: WalletType.ethereum);
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
          await addWalletNodeList(nodes: nodes, type: WalletType.litecoin);
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
        case 47:
          await addWalletNodeList(nodes: nodes, type: WalletType.zano);
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.zano,
            currentNodePreferenceKey: PreferencesKey.currentZanoNodeIdKey,
          );
          _changeExchangeProviderAvailability(
            sharedPreferences,
            providerName: "SimpleSwap",
            enabled: true,
          );
          _changeExchangeProviderAvailability(
            sharedPreferences,
            providerName: "SwapTrade",
            enabled: false,
          );
          break;
        case 48:
          await addWalletNodeList(nodes: nodes, type: WalletType.decred);
          await _changeDefaultNode(
            nodes: nodes,
            sharedPreferences: sharedPreferences,
            type: WalletType.decred,
            currentNodePreferenceKey: PreferencesKey.currentDecredNodeIdKey,
          );
          break;
        default:
          break;
      }

      await sharedPreferences.setInt(
          PreferencesKey.currentDefaultSettingsMigrationVersion, version);
    } catch (e, s) {
      printV('Migration error: ${e.toString()}');
      printV('Migration error: ${s}');
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
  required String currentNodePreferenceKey,
  bool useSSL = true,
  bool trusted = false,
  String? newDefaultUri, // ignore, if you want to use the default node uri
  List<String>?
      oldUri, // ignore, if you want to force replace the node regardless of the user's current node
}) async {
  final currentNodeId = sharedPreferences.getInt(currentNodePreferenceKey);
  final bool shouldReplace;
  if (currentNodeId == null) {
    shouldReplace = true;
  } else {
    final currentNode = nodes.values.firstWhere((node) => node.key == currentNodeId);
    shouldReplace = oldUri?.any((e) => currentNode.uriRaw.contains(e)) ?? true;
  }

  if (shouldReplace) {
    newDefaultUri ??= _getDefaultNodeUri(type);
    var newNodeId =
        nodes.values.firstWhereOrNull((element) => element.uriRaw == newDefaultUri)?.key;

    // new node doesn't exist, then add it
    if (newNodeId == null) {
      final newNode = Node(
        uri: newDefaultUri,
        type: type,
        useSSL: useSSL,
        trusted: trusted,
      );

      await nodes.add(newNode);
      newNodeId = newNode.key;
    }

    await sharedPreferences.setInt(currentNodePreferenceKey, newNodeId as int);
  }
}

String _getDefaultNodeUri(WalletType type) {
  switch (type) {
    case WalletType.monero:
      return newCakeWalletMoneroUri;
    case WalletType.bitcoin:
      return newCakeWalletBitcoinUri;
    case WalletType.litecoin:
      return cakeWalletLitecoinElectrumUri;
    case WalletType.haven:
      return havenDefaultNodeUri;
    case WalletType.ethereum:
      return ethereumDefaultNodeUri;
    case WalletType.nano:
      return nanoDefaultNodeUri;
    case WalletType.bitcoinCash:
      return cakeWalletBitcoinCashDefaultNodeUri;
    case WalletType.polygon:
      return polygonDefaultNodeUri;
    case WalletType.solana:
      return solanaDefaultNodeUri;
    case WalletType.tron:
      return tronDefaultNodeUri;
    case WalletType.wownero:
      return wowneroDefaultNodeUri;
    case WalletType.zano:
      return zanoDefaultNodeUri;
    case WalletType.decred:
      return decredDefaultUri;
    case WalletType.banano:
    case WalletType.none:
      return '';
  }
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
  final nodeList = await loadDefaultNodes(WalletType.nano);
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

Node? getBitcoinTestnetDefaultElectrumServer({required Box<Node> nodes}) {
  return nodes.values
          .firstWhereOrNull((Node node) => node.uriRaw == publicBitcoinTestnetElectrumUri) ??
      nodes.values.firstWhereOrNull((node) => node.type == WalletType.bitcoin);
}

Node? getDefaultNode({required Box<Node> nodes, required WalletType type}) {
  final defaultUri = _getDefaultNodeUri(type);
  return nodes.values.firstWhereOrNull((Node node) => node.uriRaw == defaultUri) ??
      nodes.values.firstWhereOrNull((node) => node.type == type);
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

Future<void> updateNodeTypes({required Box<Node> nodes}) async {
  nodes.values.forEach((node) async {
    if (node.type == null) {
      node.type = WalletType.monero;
      await node.save();
    }
  });
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
  final currentDecredNodeId = sharedPreferences.getInt(PreferencesKey.currentDecredNodeIdKey);
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
  final currentDecredNodeServer =
      nodeSource.values.firstWhereOrNull((node) => node.key == currentDecredNodeId);
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
  final currentZanoNode =
      nodeSource.values.firstWhereOrNull((node) => node.key == currentZanoNodeId);

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

  if (currentDecredNodeServer == null) {
    final node = Node(uri: decredDefaultUri, type: WalletType.decred);
    await nodeSource.add(node);
    await sharedPreferences.setInt(PreferencesKey.currentDecredNodeIdKey, node.key as int);
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

Future<void> migrateExchangeStatus(SharedPreferences sharedPreferences) async {
  final isExchangeDisabled = sharedPreferences.getBool(PreferencesKey.disableExchangeKey);
  if (isExchangeDisabled == null) {
    return;
  }

  await sharedPreferences.setInt(PreferencesKey.exchangeStatusKey,
      isExchangeDisabled ? ExchangeApiMode.disabled.raw : ExchangeApiMode.enabled.raw);

  await sharedPreferences.remove(PreferencesKey.disableExchangeKey);
}

Future<void> changeWowneroCurrentNodeToDefault(
    {required SharedPreferences sharedPreferences, required Box<Node> nodes}) async {
  final node = getWowneroDefaultNode(nodes: nodes);
  final nodeId = node.key as int? ?? 0;

  await sharedPreferences.setInt(PreferencesKey.currentWowneroNodeIdKey, nodeId);
}

Future<void> addNanoPowNodeList({required Box<Node> nodes}) async {
  final nodeList = await loadDefaultNanoPowNodes();
  for (var node in nodeList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }
  }
}

Node? getNanoDefaultPowNode({required Box<Node> nodes}) {
  return nodes.values.firstWhereOrNull((Node node) => node.uriRaw == nanoDefaultPowNodeUri) ??
      nodes.values.firstWhereOrNull((node) => (node.type == WalletType.nano));
}

Future<void> addWalletNodeList({required Box<Node> nodes, required WalletType type}) async {
  final List<Node> nodeList = await loadDefaultNodes(type);
  for (var node in nodeList) {
    if (nodes.values.firstWhereOrNull((element) => element.uriRaw == node.uriRaw) == null) {
      await nodes.add(node);
    }
  }
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
    await _changeDefaultNode(
      nodes: nodes,
      sharedPreferences: sharedPreferences,
      type: WalletType.monero,
      newDefaultUri: newCakeWalletMoneroUri,
      currentNodePreferenceKey: PreferencesKey.currentNodeIdKey,
      trusted: true,
    );
  }
}
