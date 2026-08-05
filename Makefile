.PHONY: run clean
MAKEFLAGS := -rR

EMACS := /d/local/bin/emacs.exe
entry := test.el
elc-args := minibuffer-frame.elc

run: $(elc-args)
	$(EMACS) -Q \
	-L . \
	-l $(entry)

$(elc-args): %.elc : %.el
	$(EMACS) -Q --batch \
	--eval "(setq byte-compile-error-on-warn t)" \
	-L . \
	-f batch-byte-compile $<

clean:
	rm -f *.elc

log-%:
	$(info $* = $($*))
