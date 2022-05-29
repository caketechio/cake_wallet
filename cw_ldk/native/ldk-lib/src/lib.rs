#![allow(dead_code)]
#![allow(unused_imports)]
#![allow(unused_variables)]
#![allow(unused_mut)]
#![allow(unused_assignments)]

pub mod bitcoind_client;
mod cli;
mod flutter_ffi;
mod convert;
mod disk;
mod hex_utils;

use crate::bitcoind_client::BitcoindClient;
use crate::disk::FilesystemLogger;
use bitcoin::blockdata::constants::genesis_block;
use bitcoin::blockdata::transaction::Transaction;
use bitcoin::consensus::encode;
use bitcoin::network::constants::Network;
use bitcoin::secp256k1::Secp256k1;
use bitcoin::BlockHash;
use bitcoin_bech32::WitnessProgram;
use lightning::chain;
use lightning::chain::chaininterface::{BroadcasterInterface, ConfirmationTarget, FeeEstimator};
use lightning::chain::chainmonitor;
use lightning::chain::keysinterface::{InMemorySigner, KeysInterface, KeysManager, Recipient};
use lightning::chain::{BestBlock, Filter, Watch};
use lightning::ln::channelmanager;
use lightning::ln::channelmanager::{
	ChainParameters, ChannelManagerReadArgs, SimpleArcChannelManager,
};
use lightning::ln::peer_handler::{IgnoringMessageHandler, MessageHandler, SimpleArcPeerManager};
use lightning::ln::{PaymentHash, PaymentPreimage, PaymentSecret};
use lightning::routing::network_graph::{NetGraphMsgHandler, NetworkGraph};
use lightning::routing::scoring::ProbabilisticScorer;
use lightning::util::config::UserConfig;
use lightning::util::events::{Event, PaymentPurpose};
use lightning::util::logger::Logger;
use lightning::{log_bytes, log_given_level, log_internal, log_trace};
use lightning::util::ser::ReadableArgs;
use lightning_background_processor::{BackgroundProcessor, Persister};
use lightning_block_sync::{init, rpc};
use lightning_block_sync::poll;
use lightning_block_sync::SpvClient;
use lightning_block_sync::UnboundedCache;
use lightning_invoice::payment;
use lightning_invoice::utils::DefaultRouter;
use lightning_invoice::Invoice;
use lightning_net_tokio::SocketDescriptor;
use lightning_persister::FilesystemPersister;
use rand::{thread_rng, Rng};
use std::collections::hash_map::Entry;
use std::collections::HashMap;
use std::fmt;
use std::fs;
use std::fs::File;
use std::io;
use std::io::Write;
use std::ops::Deref;
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};
use std::sync::mpsc::{SyncSender, Receiver, sync_channel};
use std::str::FromStr;

pub(crate) enum HTLCStatus {
	Pending,
	Succeeded,
	Failed,
}

pub(crate) struct MillisatAmount(Option<u64>);

impl fmt::Display for MillisatAmount {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		match self.0 {
			Some(amt) => write!(f, "{}", amt),
			None => write!(f, "unknown"),
		}
	}
}

pub(crate) struct PaymentInfo {
	preimage: Option<PaymentPreimage>,
	secret: Option<PaymentSecret>,
	status: HTLCStatus,
	amt_msat: MillisatAmount,
}

pub(crate) type PaymentInfoStorage = Arc<Mutex<HashMap<PaymentHash, PaymentInfo>>>;

type ChainMonitor = chainmonitor::ChainMonitor<
	InMemorySigner,
	Arc<dyn Filter + Send + Sync>,
	Arc<BitcoindClient>,
	Arc<BitcoindClient>,
	Arc<FilesystemLogger>,
	Arc<FilesystemPersister>,
>;

pub(crate) type PeerManager = SimpleArcPeerManager<
	SocketDescriptor,
	ChainMonitor,
	BitcoindClient,
	BitcoindClient,
	dyn chain::Access + Send + Sync,
	FilesystemLogger,
>;

pub(crate) type ChannelManager =
	SimpleArcChannelManager<ChainMonitor, BitcoindClient, BitcoindClient, FilesystemLogger>;

pub(crate) type InvoicePayer<E> = payment::InvoicePayer<
	Arc<ChannelManager>,
	Router,
	Arc<Mutex<ProbabilisticScorer<Arc<NetworkGraph>>>>,
	Arc<FilesystemLogger>,
	E,
>;

type Router = DefaultRouter<Arc<NetworkGraph>, Arc<FilesystemLogger>>;

struct DataPersister {
	data_dir: String,
}

