.PHONY: help dev up down check-knowledge

.DEFAULT_GOAL := help

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf " %-18s %s\n", $$1, $$2}'

dev: ## Validate knowledge handbook (foreground)
	@$(MAKE) check-knowledge

up: ## Same as check-knowledge (no long-running stack yet)
	@$(MAKE) check-knowledge

down: ## No-op placeholder (no background stack yet)
	@echo "No background stack to stop."

check-knowledge: ## Ensure required knowledge files exist
	@test -f knowledge/README.md
	@test -f knowledge/variables.md
	@test -f knowledge/00-overview.md
	@test -f knowledge/03-semi-auto-release.md
	@test -f knowledge/08-cloudflare.md
	@test -f knowledge/09-isolation-safety.md
	@test -f knowledge/secrets.example.md
	@echo "knowledge handbook OK"
