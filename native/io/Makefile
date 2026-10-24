# Separate native build; never copied into the script-only IPK.
CC ?= cc
AR ?= ar
CFLAGS ?= -Os
WARN = -std=c99 -Wall -Wextra -Werror -pedantic
BUILD ?= ../../out/native-io
.PHONY: all
all: $(BUILD)/libomc-io.a
$(BUILD):
	mkdir -p "$@"
$(BUILD)/omc_io.o: omc_io.c omc_io.h | $(BUILD)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(WARN) -c omc_io.c -o "$@"
$(BUILD)/libomc-io.a: $(BUILD)/omc_io.o
	$(AR) rcs "$@" "$<"