impl
	Persister<
		InMemorySigner,
		Arc<ChainMonitor>,
		Arc<BitcoindClient>,
		Arc<KeysManager>,
		Arc<BitcoindClient>,
		Arc<FilesystemLogger>,
	> for DataPersister
{
	fn persist_manager(&self, channel_manager: &ChannelManager) -> Result<(), std::io::Error> {
		FilesystemPersister::persist_manager(self.data_dir.clone(), channel_manager)
	}

	fn persist_graph(&self, network_graph: &NetworkGraph) -> Result<(), std::io::Error> {
		if FilesystemPersister::persist_network_graph(self.data_dir.clone(), network_graph).is_err()
		{
			// Persistence errors here are non-fatal as we can just fetch the routing graph
			// again later, but they may indicate a disk error which could be fatal elsewhere.
			eprintln!("Warning: Failed to persist network graph, check your disk and permissions");
		}

		Ok(())
	}
}

async fn handle_ldk_events(
	channel_manager: Arc<ChannelManager>, bitcoind_client: Arc<BitcoindClient>,
	keys_manager: Arc<KeysManager>, inbound_payments: PaymentInfoStorage,
	outbound_payments: PaymentInfoStorage, network: Network, event: &Event,
) {
	match event {
		Event::FundingGenerationReady {
			temporary_channel_id,
			channel_value_satoshis,
			output_script,
			..
		} => {
			// Construct the raw transaction with one output, that is paid the amount of the
			// channel.
			let addr = WitnessProgram::from_scriptpubkey(
				&output_script[..],
				match network {
					Network::Bitcoin => bitcoin_bech32::constants::Network::Bitcoin,
					Network::Testnet => bitcoin_bech32::constants::Network::Testnet,
					Network::Regtest => bitcoin_bech32::constants::Network::Regtest,
					Network::Signet => bitcoin_bech32::constants::Network::Signet,
				},
			)
			.expect("Lightning funding tx should always be to a SegWit output")
			.to_address();
			let mut outputs = vec![HashMap::with_capacity(1)];
			outputs[0].insert(addr, *channel_value_satoshis as f64 / 100_000_000.0);
			let raw_tx = bitcoind_client.create_raw_transaction(outputs).await;

			// Have your wallet put the inputs into the transaction such that the output is
			// satisfied.
			let funded_tx = bitcoind_client.fund_raw_transaction(raw_tx).await;

			// Sign the final funding transaction and broadcast it.
			let signed_tx = bitcoind_client.sign_raw_transaction_with_wallet(funded_tx.hex).await;
			assert_eq!(signed_tx.complete, true);
			let final_tx: Transaction =
				encode::deserialize(&hex_utils::to_vec(&signed_tx.hex).unwrap()).unwrap();
			// Give the funding transaction back to LDK for opening the channel.
			if channel_manager
				.funding_transaction_generated(&temporary_channel_id, final_tx)
				.is_err()
			{
				println!(
					"\nERROR: Channel went away before we could fund it. The peer disconnected or refused the channel.");
				print!("> ");
				io::stdout().flush().unwrap();
			}
		}
		Event::PaymentReceived { payment_hash, purpose, amt, .. } => {
			let mut payments = inbound_payments.lock().unwrap();
			let (payment_preimage, payment_secret) = match purpose {
				PaymentPurpose::InvoicePayment { payment_preimage, payment_secret, .. } => {
					(*payment_preimage, Some(*payment_secret))
				}
				PaymentPurpose::SpontaneousPayment(preimage) => (Some(*preimage), None),
			};
			let status = match channel_manager.claim_funds(payment_preimage.unwrap()) {
				true => {
					println!(
						"\nEVENT: received payment from payment hash {} of {} millisatoshis",
						hex_utils::hex_str(&payment_hash.0),
						amt
					);
					print!("> ");
					io::stdout().flush().unwrap();
					HTLCStatus::Succeeded
				}
				_ => HTLCStatus::Failed,
			};
			match payments.entry(*payment_hash) {
				Entry::Occupied(mut e) => {
					let payment = e.get_mut();
					payment.status = status;
					payment.preimage = payment_preimage;
					payment.secret = payment_secret;
				}
				Entry::Vacant(e) => {
					e.insert(PaymentInfo {
						preimage: payment_preimage,
						secret: payment_secret,
						status,
						amt_msat: MillisatAmount(Some(*amt)),
					});
				}
			}
		}
		Event::PaymentSent { payment_preimage, payment_hash, fee_paid_msat, .. } => {
			let mut payments = outbound_payments.lock().unwrap();
			for (hash, payment) in payments.iter_mut() {
				if *hash == *payment_hash {
					payment.preimage = Some(*payment_preimage);
					payment.status = HTLCStatus::Succeeded;
					println!(
						"\nEVENT: successfully sent payment of {} millisatoshis{} from \
								 payment hash {:?} with preimage {:?}",
						payment.amt_msat,
						if let Some(fee) = fee_paid_msat {
							format!(" (fee {} msat)", fee)
						} else {
							"".to_string()
						},
						hex_utils::hex_str(&payment_hash.0),
						hex_utils::hex_str(&payment_preimage.0)
					);
					print!("> ");
					io::stdout().flush().unwrap();
				}
			}
		}
		Event::OpenChannelRequest { .. } => {
			// Unreachable, we don't set manually_accept_inbound_channels
		}
		Event::PaymentPathSuccessful { .. } => {}
		Event::PaymentPathFailed { .. } => {}
		Event::PaymentFailed { payment_hash, .. } => {
			print!(
				"\nEVENT: Failed to send payment to payment hash {:?}: exhausted payment retry attempts",
				hex_utils::hex_str(&payment_hash.0)
			);
			print!("> ");
			io::stdout().flush().unwrap();

			let mut payments = outbound_payments.lock().unwrap();
			if payments.contains_key(&payment_hash) {
				let payment = payments.get_mut(&payment_hash).unwrap();
				payment.status = HTLCStatus::Failed;
			}
		}
		Event::PaymentForwarded { fee_earned_msat, claim_from_onchain_tx } => {
			let from_onchain_str = if *claim_from_onchain_tx {
				"from onchain downstream claim"
			} else {
				"from HTLC fulfill message"
			};
			if let Some(fee_earned) = fee_earned_msat {
				println!(
					"\nEVENT: Forwarded payment, earning {} msat {}",
					fee_earned, from_onchain_str
				);
			} else {
				println!("\nEVENT: Forwarded payment, claiming onchain {}", from_onchain_str);
			}
			print!("> ");
			io::stdout().flush().unwrap();
		}
		Event::PendingHTLCsForwardable { time_forwardable } => {
			let forwarding_channel_manager = channel_manager.clone();
			let min = time_forwardable.as_millis() as u64;
			tokio::spawn(async move {
				let millis_to_sleep = thread_rng().gen_range(min, min * 5) as u64;
				tokio::time::sleep(Duration::from_millis(millis_to_sleep)).await;
				forwarding_channel_manager.process_pending_htlc_forwards();
			});
		}
		Event::SpendableOutputs { outputs } => {
			let destination_address = bitcoind_client.get_new_address().await;
			let output_descriptors = &outputs.iter().map(|a| a).collect::<Vec<_>>();
			let tx_feerate =
				bitcoind_client.get_est_sat_per_1000_weight(ConfirmationTarget::Normal);
			let spending_tx = keys_manager
				.spend_spendable_outputs(
					output_descriptors,
					Vec::new(),
					destination_address.script_pubkey(),
					tx_feerate,
					&Secp256k1::new(),
				)
				.unwrap();
			bitcoind_client.broadcast_transaction(&spending_tx);
		}
		Event::ChannelClosed { channel_id, reason, user_channel_id: _ } => {
			println!(
				"\nEVENT: Channel {} closed due to: {:?}",
				hex_utils::hex_str(channel_id),
				reason
			);
			print!("> ");
			io::stdout().flush().unwrap();
		}
		Event::DiscardFunding { .. } => {
			// A "real" node should probably "lock" the UTXOs spent in funding transactions until
			// the funding transaction either confirms, or this event is generated.
		}
	}
}

