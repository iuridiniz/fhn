.PHONY: all clean

BINARY=fhn

all: $(BINARY)

fhn: $(wildcard *.go) go.mod
	go build -o $@

clean:
	rm -f $(BINARY)
