#![allow(unused_imports)]
#![allow(unused_variables)]
#![allow(unused_macros)]

/// this is the code that creates an interface to the flutter ffi.

// standard libary
use std::os::raw::c_char;
use std::ffi::{CString, CStr};
use std::env;
use std::fs;
use std::path::Path;
use std::fs::File;
use std::io::prelude::*;
use std::io;
use std::sync::{mpsc, Arc, Mutex};
use std::sync::mpsc::{Sender, SyncSender, Receiver, sync_channel};
// use std::sync::Mutex;
use std::thread;


// packages.
// use tokio::sync::Mutex;
use tokio::runtime::{Builder, Runtime};
use lazy_static::lazy_static;
use allo_isolate::Isolate;

// code in workspace.
// use ldk_lib::cli::{ LdkUserInfo, setup_ldkuserinfo};

// Create runtime for tokio in the static scope 
lazy_static! {
    static ref RUNTIME: io::Result<Runtime> = Builder::new_multi_thread()
        .worker_threads(4)
        .thread_name("flutterrust")
        .thread_stack_size(3 * 1024 * 1024)
        .build();
}

// Get reference to runtime in static scope
macro_rules! runtime {
    () => {
        RUNTIME.as_ref().unwrap()
    };
}

// Create channels on the static scope.
lazy_static! {
	static ref LDK_CHANNEL: (tokio::sync::mpsc::Sender<ldk_lib::Message>, Arc<tokio::sync::Mutex<tokio::sync::mpsc::Receiver<ldk_lib::Message>>> ) = {
		let (send, recv) = tokio::sync::mpsc::channel(1);
		(send, Arc::new(tokio::sync::Mutex::new(recv)))
	};
	static ref FFI_CHANNEL: (tokio::sync::mpsc::Sender<ldk_lib::Message>, Arc<tokio::sync::Mutex<tokio::sync::mpsc::Receiver<ldk_lib::Message>>> ) = {
		let (send, recv) = tokio::sync::mpsc::channel(1);
		(send, Arc::new(tokio::sync::Mutex::new(recv)))
	};
}

// Get references to channels on the static scope.
macro_rules! channel {
    (ldk) => {
	    (&(*LDK_CHANNEL).0, &(*LDK_CHANNEL).1)
    };
    (ffi) => {
	    (&(*FFI_CHANNEL).0, &(*FFI_CHANNEL).1)
    };
}

// get senders for static channels
macro_rules! sender {
    (ldk) => {
	    (*LDK_CHANNEL).0.clone()
    };
    (ffi) => {
	    (*FFI_CHANNEL).0.clone()
    };
}

// get receivers for static channels
macro_rules! receiver {
    (ldk) => {
	    (*LDK_CHANNEL).1.clone()
    };
    (ffi) => {
	    (*FFI_CHANNEL).1.clone()
    };
}

#[allow(unused_macros)]
macro_rules! error {
    ($result:expr) => {
        error!($result, 0);
    };
    ($result:expr, $error:expr) => {
        match $result {
            Ok(value) => value,
            Err(e) => {
                ffi_helpers::update_last_error(e);
                return $error;
            }
        }
    };
}

#[allow(unused_macros)]
macro_rules! cstr {
    ($ptr:expr) => {
        cstr!($ptr, 0);
    };
    ($ptr:expr, $error:expr) => {{
        null_pointer_check!($ptr);
        error!(unsafe { CStr::from_ptr($ptr).to_str() }, $error)
    }};
}

/// Convert c_char to String.
pub fn c_char_to_string(arg: *const c_char) -> String {
    let c_str: &CStr = unsafe { CStr::from_ptr(arg) };
    let str_slice: &str = c_str.to_str().unwrap();
    str_slice.to_string()
}


#[no_mangle]
pub unsafe extern "C" fn last_error_length() -> i32 {
    ffi_helpers::error_handling::last_error_length()
}

