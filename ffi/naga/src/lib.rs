/*! Naga FFI bindings.
Matches "../naga.h"
!*/
#![allow(non_camel_case_types)]

use std::{ffi, os::raw, slice};

pub struct naga_converter_t {
    glsl_in: naga::front::glsl::Parser,
    wgsl_in: naga::front::wgsl::Parser,
    validator: naga::valid::Validator,
    spv_out: naga::back::spv::Writer,
    temp_spv: Vec<u32>,
    temp_string: String,
}

#[no_mangle]
pub extern "C" fn naga_init() -> *mut naga_converter_t {
    let converter = naga_converter_t {
        glsl_in: naga::front::glsl::Parser::default(),
        wgsl_in: naga::front::wgsl::Parser::new(),
        validator: naga::valid::Validator::new(
            naga::valid::ValidationFlags::empty(),
            naga::valid::Capabilities::all(),
        ),
        spv_out: naga::back::spv::Writer::new(&Default::default()).unwrap(),
        temp_spv: Vec::with_capacity(0x1000),
        temp_string: String::with_capacity(0x1000),
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
) -> usize {
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
    converter.temp_spv.len()
}

#[no_mangle]
pub unsafe extern "C" fn naga_convert_spirv_to_wgsl(
    converter: &mut naga_converter_t,
    source: *const u32,
    size: usize,
) -> usize {
    let in_options = naga::front::spv::Options::default();
    let spv = slice::from_raw_parts(source, size);
    let module = naga::front::spv::Parser::new(spv.iter().cloned(), &in_options)
        .parse()
        .unwrap();

    let info = converter.validator.validate(&module).unwrap();

    converter.temp_string.clear();
    let mut w = naga::back::wgsl::Writer::new(
        &mut converter.temp_string,
        naga::back::wgsl::WriterFlags::empty(),
    );
    w.write(&module, &info).unwrap();
    w.finish().len()
}

#[no_mangle]
pub unsafe extern "C" fn naga_convert_spirv_to_msl(
    converter: &mut naga_converter_t,
    source: *const u32,
    size: usize,
) -> usize {
    let in_options = naga::front::spv::Options::default();
    let spv = slice::from_raw_parts(source, size);
    let module = naga::front::spv::Parser::new(spv.iter().cloned(), &in_options)
        .parse()
        .unwrap();

    let info = converter.validator.validate(&module).unwrap();
    let out_options = naga::back::msl::Options::default();
    let pipeline_options = naga::back::msl::PipelineOptions::default();

    converter.temp_string.clear();
    let mut w = naga::back::msl::Writer::new(&mut converter.temp_string);
    w.write(&module, &info, &out_options, &pipeline_options)
        .unwrap();
    w.finish().len()
}

#[no_mangle]
pub unsafe extern "C" fn naga_convert_wgsl_to_glsl(
    converter: &mut naga_converter_t,
    source: *const raw::c_char,
    entry_point: *const raw::c_char,
) -> usize {
    let string = ffi::CStr::from_ptr(source).to_str().unwrap();
    let module = converter.wgsl_in.parse(string).unwrap();

    let info = converter.validator.validate(&module).unwrap();

    let out_options = naga::back::glsl::Options {
        version: naga::back::glsl::Version::Embedded(320),
        writer_flags: naga::back::glsl::WriterFlags::empty(),
        binding_map: Default::default(),
    };
    let ep_string = ffi::CStr::from_ptr(entry_point).to_str().unwrap();
    let pipeline_options = naga::back::glsl::PipelineOptions {
        shader_stage: if ep_string.starts_with("vs_") {
            naga::ShaderStage::Vertex
        } else if ep_string.starts_with("fs_") {
            naga::ShaderStage::Fragment
        } else {
            naga::ShaderStage::Compute
        },
        entry_point: ep_string.to_string(),
    };

    converter.temp_string.clear();
    let mut w = naga::back::glsl::Writer::new(
        &mut converter.temp_string,
        &module,
        &info,
        &out_options,
        &pipeline_options,
    )
    .unwrap();
    let _reflection_info = w.write().unwrap();
    converter.temp_string.len()
}
