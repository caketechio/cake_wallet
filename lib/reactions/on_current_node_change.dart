import 'package:cw_core/utils/print_verbose.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/store/app_store.dart';

ReactionDisposer? _onCurrentNodeChangeReaction;

void startOnCurrentNodeChangeReaction(AppStore appStore) {
  _onCurrentNodeChangeReaction?.reaction.dispose();
  appStore.settingsStore.nodes.observe((change) async {
    try {
      await appStore.wallet!.connectToNode(node: change.newValue!);
    } catch (e) {
      printV(e.toString());
    }
  });
  appStore.settingsStore.powNodes.observe((change) async {
    try {
      await appStore.wallet!.connectToPowNode(node: change.newValue!);
    } catch (e) {
      printV(e.toString());
    }
  });
}