#[no_mangle]
pub unsafe extern "C" fn error_message_utf8(buf: *mut c_char, length: i32) -> i32 {
    ffi_helpers::error_handling::error_message_utf8(buf, length)
}

#[no_mangle]
pub extern "C" fn start_ldk(
    rpc_info: *const c_char,
    ldk_storage_path: *const c_char,
    port: u16,
    network: *const c_char,
    node_name: *const c_char,
    address: *const c_char,
    mnemonic_key_phrase: *const c_char,
    func: unsafe extern "C" fn(*mut c_char)
) -> *mut c_char  {

    // let callback = move |msg| {
    //     unsafe {
    //         func(CString::new(msg).unwrap().into_raw());
    //     }
    // };

    let rt = runtime!(); 
    let ffi_receiver = receiver!(ffi);

    let success = Arc::new(tokio::sync::Mutex::new(String::new()));
    let _success = success.clone();
    let res = rt.block_on(async move {
        let ffi_sender = sender!(ffi);
        let ldk_receiver = receiver!(ldk);
        let res = ldk_lib::start_ldk(
            c_char_to_string(rpc_info),
            c_char_to_string(ldk_storage_path),
            port,
            c_char_to_string(network),
            c_char_to_string(node_name),
            c_char_to_string(address),
            c_char_to_string(mnemonic_key_phrase),
            ffi_sender,
            ldk_receiver.clone(),
            Box::new(move |msg| { 
            unsafe {
                func(CString::new(msg).unwrap().into_raw());
            }
        })).await;

        if let Some(ldk_lib::Message::Success(res)) = ffi_receiver.lock().await.recv().await {
            return res;
        }
        else {
            return "error with ldk".to_string();
        }
    });

    CString::new(res).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn send_message(
    msg: *const c_char,
    isolate_port: i64 
) -> i32 {
    let sender = sender!(ldk);
    let receiver = receiver!(ffi);
    
    let rt = runtime!(); 
    let _msg = c_char_to_string(msg);
    let res = rt.spawn(async move {
        let isolate = Isolate::new(isolate_port);

        sender.send(ldk_lib::Message::Request(_msg)).await.unwrap();

        if let Some(ldk_lib::Message::Success(res)) = receiver.lock().await.recv().await {
            isolate.post(res);
        }
        else {
            isolate.post("problem with ldk".to_string());
        }
    });
    
    1
}


// // /// Run LDK asynchronous 
// // #[no_mangle]
// // pub extern "C" fn test_ldk_async(
// //     isolate_port: i64, 
// //     rpc_info: *const c_char,
// //     ldk_storage_path: *const c_char,
// // ) -> i32 {
// //     let rt = runtime!();

// // 	let ldk_userinfo: LdkUserInfo = setup_ldkuserinfo(
// // 		c_char_to_string(rpc_info),
// //         c_char_to_string(ldk_storage_path),
// // 		9732,
// 		"regtest".to_string(),
//         "hellolightning".to_string(),
// 		"0.0.0.0".to_string()
// 	).unwrap();
   
//     // run ldk in seperate thread.
//     let ffi_sender = sender!(ffi);
//     let ffi_sender_clone = ffi_sender.clone();
//     rt.spawn(async move {
//         let res = ldk_lib::flutter_ldk(ldk_userinfo).await;

//         ffi_sender_clone.send(res).unwrap();
//     });

//     // wait for ldk response in seperate thread.
//     // then post to isolate.
//     rt.spawn(async move {
//         let isolate = Isolate::new(isolate_port);
//         let ffi_receiver = receiver!(ffi);

//         let res = ffi_receiver.recv().unwrap();

//         isolate.post(res);
//     });

//     1
// }


/// my tests.
#[cfg(test)]
mod tests {

    // use super::{ldk_channels, ffi_channels};

    // no longer works on computer.  only on phone.
	#[test]
	fn test_start_ldk(){

	}


}
