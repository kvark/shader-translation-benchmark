#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <glslang_c_interface.h>
#include <naga.h>

const char* CORPUS_GLSL[] = {
	"bevy-pbr.vert",
	"bevy-pbr.frag",
};
const int CORPUS_GLSL_SIZE = sizeof(CORPUS_GLSL) / sizeof(CORPUS_GLSL[0]);

void timer_end(clock_t time_start, const char *what) {
	const unsigned usec = (clock() - time_start) * 1000 / CLOCKS_PER_SEC;
	printf("%s time: %u usec\n", what, usec);
}

const char** gather_glsl() {
	const char** sources = malloc(CORPUS_GLSL_SIZE * sizeof(const char*));
	char path[256] = {};
	for (int i=0; i<CORPUS_GLSL_SIZE; ++i) {
		sprintf(path, "corpus/glsl/%s", CORPUS_GLSL[i]);
		FILE* file = fopen(path, "rb");
		assert(file && "Corpus file not found");
		fseek(file, 0, SEEK_END);
		long size = ftell(file);
		fseek(file, 0, SEEK_SET);
		char*code = malloc(size + 1);
		int count = fread(code, size, 1, file);
		assert(count && "Unable to read the corpus file");
		code[size] = 0;
		fclose(file);
		sources[i] = code;
	}
	return sources;
}

void bench_naga() {
	struct naga_converter_t*const converter = naga_init();
	const char** sources = gather_glsl();
	const clock_t time_start = clock();

	for (int i=0; i<CORPUS_GLSL_SIZE; ++i) {
		const enum naga_stage_t stage =
			strstr(CORPUS_GLSL[i], ".vert") ? NAGA_VERTEX :
			strstr(CORPUS_GLSL[i], ".frag") ? NAGA_FRAGMENT :
			NAGA_COMPUTE;
		naga_convert_glsl_to_spirv(converter, sources[i], stage);
		size_t size = naga_get_spirv_result_size(converter);
		assert(size > 0 && "SPIR-V generation failed");
	}

	timer_end(time_start, "naga");
	free(sources);
	naga_exit(converter);
}

void bench_glslang() {
	glslang_initialize_process();
	const char** sources = gather_glsl();
	glslang_resource_t resource = {
		.max_texture_units = 16,
		.max_texture_coords = 16,
		.max_vertex_attribs = 16,
		.max_varying_floats = 64,
		.max_draw_buffers = 4,
		.limits = {
			.non_inductive_for_loops = 1,
			.while_loops = 1,
			.do_while_loops = 1,
			.general_uniform_indexing = 1,
			.general_attribute_matrix_vector_indexing = 1,
			.general_varying_indexing = 1,
			.general_sampler_indexing = 1,
			.general_variable_indexing = 1,
			.general_constant_matrix_vector_indexing = 1,
		},
	};

	const clock_t time_start = clock();
	for (int i=0; i<CORPUS_GLSL_SIZE; ++i) {
		const glslang_stage_t stage =
			strstr(CORPUS_GLSL[i], ".vert") ? GLSLANG_STAGE_VERTEX :
			strstr(CORPUS_GLSL[i], ".frag") ? GLSLANG_STAGE_FRAGMENT :
			GLSLANG_STAGE_COMPUTE;
		glslang_input_t input = {
			.language = GLSLANG_SOURCE_GLSL,
			.stage = stage,
			.client = GLSLANG_CLIENT_VULKAN,
			.client_version = GLSLANG_TARGET_VULKAN_1_1,
			.target_language = GLSLANG_TARGET_SPV,
			.target_language_version = GLSLANG_TARGET_SPV_1_3,
			.code = sources[i],
			.default_version = 100,
			.default_profile = GLSLANG_NO_PROFILE,
			.force_default_version_and_profile = false,
			.messages = GLSLANG_MSG_DEFAULT_BIT,
			.resource = &resource,
		};

		glslang_shader_t*const shader = glslang_shader_create(&input);
		glslang_shader_preprocess(shader, &input);
		glslang_shader_parse(shader, &input);
		const char* const info_log = glslang_shader_get_info_log(shader);
		if (info_log && strlen(info_log) > 0) {
			printf("'%s' info log:\n%s", CORPUS_GLSL[i], info_log);
		}

		glslang_program_t*const program = glslang_program_create();
		glslang_program_add_shader(program, shader);
		glslang_program_link(program, GLSLANG_MSG_SPV_RULES_BIT | GLSLANG_MSG_VULKAN_RULES_BIT);
		glslang_program_SPIRV_generate(program, stage);
		size_t size = glslang_program_SPIRV_get_size(program);
		assert(size > 0 && "SPIR-V generation failed");
		//printf("\t'%s' generated SPIR-V size: %lu\n", CORPUS_GLSL[i], size);

		glslang_shader_delete(shader);
		glslang_program_delete(program);
	}

	timer_end(time_start, "glslang");
	free(sources);
	glslang_finalize_process();
}

int main() {
	printf("GLSL -> SPIRV\n");
	bench_naga();
	bench_glslang();
	return 0;
}
