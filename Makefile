SHELL := /bin/bash

.PHONY: ci lint-shell lint-php smoke-debian test-dry-run

ci: lint-shell lint-php smoke-debian test-dry-run

lint-shell:
	find install bin func upd tools tests -type f -print0 | while IFS= read -r -d '' file; do \
		if [[ "$$file" == *.sh ]]; then printf '%s\0' "$$file"; continue; fi; \
		IFS= read -r first_line < "$$file" || true; \
		[[ "$$first_line" == '#!'*sh* ]] && printf '%s\0' "$$file"; \
	done | xargs -0 -r bash -n
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck install/debian-common.sh tools/*.sh tests/*.sh; else echo 'shellcheck not installed; skipping'; fi

lint-php:
	@if [ -x /usr/bin/php ]; then find web install -type f -name '*.php' -print0 | xargs -0 -n1 -P4 timeout 10s /usr/bin/php -n -l >/tmp/vesta-php-lint.log && cat /tmp/vesta-php-lint.log; elif command -v php >/dev/null 2>&1 && ! command -v php | grep -q phpenv; then find web install -type f -name '*.php' -print0 | xargs -0 -n1 -P4 timeout 10s php -n -l >/tmp/vesta-php-lint.log && cat /tmp/vesta-php-lint.log; else echo 'system php not installed or phpenv shim is too slow; skipping local php lint'; fi

smoke-debian:
	bash tests/debian-smoke.sh

test-dry-run:
	VESTA_CI=1 VESTA_DEBIAN_RELEASE=12 bash install/vst-install-debian.sh --interactive no --apache no --nginx no --mysql no --exim no --dovecot no --clamav no --spamassassin no --iptables no --fail2ban no --softaculous no
