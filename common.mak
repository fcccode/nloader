# compiler detection
COMPILER = "$(shell $(CC) --version | head -1)"

CFLAGS  = -I$(top)
CFLAGS += -D_FILE_OFFSET_BITS=64
CFLAGS += -m32
CFLAGS += -O0 -g3 -Wall
CFLAGS += -DLIBNLOADER=\"/usr/lib/nloader\"

DEPFLAGS += -MMD -MF $(@:.o=.d) -MT $@

# glibc decided to crash in strcasestr using sse2 code
ifneq (,$(findstring clang, $(COMPILER)))
	CFLAGS += -mstackrealign
else ifneq (,$(findstring cc, $(COMPILER)))
	CFLAGS += -mincoming-stack-boundary=2
endif

ifdef RELEASE
CFLAGS += -O2
STRIP  = strip --strip-unneeded
else
STRIP  = :
endif

TARGETS = nloader lznt1 libs

RANLIB = ranlib
MKNTFS = PATH=$(PATH):/sbin:/usr/sbin mkntfs

YFMT = elf32
YDBG = dwarf2
ifdef USE_CCACHE
CC := $(shell which ccache 2>/dev/null) $(CC)
endif
OS = $(shell uname -s)

ifneq (,$(findstring Linux, $(OS)))
	TARGETS += disk.img
	CFLAGS += -fshort-wchar
	CFLAGS += -Werror
	LDFLAGS += -ldl
	MKSO = $(CC) $(CFLAGS) -shared
ifneq (,$(wildcard autochk.exe))
	TARGETS += autochk
	LDALONE = -rdynamic -Wl,--whole-archive -L$(top)/libs/ntdll -lntdll -Wl,--no-whole-archive
endif
else ifneq (,$(findstring FreeBSD, $(OS)))
	TARGETS += disk.img
	CFLAGS += -fshort-wchar
	MKSO = $(CC) $(CFLAGS) -shared
	YFLAGS = -Dstderr=__stderrp
else ifneq (,$(findstring Darwin, $(OS)))
	CFLAGS += -fshort-wchar -mstackrealign
	LDFLAGS += -ldl -Wl,-read_only_relocs,suppress,-undefined,dynamic_lookup -single-module
	YFMT = macho32
	YDBG = null
	MKSO = $(CC) $(CFLAGS) $(LDFLAGS) -dynamiclib
else ifneq (,$(findstring MINGW32, $(OS)))
	TARGETS += volumeinfo
	MKSO = dllwrap --def $(basename $(@F)).def
	EXE = .exe
	YFMT = win32
else
$(error $(OS) is not supported)
endif

#CFLAGS += -DDEBUG_HEAP
#CFLAGS += -DDEBUG_CRT

#CFLAGS += -DTHREADED -pthread

#CFLAGS += -DREDIR_IO
#CFLAGS += -DREDIR_SYSCALL

all:: $(TARGETS)

%.o: %.c Makefile $(top)/common.mak
	$(CC) $(CFLAGS) $(DEPFLAGS) -c -o $@ $<

%.o: %.asm Makefile $(top)/common.mak $(top)/asmdefs.inc
	yasm $(YFLAGS) -I$(top) -g $(YDBG) -a x86 -f $(YFMT) -o $@ $<

# disable most of builtin rules
.SUFFIXES:
