.PHONY: fmt

run:
	build/bench

fmt:
	cd ffi/naga && cargo fmt
	clang-format -i src/main.c ffi/tint/src/lib.cc
