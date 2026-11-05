.PHONY: build check test fmt hooks install

build:
	dune build

check: build
	dune exec yap -- check --root .
	dune test

test:
	dune test

fmt:
	dune fmt

hooks:
	./scripts/install-hooks.sh

install:
	dune install
