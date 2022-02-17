.PHONY: run fmt chart

run:
	build/bench

fmt:
	cd ffi/naga && cargo fmt
	cd visual && cargo fmt
	clang-format -i src/main.c ffi/tint/src/lib.cc

chart:
	cd visual && cargo run
