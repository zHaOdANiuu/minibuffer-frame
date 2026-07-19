.PHONY: run clean
MAKEFLAGS := -rR

entry := test/test.el
elc-args := fido-frame.elc

run: $(elc-args)
	emacs -Q \
	-L . \
	-l $(entry)

$(elc-args): %.elc : %.el
	emacs -Q --batch \
	--eval "(setq byte-compile-error-on-warn t)" \
	-L . \
	-f batch-byte-compile $<

clean:
	rm -f *.elc

log-%:
	$(info $* = $($*))
