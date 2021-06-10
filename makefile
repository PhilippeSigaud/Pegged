include setup.mk

all:
	if [ -x /usr/bin/dmd ]; then \
		dmd -w -wi -O -release -noboundscheck -lib -oflibpegged.a $(DFILES); \
	elif [ -x /usr/bin/ldc2 ]; then \
		ldc2 -w -wi -O2 -release -boundscheck=off -c -of=libpegged.a $(DFILES); \
	elif [ -x /usr/bin/gdc ]; then \
		gdc -Wall -O2 -frelease -fbounds-check=off -c -olibpegged.a $(DFILES); \
	fi

clean:
		rm -f libpegged.a

info:
	@echo "DFILES = $(DFILES)"

ALL_PEG:=${shell find examples -maxdepth 1 -type d -not -path examples}

define Pegs
$1/.done:
	cd $1; dub test
	touch $1/.done

endef

${foreach DONE,$(ALL_PEG), ${eval ${call Pegs,$(DONE)}}}

DO_ALL := ${addsuffix /.done,$(ALL_PEG)}

test-all: $(DO_ALL)

test-clean:
	rm -f $(DO_ALL)

export DO_ALL_PEG=${foreach DONE,$(ALL_PEG), ${call Pegs,$(DONE)}}


CALL_PEG:=${call Pegs,c}}

export CALL_PEG

show:
	@echo "$$CALL_PEG"
	@echo "$$DO_ALL_PEG"
	@echo $(ALL_PEG)
	@echo $(DO_ALL)
