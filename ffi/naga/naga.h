struct naga_converter_t;

enum naga_stage_t {
	NAGA_VERTEX = 1,
	NAGA_FRAGMENT = 2,
	NAGA_COMPUTE = 3,
};

extern struct naga_converter_t* naga_init();
extern void naga_exit(struct naga_converter_t*);
// generate SPIR-V and report its size
extern size_t naga_convert_glsl_to_spirv(struct naga_converter_t*, char const*, enum naga_stage_t);
// generate WGSL and report its length
extern size_t naga_convert_spirv_to_wgsl(struct naga_converter_t*, unsigned const*, size_t);
// generate MSL and report its length
extern size_t naga_convert_spirv_to_msl(struct naga_converter_t*, unsigned const*, size_t);
// generate GLSL and report its length
extern size_t naga_convert_wgsl_to_glsl(struct naga_converter_t*, char const*, char const*);
