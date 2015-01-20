PREAMBLE=/*** Mark K Cowan, github.com/battlesnake, github.com/kartulita ***/

export SRCDIR=src
export OUTDIR=out
export JSDIR=$(OUTDIR)
export DOCDIR=$(OUTDIR)/doc
export JSDOCDIR=$(DOCDIR)/jsdoc
export DOCSRCDIR=$(SRCDIR)/$(DOCDIR)
export TESTDIR=$(OUTDIR)/tests

CLEANDIRS=$(OUTDIR)
DISTCLEANPREDICATE=-type 'd' -and \( -name 'bower_components' -or -name 'node_modules' \) -prune

PWD=$(shell pwd)

DOCS=$(patsubst $(SRCDIR)/%.md, %.html, $(wildcard $(DOCSRCDIR)/*.md))

ifeq (,$(SELECT))
MODULEHEADERS=$(shell find $(SRCDIR)/ -maxdepth 2 -type f -name 'module.js')
else
MODULEHEADERS=$(SELECT:%=$(SRCDIR)/%/module.js)
endif
MODULES=$(patsubst $(SRCDIR)/%/module.js, $(JSDIR)/%.js, $(MODULEHEADERS))
MODULE_DIRS=$(MODULEHEADERS:%/module.js=%/)
MODULES_MIN=$(MODULES:%.js=%.min.js)

JSDOC=$(JSDOCDIR)/index.html

export EXCLUDEPREDICATES=-not -path '*/demos/*' -not -path '*/tests/*' -not -path '*/.*' -not -path '*/node_modules/*' -not -path '*/bower_components/*'

export SOURCEPREDICATES=-type 'f' -name '*.js' $(EXCLUDEPREDICATES)
SOURCES=$(shell find $(MODULE_DIRS) $(SOURCEPREDICATES))

BUNDLE=$(JSDIR)/bundle.js
BUNDLE_MIN=$(BUNDLE:%.js=%.min.js)

export CSSPREDICATES=-type 'f' -name '*.css' $(EXCLUDEPREDICATES)
CSS=$(shell find $(MODULE_DIRS) $(CSSPREDICATES))

CSSBUNDLE=$(OUTDIR)/bundle.min.css

export LESSPREDICATES=-type 'f' -name '*.less' $(EXCLUDEPREDICATES)
LESS=$(shell find $(MODULE_DIRS) $(LESSPREDICATES))
LESSBUNDLE=$(OUTDIR)/bundle.less

export NPM=npm
export NODE_MODULES=node_modules
export NPM_NGDOC_DIR=$(NODE_MODULES)/angular-jsdoc
export NODE_BIN=$(NODE_MODULES)/.bin
PATH := $(PWD)/build:$(PWD)/$(NODE_BIN):$(PATH)
export NPM_JSDOC=jsdoc
export NGANNOTATE=ng-annotate --add --single_quotes -
export NPM_HTTP=http-server

export BOWER=bower --allow-root
export BOWER_COMPONENTS=bower_components

export UGLIFYJS=uglifyjs -c -m --preamble='$(PREAMBLE)' - 

export UGLIFYCSS=uglifycss

export LESSC=lessc

TAGS=sources modules bundle

export RMRF=rm -rf --
export RMF=rm -f --
export MKDIRP=mkdir -p --
export RMDIR=rmdir --ignore-fail-on-non-empty --

SHELL=bash
.SHELLFLAGS=-euo pipefail -c

.PHONY: all deps bundle modules docs clean serve syntax test stats styles

.SECONDEXPANSION:

all: bundle modules docs styles
	@true

bundle: $(BUNDLE_MIN)
	@true

modules: $(MODULES_MIN)
	@true

docs: $(JSDOC)
	@true

deps: | $(NODE_MODULES) $(BOWER_COMPONENTS)

syntax:
	@syntax.sh

test:
	@test.sh

clean:
	$(RMRF) $(CLEANDIRS) || true

distclean: clean
	find . $(DISTCLEANPREDICATE) -exec $(RMRF) {} \; || true

serve:
	http-server ./ -p 8000 -s -i0 >/dev/null 2>&1

stats: all
	stats.sh | less -r

styles: $(CSSBUNDLE) $(LESSBUNDLE)
	@true

$(NODE_MODULES):
	$(NPM) install

$(NODE_MODULES)/%:
	$(NPM) install $(@:$(NODE_MODULES)/%=%)

$(BOWER_COMPONENTS): $(NODE_MODULES)/bower
	$(BOWER) install

$(OUTDIR):
	$(MKDIRP) $(OUTDIR)

$(DOCDIR):
	$(MKDIRP) $(DOCDIR)

$(JSDOCDIR):
	$(MKDIRP) $(JSDOCDIR)

%.min.js: %.js | $(NODE_MODULES)/uglify-js
	$(UGLIFYJS) < $^ > $@ || ($(RMF) $@; false)

$(BUNDLE): $(MODULES) | $(JSDIR)
	concatenate.pl $^ > $@

$(JSDIR)/%.js: $(SRCDIR)/%/* $(SRCDIR)/%/* | $(JSDIR) $(NODE_MODULES)/ng-annotate
	build-module.pl ${@:$(JSDIR)/%.js=%} | $(NGANNOTATE) > $@

$(JSDOC): $(SOURCES) | $(JSDOCDIR) $(NODE_MODULES)/jsdoc $(NODE_MODULES)/angular-jsdoc
	$(NPM_JSDOC) $(SRCDIR) -d $(JSDOCDIR) -c build/jsdoc.json -t $(NPM_NGDOC_DIR)/template

$(CSSBUNDLE): $(CSS) | $(OUTDIR) $(LESSBUNDLE) $(NODE_MODULES)/uglifycss
ifneq "$$^" ""
	{ cat -- $^ && $(LESSC) $(LESSBUNDLE); } | $(UGLIFYCSS) > $@
else
	@echo "No CSS files found"
endif

$(LESSBUNDLE): $(LESS) | $(OUTDIR) $(NODE_MODULES)/less
ifneq "$$^" ""
	cat -- $^ > $@
	$(LESSC) -l $@
else
	@echo "No LESS files found"
endif	

diag:
	@echo "Modules: "
	@printf -- " * %s\n" $(MODULES)
	@echo
	@echo "JS sources: "
	@printf -- " * %s\n" $(SOURCES)
	@echo
	@echo "CSS styles: "
	@printf -- " * %s\n" $(CSS)
	@echo
	@echo "LESS styles: "
	@printf -- " * %s\n" $(LESS)
	@echo
