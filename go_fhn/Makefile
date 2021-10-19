.PHONY: all clean

BINARY=fhn

all: $(BINARY)

fhn: $(wildcard *.go) go.mod
	go build -a -o $@

fhn.static: $(wildcard *.go) go.mod
	CGO_ENABLED=0 go build -a -ldflags '-extldflags "-static" -s -w' -o $@

clean:
	rm -f $(BINARY)
