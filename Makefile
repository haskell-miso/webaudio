SHELL := bash
JS_TOOLS := $(CURDIR)/dist-newstyle/js-tools
JS_CABAL = PATH="$(JS_TOOLS):$$PATH" cabal --with-ghc=$(shell command -v javascript-unknown-ghcjs-ghc) --with-hc-pkg=$(shell command -v javascript-unknown-ghcjs-ghc-pkg)
EXE := webaudio-check
JS_SITE := dist-site/js
WASM_SITE := dist-site/wasm

.PHONY: js-tools update-js update-wasm build-js build-wasm check-js check-wasm clean

js-tools:
	mkdir -p $(JS_TOOLS)
	ln -sf $$(command -v javascript-unknown-ghcjs-ghc-pkg) $(JS_TOOLS)/ghc-pkg
	ln -sf $$(command -v javascript-unknown-ghcjs-ghc) $(JS_TOOLS)/ghc
	ln -sf $$(command -v javascript-unknown-ghcjs-hsc2hs) $(JS_TOOLS)/hsc2hs

update-js: js-tools
	$(JS_CABAL) update

update-wasm:
	wasm32-wasi-cabal update

build-js: js-tools
	$(JS_CABAL) build $(EXE)
	rm -rf $(JS_SITE)
	mkdir -p $(JS_SITE)
	cp test/browser/reference.js test/browser/worklet.js $(JS_SITE)/
	cp test/browser/index-js.html $(JS_SITE)/index.html
	cp "$$($(JS_CABAL) list-bin $(EXE)).jsexe/all.js" $(JS_SITE)/all.js

build-wasm:
	wasm32-wasi-cabal build $(EXE)
	rm -rf $(WASM_SITE)
	mkdir -p $(WASM_SITE)
	cp -r test/browser/vendor $(WASM_SITE)/vendor
	cp test/browser/reference.js test/browser/worklet.js $(WASM_SITE)/
	cp test/browser/index-wasm.html $(WASM_SITE)/index.html
	cp test/browser/host.mjs $(WASM_SITE)/host.mjs
	wasm=$$(wasm32-wasi-cabal list-bin $(EXE) | tail -n 1); \
	"$$(wasm32-wasi-ghc --print-libdir)/post-link.mjs" --input "$$wasm" --output $(WASM_SITE)/ghc_wasm_jsffi.js; \
	cp "$$wasm" $(WASM_SITE)/app.wasm

check-js:
	node test/browser/check.mjs $(JS_SITE)

check-wasm:
	node test/browser/check.mjs $(WASM_SITE)

clean:
	rm -rf dist-newstyle dist-site
