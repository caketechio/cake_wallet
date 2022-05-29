use std::env;
use dart_bindgen::{config::*, Codegen};

fn main(){
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    let mut config = cbindgen::Config::default();
    config.language = cbindgen::Language::C;
    config.braces = cbindgen::Braces::SameLine;
    config.cpp_compat = true;
    config.style = cbindgen::Style::Both;

    cbindgen::Builder::new()
        .with_crate(crate_dir)
        .with_config(config)
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file("libldk_ffi.h");

    let config = DynamicLibraryConfig {
        ios: DynamicLibraryCreationMode::Executable.into(),
        android: DynamicLibraryCreationMode::open("libldk_ffi.so").into(),
        ..Default::default()
    };

    // load the c header file, with config and lib name
    let codegen = Codegen::builder()
        .with_src_header("libldk_ffi.h")
        .with_lib_name("libldk_ffi")
        .with_config(config)
        .with_allo_isolate()
        .build()
        .unwrap();
    
    // generate the dart code and get the bindings back
    let bindings = codegen.generate().unwrap();

    // write the bindings to your dart package
    // and start using it to write your own high level abstraction.
    bindings
        .write_to_file("../../lib/ffi.dart")
        .unwrap();
}