#[derive(Debug)]
pub enum Message {
	Request(String),
	Error(String),
	Success(String),
    Exit(String),
}


use lightning::util::events::EventHandler;


pub async fn start_ldk(
    rpc_info: String,
    ldk_storage_path: String,
    port: u16,
    network: String,
    node_name: String,
    address: String,
    mnemonic_key_phrase: String,
	ffi_sender: tokio::sync::mpsc::Sender<Message>,
	ldk_receiver: Arc<tokio::sync::Mutex<tokio::sync::mpsc::Receiver<Message>>>,
    callback: Box<dyn Fn(&str) + Send + Sync>
) {
    callback("...starting ldk");

    // setup args
	let args: cli::LdkUserInfo = cli::setup_ldkuserinfo(
		rpc_info.clone(),
		ldk_storage_path.clone(),
		port,
		network.clone(),
        node_name.clone(),
		address.clone()
	).unwrap();

    callback(format!("{:?}", args).as_str());

	// Initialize the LDK data directory if necessary.
	let ldk_data_dir = format!("{}/.ldk", args.ldk_storage_dir_path);
	fs::create_dir_all(ldk_data_dir.clone()).unwrap();

    callback("Initialize the LDK data directory if necessary.");

	// Initialize our bitcoind client.
	let bitcoind_client = match BitcoindClient::new(
		args.bitcoind_rpc_host.clone(),
		args.bitcoind_rpc_port,
		args.bitcoind_rpc_username.clone(),
		args.bitcoind_rpc_password.clone(),
		tokio::runtime::Handle::current(),
	)
	.await
	{
		Ok(client) => Arc::new(client),
		Err(e) => {
			let msg = format!("Failed to connect to bitcoind client: {}", e);
            callback(msg.as_str());
			ffi_sender.send(Message::Error(msg)).await.unwrap();
			return;
		}
	};

    callback("Initialize our bitcoind client.");

	// Check that the bitcoind we've connected to is running the network we expect
	let bitcoind_chain = bitcoind_client.get_blockchain_info().await.chain;
	if bitcoind_chain
		!= match args.network {
			bitcoin::Network::Bitcoin => "main",
			bitcoin::Network::Testnet => "test",
			bitcoin::Network::Regtest => "regtest",
			bitcoin::Network::Signet => "signet",
		} {
		let msg = format!(
			"Chain argument ({}) didn't match bitcoind chain ({})",
			args.network, bitcoind_chain
		);
        callback(msg.as_str());
		ffi_sender.send(Message::Error(msg)).await.unwrap();
		return;
	}

    callback("Check that the bitcoind we've connected to is running the network we expect");

	// ## Setup
	// Step 1: Initialize the FeeEstimator

	// BitcoindClient implements the FeeEstimator trait, so it'll act as our fee estimator.
	let fee_estimator = bitcoind_client.clone();

    callback("Step 1: Initialize the FeeEstimator");

	// Step 2: Initialize the Logger
	let logger = Arc::new(FilesystemLogger::new(ldk_data_dir.clone()));

    callback("Step 2: Initialize the Logger");
	// log_trace!(logger, "...testing log_trace");
	// lightning::util::log_trace!(logger, "Latest block {} at height {} removed via block_disconnected", header.block_hash(), height);

	// Step 3: Initialize the BroadcasterInterface

	// BitcoindClient implements the BroadcasterInterface trait, so it'll act as our transaction
	// broadcaster.
	let broadcaster = bitcoind_client.clone();

    callback("Step 3: Initialize the BroadcasterInterface");

	// Step 4: Initialize Persist
	let persister = Arc::new(FilesystemPersister::new(ldk_data_dir.clone()));

    callback("Step 4: Initialize Persist");

	// Step 5: Initialize the ChainMonitor
	let chain_monitor: Arc<ChainMonitor> = Arc::new(chainmonitor::ChainMonitor::new(
		None,
		broadcaster.clone(),
		logger.clone(),
		fee_estimator.clone(),
		persister.clone(),
	));

    callback("Step 5: Initialize the ChainMonitor");

	// Step 6: Initialize the KeysManager

	// The key seed that we use to derive the node privkey (that corresponds to the node pubkey) and
	// other secret key material.
	let keys_seed_path = format!("{}/keys_seed", ldk_data_dir.clone());
	let keys_seed = if let Ok(seed) = fs::read(keys_seed_path.clone()) {
		assert_eq!(seed.len(), 32);
		let mut key = [0; 32];
		key.copy_from_slice(&seed);
		key
	} else {
		let mut key = [0; 32];
		thread_rng().fill_bytes(&mut key);
		match File::create(keys_seed_path.clone()) {
			Ok(mut f) => {
				f.write_all(&key).expect("Failed to write node keys seed to disk");
				f.sync_all().expect("Failed to sync node keys seed to disk");
			}
			Err(e) => {
				let msg = format!("ERROR: Unable to create keys seed file {}: {}", keys_seed_path, e);
				callback(msg.as_str());
                ffi_sender.send(Message::Error(msg)).await.unwrap();
				return;
			}
		}
		key
	};
	let cur = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap();
	let keys_manager = Arc::new(KeysManager::new(&keys_seed, cur.as_secs(), cur.subsec_nanos()));

    callback("Step 6: Initialize the KeysManager");

	// Step 7: Read ChannelMonitor state from disk
	let mut channelmonitors = persister.read_channelmonitors(keys_manager.clone()).unwrap();

    callback("Step 7: Read ChannelMonitor state from disk");

	// Step 8: Initialize the ChannelManager
	let mut user_config = UserConfig::default();
	user_config.peer_channel_config_limits.force_announced_channel_preference = false;
	let mut restarting_node = true;
	let (channel_manager_blockhash, channel_manager) = {
		if let Ok(mut f) = fs::File::open(format!("{}/manager", ldk_data_dir.clone())) {
			let mut channel_monitor_mut_references = Vec::new();
			for (_, channel_monitor) in channelmonitors.iter_mut() {
				channel_monitor_mut_references.push(channel_monitor);
			}
			let read_args = ChannelManagerReadArgs::new(
				keys_manager.clone(),
				fee_estimator.clone(),
				chain_monitor.clone(),
				broadcaster.clone(),
				logger.clone(),
				user_config,
				channel_monitor_mut_references,
			);
			<(BlockHash, ChannelManager)>::read(&mut f, read_args).unwrap()
		} else {
			// We're starting a fresh node.
			restarting_node = false;
			let getinfo_resp = bitcoind_client.get_blockchain_info().await;

			let chain_params = ChainParameters {
				network: args.network,
				best_block: BestBlock::new(
					getinfo_resp.latest_blockhash,
					getinfo_resp.latest_height as u32,
				),
			};
			let fresh_channel_manager = channelmanager::ChannelManager::new(
				fee_estimator.clone(),
				chain_monitor.clone(),
				broadcaster.clone(),
				logger.clone(),
				keys_manager.clone(),
				user_config,
				chain_params,
			);
			(getinfo_resp.latest_blockhash, fresh_channel_manager)
		}
	};

    callback("Step 8: Initialize the ChannelManager");

	// Step 9: Sync ChannelMonitors and ChannelManager to chain tip
	let mut chain_listener_channel_monitors = Vec::new();
	let mut cache = UnboundedCache::new();
	let mut chain_tip: Option<poll::ValidatedBlockHeader> = None;
	if restarting_node {
		let mut chain_listeners =
			vec![(channel_manager_blockhash, &channel_manager as &dyn chain::Listen)];

		for (blockhash, channel_monitor) in channelmonitors.drain(..) {
			let outpoint = channel_monitor.get_funding_txo().0;
			chain_listener_channel_monitors.push((
				blockhash,
				(channel_monitor, broadcaster.clone(), fee_estimator.clone(), logger.clone()),
				outpoint,
			));
		}

		for monitor_listener_info in chain_listener_channel_monitors.iter_mut() {
			chain_listeners
				.push((monitor_listener_info.0, &monitor_listener_info.1 as &dyn chain::Listen));
		}
		chain_tip = Some(
			init::synchronize_listeners(
				&mut bitcoind_client.deref(),
				args.network,
				&mut cache,
				chain_listeners,
			)
			.await
			.unwrap(),
		);
	}

    callback("Step 9: Sync ChannelMonitors and ChannelManager to chain tip");

	// Step 10: Give ChannelMonitors to ChainMonitor
	for item in chain_listener_channel_monitors.drain(..) {
		let channel_monitor = item.1 .0;
		let funding_outpoint = item.2;
		chain_monitor.watch_channel(funding_outpoint, channel_monitor).unwrap();
	}

    callback("Step 10: Give ChannelMonitors to ChainMonitor");

	// Step 11: Optional: Initialize the NetGraphMsgHandler
	let genesis = genesis_block(args.network).header.block_hash();
	let network_graph_path = format!("{}/network_graph", ldk_data_dir.clone());
	let network_graph = Arc::new(disk::read_network(Path::new(&network_graph_path), genesis));
	let network_gossip = Arc::new(NetGraphMsgHandler::new(
		Arc::clone(&network_graph),
		None::<Arc<dyn chain::Access + Send + Sync>>,
		logger.clone(),
	));

    callback("Step 11: Optional: Initialize the NetGraphMsgHandler");

	// Step 12: Initialize the PeerManager
	let channel_manager: Arc<ChannelManager> = Arc::new(channel_manager);
	let mut ephemeral_bytes = [0; 32];
	rand::thread_rng().fill_bytes(&mut ephemeral_bytes);
	let lightning_msg_handler = MessageHandler {
		chan_handler: channel_manager.clone(),
		route_handler: network_gossip.clone(),
	};
	let peer_manager: Arc<PeerManager> = Arc::new(PeerManager::new(
		lightning_msg_handler,
		keys_manager.get_node_secret(Recipient::Node).unwrap(),
		&ephemeral_bytes,
		logger.clone(),
		Arc::new(IgnoringMessageHandler {}),
	));

    callback("Step 12: Initialize the PeerManager");

	// ## Running LDK
	// Step 13: Initialize networking

	let peer_manager_connection_handler = peer_manager.clone();
	let listening_port = args.ldk_peer_listening_port;
	let stop_listen_connect = Arc::new(AtomicBool::new(false));
	let stop_listen = Arc::clone(&stop_listen_connect);
	tokio::spawn(async move {
		let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", listening_port))
			.await
			.expect("Failed to bind to listen port - is something else already listening on it?");
		loop {
			let peer_mgr = peer_manager_connection_handler.clone();
			let tcp_stream = listener.accept().await.unwrap().0;
			if stop_listen.load(Ordering::Acquire) {
				return;
			}
			tokio::spawn(async move {
				lightning_net_tokio::setup_inbound(
					peer_mgr.clone(),
					tcp_stream.into_std().unwrap(),
				)
				.await;
			});
		}
	});

    callback("Step 13: Initialize networking");

	// Step 14: Connect and Disconnect Blocks
	if chain_tip.is_none() {
		chain_tip =
			Some(init::validate_best_block_header(&mut bitcoind_client.deref()).await.unwrap());
	}
	let channel_manager_listener = channel_manager.clone();
	let chain_monitor_listener = chain_monitor.clone();
	let bitcoind_block_source = bitcoind_client.clone();
	let network = args.network;
	tokio::spawn(async move {
		let mut derefed = bitcoind_block_source.deref();
		let chain_poller = poll::ChainPoller::new(&mut derefed, network);
		let chain_listener = (chain_monitor_listener, channel_manager_listener);
		let mut spv_client =
			SpvClient::new(chain_tip.unwrap(), chain_poller, &mut cache, &chain_listener);
		loop {
			spv_client.poll_best_tip().await.unwrap();
			tokio::time::sleep(Duration::from_secs(1)).await;
		}
	});

    callback("Step 14: Connect and Disconnect Blocks");

	// Step 15: Handle LDK Events
	let channel_manager_event_listener = channel_manager.clone();
	let keys_manager_listener = keys_manager.clone();
	// TODO: persist payment info to disk
	let inbound_payments: PaymentInfoStorage = Arc::new(Mutex::new(HashMap::new()));
	let outbound_payments: PaymentInfoStorage = Arc::new(Mutex::new(HashMap::new()));
	let inbound_pmts_for_events = inbound_payments.clone();
	let outbound_pmts_for_events = outbound_payments.clone();
	let network = args.network;
	let bitcoind_rpc = bitcoind_client.clone();
	let handle = tokio::runtime::Handle::current();
	let event_handler = move |event: &Event| {
		handle.block_on(handle_ldk_events(
			channel_manager_event_listener.clone(),
			bitcoind_rpc.clone(),
			keys_manager_listener.clone(),
			inbound_pmts_for_events.clone(),
			outbound_pmts_for_events.clone(),
			network,
			event,
		));
	};

    callback("Step 15: Handle LDK Events");

	// Step 16: Initialize routing ProbabilisticScorer
	let scorer_path = format!("{}/prob_scorer", ldk_data_dir.clone());
	let scorer = Arc::new(Mutex::new(disk::read_scorer(
		Path::new(&scorer_path),
		Arc::clone(&network_graph),
	)));
	let scorer_persist = Arc::clone(&scorer);
	tokio::spawn(async move {
		let mut interval = tokio::time::interval(Duration::from_secs(600));
		loop {
			interval.tick().await;
			if disk::persist_scorer(Path::new(&scorer_path), &scorer_persist.lock().unwrap())
				.is_err()
			{
				// Persistence errors here are non-fatal as channels will be re-scored as payments
				// fail, but they may indicate a disk error which could be fatal elsewhere.
				eprintln!("Warning: Failed to persist scorer, check your disk and permissions");
			}
		}
	});

    callback("Step 16: Initialize routing ProbabilisticScorer");

	// Step 17: Create InvoicePayer
	let router = DefaultRouter::new(
		network_graph.clone(),
		logger.clone(),
		keys_manager.get_secure_random_bytes(),
	);
	let invoice_payer = Arc::new(InvoicePayer::new(
		channel_manager.clone(),
		router,
		scorer.clone(),
		logger.clone(),
		event_handler,
		payment::RetryAttempts(5),
	));

    callback("Step 17: Create InvoicePayer");

	// Step 18: Persist ChannelManager and NetworkGraph
	let persister = DataPersister { data_dir: ldk_data_dir.clone() };

    callback("Step 18: Persist ChannelManager and NetworkGraph");

	// Step 19: Background Processing
	let background_processor = BackgroundProcessor::start(
		persister,
		invoice_payer.clone(),
		chain_monitor.clone(),
		channel_manager.clone(),
		Some(network_gossip.clone()),
		peer_manager.clone(),
		logger.clone(),
	);

    callback("Step 19: Background Processing");

	// Regularly reconnect to channel peers.
	let connect_cm = Arc::clone(&channel_manager);
	let connect_pm = Arc::clone(&peer_manager);
	let peer_data_path = format!("{}/channel_peer_data", ldk_data_dir.clone());
	let stop_connect = Arc::clone(&stop_listen_connect);
	tokio::spawn(async move {
		let mut interval = tokio::time::interval(Duration::from_secs(1));
		loop {
			interval.tick().await;
			match disk::read_channel_peer_data(Path::new(&peer_data_path)) {
				Ok(info) => {
					let peers = connect_pm.get_peer_node_ids();
					for node_id in connect_cm
						.list_channels()
						.iter()
						.map(|chan| chan.counterparty.node_id)
						.filter(|id| !peers.contains(id))
					{
						if stop_connect.load(Ordering::Acquire) {
							return;
						}
						for (pubkey, peer_addr) in info.iter() {
							if *pubkey == node_id {
								let _ = cli::do_connect_peer(
									*pubkey,
									peer_addr.clone(),
									Arc::clone(&connect_pm),
								)
								.await;
							}
						}
					}
				}
				Err(e) => println!("ERROR: errored reading channel peer info from disk: {:?}", e),
			}
		}
	});

    callback("Regularly reconnect to channel peers.");

	// Regularly broadcast our node_announcement. This is only required (or possible) if we have
	// some public channels, and is only useful if we have public listen address(es) to announce.
	// In a production environment, this should occur only after the announcement of new channels
	// to avoid churn in the global network graph.
	let chan_manager = Arc::clone(&channel_manager);
	let network = args.network;
	if !args.ldk_announced_listen_addr.is_empty() {
		tokio::spawn(async move {
			let mut interval = tokio::time::interval(Duration::from_secs(60));
			loop {
				interval.tick().await;
				chan_manager.broadcast_node_announcement(
					[0; 3],
					args.ldk_announced_node_name,
					args.ldk_announced_listen_addr.clone(),
				);
			}
		});
	}

    callback("Regularly broadcast our node_announcement.");

    callback("Ready to receive messages from ldk channel");

	while let Some(message) = ldk_receiver.lock().await.recv().await {

		match message {
			Message::Request(msg) => {
				callback(format!("Request to ldk: {}", msg).as_str());

				let mut words = msg.split_whitespace();

				let res:String;
				if let Some(word) = words.next() {
					match word {
						"nodeinfo" => {
							res = flutter_ffi::node_info(&channel_manager, &peer_manager);
						},
            "listchannels" => {
                // list_channels(&channel_manager, &network_graph)
                res = format!("{{ \"channels\": [] }}");
            },
			"connectpeer" => {
				let peer_pubkey_and_ip_addr = words.next();
				if peer_pubkey_and_ip_addr.is_none() {
					ffi_sender.send(Message::Error("ERROR: connectpeer requires peer connection info: `connectpeer pubkey@host:port`".to_string())).await.unwrap();
					continue;
				}

				let (pubkey, peer_addr) =
					match flutter_ffi::parse_peer_info(peer_pubkey_and_ip_addr.unwrap().to_string()) {
						Ok(info) => info,
						Err(e) => {
							println!("{:?}", e.into_inner().unwrap());
							continue;
						}
					};
				
				callback("cli::connect_peer_if_necessary");
				if flutter_ffi::connect_peer_if_necessary(pubkey, peer_addr, peer_manager.clone(), &callback)
					.await
					.is_ok()
				{
					res = format!("SUCCESS: connected to peer {}", pubkey);
				}
				else {
					res = format!("couldn't connect to peer :(");
				}
			},
            "listpeers" => {
                res = flutter_ffi::list_peers(peer_manager.clone());
            },
            "openchannel" => {
                let peer_pubkey_and_ip_addr = words.next();
                let channel_value_sat = words.next();
                res = format!("a channel for {} was created for {} sats", peer_pubkey_and_ip_addr.unwrap(), channel_value_sat.unwrap());
            },
            "closechannel" => {
                let channel_id_str = words.next();
                res = format!("channel: {} was closed", channel_id_str.unwrap());
            },
            "getinvoice" => {
                let amt_str = words.next();
                if amt_str.is_none() {
                    res = format!("ERROR: getinvoice requires an amount in millisatoshis");
                }
                else {
                    let amt_msat: Result<u64, _> = amt_str.unwrap().parse();
                    if amt_msat.is_err() {
                        res = format!("ERROR: getinvoice provided payment amount was not a number");
                    }
                    else {
                        // get_invoice(
                        //     amt_msat.unwrap(),
                        //     inbound_payments.clone(),
                        //     channel_manager.clone(),
                        //     keys_manager.clone(),
                        //     network,
                        // );
                        res = "lnbc20m1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqhp58yjmdan79s6qqdhdzgynm4zwqd5d7xmw5fk98klysy043l2ahrqsfpp3qjmp7lwpagxun9pygexvgpjdc4jdj85fr9yq20q82gphp2nflc7jtzrcazrra7wwgzxqc8u7754cdlpfrmccae92qgzqvzq2ps8pqqqqqqpqqqqq9qqqvpeuqafqxu92d8lr6fvg0r5gv0heeeqgcrqlnm6jhphu9y00rrhy4grqszsvpcgpy9qqqqqqgqqqqq7qqzqj9n4evl6mr5aj9f58zp6fyjzup6ywn3x6sk8akg5v4tgn2q8g4fhx05wf6juaxu9760yp46454gpg5mtzgerlzezqcqvjnhjh8z3g2qqdhhwkj".to_string();
                    }
                }
            },
            "sendpayment" => {
                let invoice_str = words.next();
                if invoice_str.is_none() {
                    res = format!("ERROR: sendpayment requires an invoice: `sendpayment <invoice>`");
                }
                else {
                    // let invoice = match Invoice::from_str(invoice_str.unwrap()) {
                    //     Ok(invoice) => {
                    //         send_payment(&*invoice_payer, &invoice, outbound_payments.clone());
                    //     },
                    //     Err(e) => {
                    //         res = format!("ERROR: invalid invoice: {:?}", e);
                    //     }
                    // };
                    res = format!("invoice: {} was paid", invoice_str.unwrap())

                }

            },
						_ => {
							res = msg.clone(); 
						}
					}
				}
				else {
					res = "could not parse message".to_string();
				}

				callback(format!("ldk_recv: Success => {}", msg).as_str());
				ffi_sender.send(Message::Success(res)).await.unwrap();
			},
      Message::Exit(msg) => {
          // Disconnect our peers and stop accepting new connections. This ensures we don't continue
          // updating our channel data after we've stopped the background processor.
          stop_listen_connect.store(true, Ordering::Release);
          peer_manager.disconnect_all_peers();

          //Stop the background processor.
          background_processor.stop().unwrap();

          callback(format!("ldk_recv: Exit => {}",msg).as_str());
          ffi_sender.send(Message::Exit(msg)).await.unwrap();
          break;
      },
			_ => ()
		};
	}

		

}


