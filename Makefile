REBAR ?= $(shell pwd)/rebar

.PHONY: deps rel

all: deps compile

compile:
	$(REBAR) compile

recompile:
	$(REBAR) compile skip_deps=true

deps:
	$(REBAR) get-deps

clean:
	$(REBAR) clean
	rm -rf build

distclean: clean
	$(REBAR) delete-deps