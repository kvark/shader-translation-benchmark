/*! Naga FFI bindings.
Matches "../naga.h"
!*/
#![allow(non_camel_case_types)]

use std::{ffi, os::raw};

pub struct naga_converter_t {
    glsl_in: naga::front::glsl::Parser,
    validator: naga::valid::Validator,
    spv_out: naga::back::spv::Writer,
    temp_spv: Vec<u32>,
}

#[no_mangle]
pub extern "C" fn naga_init() -> *mut naga_converter_t {
    let converter = naga_converter_t {
        glsl_in: naga::front::glsl::Parser::default(),
        validator: naga::valid::Validator::new(
            naga::valid::ValidationFlags::empty(),
            naga::valid::Capabilities::all(),
        ),
        spv_out: naga::back::spv::Writer::new(&Default::default()).unwrap(),
        temp_spv: Vec::with_capacity(0x1000),
    };
    Box::into_raw(Box::new(converter))
}

#[no_mangle]
pub unsafe extern "C" fn naga_exit(converter: *mut naga_converter_t) {
    let _ = Box::from_raw(converter).validator;
}

#[no_mangle]
pub unsafe extern "C" fn naga_convert_glsl_to_spirv(
    converter: &mut naga_converter_t,
    source: *const raw::c_char,
    stage: raw::c_int,
) {
    let in_options = naga::front::glsl::Options {
        stage: match stage {
            1 => naga::ShaderStage::Vertex,
            2 => naga::ShaderStage::Fragment,
            3 => naga::ShaderStage::Compute,
            _ => panic!("Unknown shader stage {}", stage),
        },
        defines: Default::default(),
    };
    let string = ffi::CStr::from_ptr(source).to_str().unwrap();
    let module = converter.glsl_in.parse(&in_options, string).unwrap();

    let info = converter.validator.validate(&module).unwrap();

    converter.temp_spv.clear();
    converter
        .spv_out
        .write(&module, &info, None, &mut converter.temp_spv)
        .unwrap();
}

#[no_mangle]
pub extern "C" fn naga_get_spirv_result_size(converter: &naga_converter_t) -> usize {
    converter.temp_spv.len()
}
