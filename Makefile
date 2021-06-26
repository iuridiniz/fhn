DIRS = vlang_fhn rust_fhn zig_fhn

.PHONY: all clean

all:
	 $(foreach dir,$(DIRS),$(MAKE) -C $(dir) $@;)
clean:
	 $(foreach dir,$(DIRS),$(MAKE) -C $(dir) $@;)