#[cfg(test)]
mod tests {
    use futures::channel::oneshot::Receiver;

    use super::start_ldk;
    use super::Message;
	use std::sync::mpsc::{SyncSender, sync_channel};
    use tokio::runtime::Builder;
    use std::sync::Arc;

	#[test]
	fn test_start_ldk(){
        let runtime = Builder::new_multi_thread()
            .enable_all()
            .worker_threads(3)
            .thread_name("flutterrust")
            .thread_stack_size(8 * 1024 * 1024)
            .build()
            .unwrap();
        
        runtime.block_on(async move {

            let (ldk_send, ldk_recv) : (tokio::sync::mpsc::Sender<Message>, tokio::sync::mpsc::Receiver<Message>) = tokio::sync::mpsc::channel(10);

            let (ffi_send, mut ffi_recv) : (tokio::sync::mpsc::Sender<Message>, tokio::sync::mpsc::Receiver<Message>) = tokio::sync::mpsc::channel(10);

            ldk_send.send(Message::Request("test request".to_string())).await.unwrap();
            ldk_send.send(Message::Request("connectpeer 038f07ba15d065b96efc5cb708e9847f72cb9138871a15e5e4097f15a6a74a914a@192.168.0.13:9735".to_string())).await.unwrap();
            ldk_send.send(Message::Exit("exit from test_start_ldk".to_string())).await.unwrap();

            start_ldk(
                "polaruser:polarpass@192.168.0.13:18443".to_string(),
                "./".to_string(),
                9732,
                "regtest".to_string(),
                "hellolighting".to_string(),
                "0.0.0.0".to_string(),
                "mnemonic_key_phrase".to_string(),
				ffi_send,
                Arc::new(tokio::sync::Mutex::new(ldk_recv)),
                Box::new(|msg| { println!("{}",msg)})
            ).await;

            while let Some(res) = ffi_recv.recv().await {
                match res {
                    Message::Success(_) => {
                        println!("ffi_recv: {:?}",res);
                    },
                    Message::Exit(_) => {
                        println!("ffi_recv: {:?}",res);
                        break;
                    },
                    _ => ()
                }
            }
        });
	}

}
