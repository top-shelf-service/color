.PHONY: validate syntax test install-local reinstall status

validate:
	bash scripts/validate-color-system.sh

syntax:
	bash -n install.sh
	bash -n uninstall.sh
	bash -n bash_aliases_template.sh
	bash -n ctl_environment_template/colors.source.sh.template
	bash -n scripts/validate-color-system.sh

test: syntax validate
	@echo "All local tests passed."

install-local:
	./install.sh

reinstall:
	./install.sh --force --backup

status:
	git status --short
	git branch --show-current
