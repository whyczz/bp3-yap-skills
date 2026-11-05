.PHONY: build check test fmt hooks install

build:
	dune build

check: build
	dune build @render
	dune test

test:
	dune test

fmt:
	dune fmt

hooks:
	./scripts/install-hooks.sh

install:
	dune install
