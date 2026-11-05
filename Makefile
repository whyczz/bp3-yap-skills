.PHONY: build check test fmt hooks install install-skills

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

# Usage:
#   make install-skills
#   make install-skills pi global
#   make install-skills all
#   make install-skills all global
#   make install-skills codex global
#   make install-skills pi local-dir DIR=/path/to/project
#   make install-skills claude local-dir DIR=/path/to/project
#
# The words after install-skills are captured as arguments, not targets:
# first the harness (default pi), then the scope (global, or local-dir
# which needs DIR). Anything else is passed to the yap CLI, which rejects
# unknown harnesses and scopes we do not recognise here.
install-skills:
	@harness='$(or $(word 2,$(MAKECMDGOALS)),pi)'; scope='$(or $(word 3,$(MAKECMDGOALS)),global)'; \
	case "$$harness" in global|local|local-dir|project) scope="$$harness"; harness=pi ;; esac; \
	harness_arg="$$harness"; \
	if [ "$$harness" = "all" ]; then harness_arg="pi,claude,codex,muse"; fi; \
	case "$$scope" in \
	  global) \
	    dune exec yap -- install --root . --harness "$$harness_arg" -g ;; \
	  local|local-dir|project) \
	    if [ -z "$(DIR)" ]; then \
	      echo "usage: make install-skills $$harness local-dir DIR=/path/to/project" >&2; exit 2; \
	    fi; \
	    dune exec yap -- install --root . --harness "$$harness_arg" -p --target "$(DIR)" ;; \
	  *) echo "unknown scope: $$scope (expected global or local-dir)" >&2; exit 2 ;; \
	esac

# Swallow the argument words after install-skills so Make does not try
# to build them as targets.
EXTRA_GOALS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
ifneq (,$(filter install-skills,$(MAKECMDGOALS)))
.PHONY: $(EXTRA_GOALS)
$(EXTRA_GOALS): ; @:
endif
