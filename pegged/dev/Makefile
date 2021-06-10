
DCFALGS+=-I../../
DCFALGS+=-I../../examples/peggedgrammar/src/
LDFLAGS+=../../libpegged.a
DFILES+=../../examples/peggedgrammar/src/pegged/examples/peggedgrammar.d

all:
	dmd $(DCFALGS) $(DFILES) regenerate.d $(LDFLAGS)

clean:
	rm -f regenerate
