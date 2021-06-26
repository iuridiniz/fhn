.PHONY: all clean fmt

BINARY=fhn

all: $(BINARY)

fhn: $(wildcard src/*.zig) build.zig fmt
	zig build
	cp zig-out/bin/$@ $@

fmt: $(wildcard src/*.zig) build.zig
	zig fmt $?

clean:
	rm -f $(BINARY)
	rm -rf zig-out zig-cache
	
