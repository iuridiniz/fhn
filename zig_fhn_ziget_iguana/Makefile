.PHONY: all clean fmt

BINARY = fhn

ifeq ($(OS),Windows)
	ZIGFLAGS += -Dtarget=x86_64-windows-gnu
	BINARY = fhn.exe
endif

all: $(BINARY)

$(BINARY): $(wildcard src/*.zig) build.zig
	zig build $(ZIGFLAGS)
	cp zig-out/bin/$@ $@

fmt: $(wildcard src/*.zig) build.zig
	zig fmt $?

clean:
	rm -f $(BINARY)
	rm -rf zig-out zig-cache
	
