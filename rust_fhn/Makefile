.PHONY: all clean

BINARY=fhn

all: $(BINARY)
fhn: $(wildcard src/*.rs)
	cargo build --release
	cp target/release/$@ $@

clean:
	rm $(BINARY)
	cargo clean
	
