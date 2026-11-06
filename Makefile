.PHONY: check test lint package render hooks install install-skills

check: lint
	./scripts/yap check
	./test/test_yap.sh

lint:
	shellcheck -x scripts/yap scripts/*.sh test/*.sh .githooks/pre-commit

test:
	./test/test_yap.sh

render:
	./scripts/yap render --all

package:
	./scripts/yap plugin --harness pi,claude,codex,muse

hooks:
	./scripts/install-hooks.sh

# Compatibility: make install installs skills, not a compiled authoring binary.
install: install-skills

# make install-skills [pi|claude|codex|muse|all] [global|local-dir] [DIR=...]
install-skills:
	@harness='$(or $(word 2,$(MAKECMDGOALS)),pi)'; scope='$(or $(word 3,$(MAKECMDGOALS)),global)'; \
	case "$$harness" in global|local|local-dir|project) scope="$$harness"; harness=pi ;; esac; \
	if [ "$$harness" = all ]; then harness=pi,claude,codex,muse; fi; \
	case "$$scope" in \
	  global) ./scripts/yap install --harness "$$harness" -g ;; \
	  local|local-dir|project) \
	    if [ -z "$(DIR)" ]; then echo 'local-dir requires DIR=/path/to/project' >&2; exit 2; fi; \
	    ./scripts/yap install --harness "$$harness" -p --target "$(DIR)" ;; \
	  *) echo "unknown scope: $$scope" >&2; exit 2 ;; \
	esac

EXTRA_GOALS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
ifneq (,$(filter install-skills,$(MAKECMDGOALS)))
.PHONY: $(EXTRA_GOALS)
$(EXTRA_GOALS): ; @:
endif
