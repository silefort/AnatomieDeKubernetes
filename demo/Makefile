VERSION ?= 0

.PHONY: tmux play

tmux:
	@bash tmux.sh $(VERSION)

ssh:
	ssh ubuntu@ns5006497.ip-192-99-35.net

play:
	@asciinema play $(CAST)

help:
	@echo "Usage: make tmux VERSION=<0|1|2>"
	@echo "       make play CAST=<chemin>"
