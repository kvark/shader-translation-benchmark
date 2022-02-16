struct naga_converter_t;

enum naga_stage_t {
	NAGA_VERTEX = 1,
	NAGA_FRAGMENT = 2,
	NAGA_COMPUTE = 3,
};

extern struct naga_converter_t* naga_init();
extern void naga_exit(struct naga_converter_t*);
extern void naga_convert_glsl_to_spirv(struct naga_converter_t*, char const*, enum naga_stage_t);
extern size_t naga_get_spirv_result_size(struct naga_converter_t const*);
