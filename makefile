# Subshell configuration
SHELL = bash
.SHELLFLAGS = -euo pipefail -c

# Directories
export srcdir := src
export outdir := out
export mindir := $(outdir)/min
export testdir := $(outdir)/tests
export docdir := $(outdir)/doc

# Directories to delete on clean
cleandirs := $(outdir)

# Transient folders (not included in dependency checking, deleted on fullclean)
transientpredicate := -name 'bower_components' -or -name 'node_modules'

# Predicate for total cleaning
fullcleanpredicate := -type 'd' -and \( $(transientpredicate) \) -prune

# Get makefile directory
pwd := $(shell pwd)

# Get list of modules to build
modulejs = $(wildcard $(srcdir)/*/module.js)
all_modules = $(modulejs:$(srcdir)/%/module.js=%)
ifeq "$(select)" ""
modules := $(all_modules)
else
comma := ,
modules := $(subst $(comma), ,$(select))
endif

# Dependency resolution
-include makefile.deps

export modules
module_release_targets := $(modules:%=minify-module-%)

jsdoc := $(docdir)/index.html

# Build-system dependencies
export npm := npm
export jsdoc_template := node_modules/angular-jsdoc/template
PATH := $(pwd)/build:$(pwd)/node_modules/.bin:$(PATH)

export annotate := ng-annotate --add --single_quotes -
export bower := bower --allow-root
export uglifyjs := uglifyjs -c -m -
export uglifycss := uglifycss
export lessc := lessc -
export jsdoc := jsdoc

# Command alisaes
export rmrf := rm -rf --
export rmf := rm -f --
export mkdirp := mkdir -p --
export rmdir := rmdir --ignore-fail-on-non-empty --

.PHONY: default clean fullclean all docs stats release debug

.SECONDARY:

.SECONDEXPANSION:

default: all

deps: | node_modules bower_components
	@perl -e 'use IPC::Pipeline' || cpan install IPC::Pipeline
	@perl -e 'use IPC::Open2' || cpan install IPC::Open2

node_modules:
	$(npm) install

bower_components: node_modules
	$(bower) install

stats: release
	stats.sh | less -r || true

syntax: node_modules
	syntax.sh

all: $(mindir)/bundle.js $(mindir)/bundle.css $(outdir)/bundle.less
	@true

release: all $(module_release_targets)
	@true

debug: $(outdir)/bundle.js $(outdir)/bundle.css $(outdir)/bundle.less

clean:
	$(rmrf) $(cleandirs)

fullclean: clean
	find $(fullcleanpredicate) -exec $(rmrf) {} \;

docs:
	$(jsdoc) $(srcdir) -d $(docdir) -c build/jsdoc.json -t $(jsdoc_template)

minify-module-%: $(mindir)/%.js $(mindir)/%.css $(outdir)/%.less | node_modules/ng-annotate
	@true

build-module-%: $$(shell find $(srcdir)/% '(' $(transientpredicate) ')' -prune -o '(' -name '*.js' -or -name '*.html' ')' ) | $(outdir) node_modules
	$(eval module := $(@:build-module-%=%)) $(eval moddir := $(srcdir)/$(module))
	@if [ -e $(moddir)/makefile ]; then \
		echo -e "  \e[32mINTEGRATE\e[0m   $(module)" \
		integration_target=$$(realpath $(outdir)) \
			make --no-print-directory -C $(moddir) integrate; \
	fi
	@echo -e "  \e[32mBUILD\e[0m       $(module)"
	@build-module.pl $(module) $(srcdir) $(outdir)

$(outdir):
	@$(mkdirp) $(outdir)

$(mindir):
	@$(mkdirp) $(mindir)

$(docdir):
	@$(mkdirp) $(docdir)

$(testdir):
	@$(mkdirp) $(testdir)

$(outdir)/bundle.js: $(modules:%=$(outdir)/%.js)
	@echo -e "  \e[32mCONCATENATE\e[0m $(@:$(outdir)/%=%)"
	@cat -- $^ > $@

$(outdir)/bundle.css: $(modules:%=$(outdir)/%.css)
	@echo -e "  \e[32mCONCATENATE\e[0m $(@:$(outdir)/%=%)"
	@cat -- $^ > $@

$(outdir)/bundle.less: $(modules:%=$(outdir)/%.less)
	@echo -e "  \e[32mCONCATENATE\e[0m $(@:$(outdir)/%=%)"
	@cat -- $^ > $@

$(mindir)/%.js: $(outdir)/%.js | node_modules $(mindir)
	@echo -e "  \e[32mUGLIFY-JS\e[0m   $(@:$(mindir)/%=%)"
	@$(uglifyjs) < $< > $@ || ($(rmf) $@; false)

$(mindir)/%.css: $(outdir)/%.css | node_modules $(mindir)
	@echo -e "  \e[32mUGLIFY-CSS\e[0m  $(@:$(mindir)/%=%)"
	@$(uglifycss) < $< > $@ || ($(rmf) $@; false)

$(outdir)/%.js: build-module-%
	@true

$(outdir)/%.css: $(outdir)/%.less build-module-%
	@echo -e "  \e[32mLESS\e[0m        $(@:$(outdir)/%=%)"
	@$(lessc) < $< >> $@

$(outdir)/%.less: build-module-%
	@true

-include makefile.local
