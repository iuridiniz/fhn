.PHONY: all clean


all: fhn
fhn: $(wildcard *.v)
	v -prod -showcc -g -o fhn .

clean:
	rm fhn
