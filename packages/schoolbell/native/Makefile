CC ?= cc
AR ?= ar
CFLAGS ?= -Os
BUILD ?= ../../../out/native-schoolbell-player
WARN = -std=c99 -Wall -Wextra -Werror -pedantic
.PHONY: all
all: $(BUILD)/libschoolbell-player.a
$(BUILD):
	mkdir -p "$@"
$(BUILD)/player.o: player.c player.h | $(BUILD)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(WARN) -c player.c -o "$@"
$(BUILD)/libschoolbell-player.a: $(BUILD)/player.o
	$(AR) rcs "$@" "$<"
