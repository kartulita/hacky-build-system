SRCDIR=src
OUTDIR=out
TMPDIR=tmp
TAGDIR=html
DOCDIR=doc
JSDOCDIR=$(DOCDIR)/jsdoc
DOCSRCDIR=$(SRCDIR)/$(DOCDIR)

TITLE=Wheatley

PWD=$(shell pwd)

DOCS=$(patsubst $(SRCDIR)/%.md, %.html, $(wildcard $(DOCSRCDIR)/*.md))

MODULES=$(patsubst $(SRCDIR)/%/module.js, $(OUTDIR)/%.js, $(shell find $(SRCDIR)/ -maxdepth 2 -type f -name 'module.js'))

JSDOC=$(JSDOCDIR)/index.html

SOURCES=$(shell find $(SRCDIR)/ -type f -name '*.js' -not -path '*/tests/*' -not -path '*/doc/*')

BUNDLE=$(OUTDIR)/bundle.js

NODE_MODULES=node_modules
NPM_NGDOC_DIR=$(NODE_MODULES)/angular-jsdoc
NODE_BIN=$(NODE_MODULES)/.bin
NPM_JSDOC=$(NODE_BIN)/jsdoc
export NGANNOTATE=$(NODE_BIN)/ng-annotate --add --single_quotes -
export NPM_HTTP=$(PWD)/$(NODE_BIN)/http-server

ifdef TEST
export UGLIFY=$(NODE_BIN)/uglifyjs -b -
else
export UGLIFY=$(NODE_BIN)/uglifyjs -c -m -
endif

TAGS=sources modules bundle

RMRF=rm -rf --
RMF=rm -f --
MKDIRP=mkdir -p --
RMDIR=rmdir --ignore-fail-on-non-empty --

SHELL=bash
.SHELLFLAGS=-euo pipefail -c

.PHONY: all bundle modules docs clean serve deps npm_deps tags syntax test test-loop stats ngdoc jsdoc

all: bundle modules docs tags
	@true

bundle: $(BUNDLE)
	@true

modules: $(MODULES)
	@true

# $(DOCS) $(DOCDIR)/index.html
docs: jsdoc
	@true


ngdoc: jsdoc
	@true

jsdoc: $(JSDOC)
	@true

deps:
	npm install

syntax:
	@build/syntax.sh $(SOURCES)

syntax-loop:
	@build/syntax.sh --loop $(SOURCES) || true

test:
	@build/test.sh

test-loop:
	@build/test.sh --loop || true

clean:
	$(RMRF) $(OUTDIR) $(TMPDIR) $(TAGDIR) $(DOCDIR) || true

distclean: clean
	$(RMRF) $(NODE_MODULES) || true

serve:
	http-server ./ -p 8000 -s -i0 >/dev/null 2>&1

stats:
	build/stats.sh | less -r
	
$(OUTDIR):
	$(MKDIRP) $(OUTDIR)

$(TAGDIR):
	$(MKDIRP) $(TAGDIR)

$(TMPDIR):
	$(MKDIRP) $(TMPDIR)

$(DOCDIR):
	$(MKDIRP) $(DOCDIR)

$(JSDOCDIR):
	$(MKDIRP) $(JSDOCDIR)

tags: | $(TAGDIR)
	build/html-tags.pl >$(TAGDIR)/sources.html $(SOURCES:$(SRCDIR)/%=$(PREFIX)%)
	build/html-tags.pl >$(TAGDIR)/modules.html $(MODULES:$(OUTDIR)/%=$(PREFIX)%)
	build/html-tags.pl >$(TAGDIR)/bundle.html $(PREFIX)$(BUNDLE:$(OUTDIR)/%=%)

$(BUNDLE): $(MODULES) | npm_deps $(OUTDIR) $(TMPDIR)
	$(eval TEMP=$(TMPDIR)/$(subst /,_,$@))
	build/concatenate.pl $^ > $(TEMP).cat
	$(UGLIFY) < $(TEMP).cat > $(TEMP).ugly
	cp $(TEMP).ugly $@

$(OUTDIR)/%.js: $(SRCDIR)/%/*.js | npm_deps $(OUTDIR) $(TMPDIR)
	$(eval TEMP=$(TMPDIR)/$(subst /,_,$@))
	build/concatenate.pl $^ > $(TEMP).cat
	$(NGANNOTATE) < $(TEMP).cat > $(TEMP).annot
	$(UGLIFY) < $(TEMP).annot > $(TEMP).ugly
	cp $(TEMP).ugly $@

$(JSDOCDIR)/index.html: $(SOURCES) | $(JSDOCDIR)
	$(NPM_JSDOC) -r $(SRCDIR) -d $(JSDOCDIR) -c $(NPM_NGDOC_DIR)/conf.json -t $(NPM_NGDOC_DIR)/template

$(DOCDIR)/index.html: $(DOCS)
	cat $(sort $^) | build/doc.sh $(TITLE) > $@
	cp -t $(DOCDIR) build/docpage/*.{css,js}

$(DOCDIR)/%.html: $(DOCSRCDIR)/%.md $(SOURCES) | $(DOCDIR)
	$(eval NAME=$(patsubst $(DOCSRCDIR)/%.md,%,$<))
	build/demo.sh $< $(SRCDIR) $(DOCDIR)/demos/$(NAME)
	pandoc --from=markdown_github --to=html < $< > $@
