import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cw_core/node.dart';
import 'package:cake_wallet/entities/node_list.dart';
import 'package:cake_wallet/entities/default_settings_migration.dart';
import 'package:cw_core/wallet_type.dart';

part 'node_list_view_model.g.dart';

class NodeListViewModel = NodeListViewModelBase with _$NodeListViewModel;

abstract class NodeListViewModelBase with Store {
  NodeListViewModelBase(this._nodeSource, this._appStore)
      : nodes = ObservableList<Node>(), 
        wallet = _appStore.wallet!, 
        settingsStore = _appStore.settingsStore {   
        _bindNodes();

        reaction((_) => _appStore.wallet, (WalletBase<Balance, TransactionHistoryBase<TransactionInfo>,
              TransactionInfo>?
          _wallet) { 
            wallet = _wallet!;
            _bindNodes();
        });
  }

  @computed
  Node get currentNode {
    final node = settingsStore.nodes[wallet.type];

    if (node == null) {
      throw Exception('No node for wallet type: ${wallet.type}');
    }

    return node;
  }

  @observable
  WalletBase wallet;

  String getAlertContent(String uri) =>
      S.current.change_current_node(uri) +
          '${uri.endsWith('.onion') || uri.contains('.onion:') ? '\n' + S.current.orbot_running_alert : ''}';

  
  ObservableList<Node> nodes;
  final SettingsStore settingsStore;
  final Box<Node> _nodeSource;
  final AppStore _appStore;

  Future<void> reset() async {
    await resetToDefault(_nodeSource);

    Node node;

    switch (wallet.type) {
      case WalletType.bitcoin:
        node = getBitcoinDefaultElectrumServer(nodes: _nodeSource)!;
        break;
      case WalletType.monero:
        node = getMoneroDefaultNode(nodes: _nodeSource);
        break;
      case WalletType.litecoin:
        node = getLitecoinDefaultElectrumServer(nodes: _nodeSource)!;
        break;
      case WalletType.haven:
        node = getHavenDefaultNode(nodes: _nodeSource)!;
        break;
      default:
        throw Exception('Unexpected wallet type: ${wallet.type}');
    }

    await setAsCurrent(node);
  }

  @action
  Future<void> delete(Node node) async => node.delete();

  Future<void> setAsCurrent(Node node) async =>
      settingsStore.nodes[wallet.type] = node;
  
  @action
  void _bindNodes() {
    nodes = _nodeSource.values
        .where((Node val) => val.type == wallet.type)
        .toList()
        .asObservable();
  }
}
