import 'dart:ffi';
import 'package:cw_haven/api/structs/pending_transaction.dart';
import 'package:cw_haven/api/structs/ut8_box.dart';
import 'package:ffi/ffi.dart';

typedef create_wallet = Int8 Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32, Pointer<Utf8>);

typedef restore_wallet_from_seed = Int8 Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32, Int64, Pointer<Utf8>);

typedef restore_wallet_from_keys = Int8 Function(Pointer<Utf8>, Pointer<Utf8>,
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32, Int64, Pointer<Utf8>);

typedef is_wallet_exist = Int8 Function(Pointer<Utf8>);

typedef load_wallet = Int8 Function(Pointer<Utf8>, Pointer<Utf8>, Int8);

typedef error_string = Pointer<Utf8> Function();

typedef get_filename = Pointer<Utf8> Function();

typedef get_seed = Pointer<Utf8> Function();

typedef get_address = Pointer<Utf8> Function(Int32, Int32);

typedef get_full_balance = Pointer<Int64> Function(Int32);

typedef get_unlocked_balance = Pointer<Int64> Function(Int32);

typedef get_full_balanace = Int64 Function(Int32);

typedef get_unlocked_balanace = Int64 Function(Int32);

typedef get_current_height = Int64 Function();

typedef get_node_height = Int64 Function();

typedef is_connected = Int8 Function();

typedef setup_node = Int8 Function(
    Pointer<Utf8>, Pointer<Utf8>?, Pointer<Utf8>?, Int8, Int8, Pointer<Utf8>);

typedef start_refresh = Void Function();

typedef connect_to_node = Int8 Function();

typedef set_refresh_from_block_height = Void Function(Int64);

typedef set_recovering_from_seed = Void Function(Int8);

typedef store_c = Void Function(Pointer<Utf8>);

typedef set_password = Int8 Function(Pointer<Utf8> password, Pointer<Utf8Box> error);

typedef set_listener = Void Function();

typedef get_syncing_height = Int64 Function();

typedef is_needed_to_refresh = Int8 Function();

typedef is_new_transaction_exist = Int8 Function();

typedef subaddrress_size = Int32 Function();

typedef subaddrress_refresh = Void Function(Int32);

typedef subaddress_get_all = Pointer<Int64> Function();

typedef subaddress_add_new = Void Function(
    Int32 accountIndex, Pointer<Utf8> label);

typedef subaddress_set_label = Void Function(
    Int32 accountIndex, Int32 addressIndex, Pointer<Utf8> label);

typedef account_size = Int32 Function();

typedef account_refresh = Void Function();

typedef account_get_all = Pointer<Int64> Function();

typedef account_add_new = Void Function(Pointer<Utf8> label);

typedef account_set_label = Void Function(
    Int32 accountIndex, Pointer<Utf8> label);

typedef transactions_refresh = Void Function();

typedef get_tx_key = Pointer<Utf8>? Function(Pointer<Utf8> txId);

typedef transactions_count = Int64 Function();

typedef transactions_get_all = Pointer<Int64> Function();

typedef transaction_create = Int8 Function(
    Pointer<Utf8> address,
    Pointer<Utf8> assetType,
    Pointer<Utf8> paymentId,
    Pointer<Utf8> amount,
    Int8 priorityRaw,
    Int32 subaddrAccount,
    Pointer<Utf8Box> error,
    Pointer<PendingTransactionRaw> pendingTransaction);

typedef transaction_create_mult_dest = Int8 Function(
    Pointer<Pointer<Utf8>> addresses,
    Pointer<Utf8> assetType,
    Pointer<Utf8> paymentId,
    Pointer<Pointer<Utf8>> amounts,
    Int32 size,
    Int8 priorityRaw,
    Int32 subaddrAccount,
    Pointer<Utf8Box> error,
    Pointer<PendingTransactionRaw> pendingTransaction);

typedef transaction_commit = Int8 Function(Pointer<PendingTransactionRaw>, Pointer<Utf8Box>);

typedef secret_view_key = Pointer<Utf8> Function();

typedef public_view_key = Pointer<Utf8> Function();

typedef secret_spend_key = Pointer<Utf8> Function();

typedef public_spend_key = Pointer<Utf8> Function();

typedef close_current_wallet = Void Function();

typedef on_startup = Void Function();

typedef rescan_blockchain = Void Function();

typedef asset_types = Pointer<Pointer<Utf8>> Function();

typedef asset_types_size = Int32 Function();

typedef get_rate = Pointer<Int64> Function();

typedef size_of_rate = Int32 Function();

typedef update_rate = Void Function();

typedef set_trusted_daemon = Void Function(Int8 trusted);

typedef trusted_daemon = Int8 Function();

typedef estimate_transaction_fee = Int64 Function(
    Int32 outputs,
    Int8 priorityRaw);