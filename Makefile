.PHONY: changelog release-dry-run release release-patch release-minor release-major

# Regenerate CHANGELOG.md, sync install.sh + README.md version, amend the bump commit, and move the tag
define post-bump
	@TAG=$$(git describe --tags --abbrev=0) && \
		VER=$${TAG#v} && \
		git-cliff -o CHANGELOG.md && \
		sed -i "s/^VERSION=\"[0-9]*\.[0-9]*\.[0-9]*\"/VERSION=\"$$VER\"/" install.sh && \
		sed -i "s/version-[0-9]*\.[0-9]*\.[0-9]*-blue/version-$$VER-blue/" README.md && \
		git add CHANGELOG.md install.sh README.md && \
		git commit --amend --no-edit && \
		git tag -d $$TAG && \
		git tag $$TAG && \
		echo "Released $$TAG"
endef

changelog: ## Preview unreleased changes
	git-cliff --unreleased --strip header

release-dry-run: ## Show what the next release would look like
	@cz bump --dry-run
	@echo "---"
	@git-cliff --unreleased --strip header

release: ## Bump version, regenerate changelog, commit and tag
	cz bump --yes
	$(post-bump)

release-patch: ## Force a patch release
	cz bump --yes --increment PATCH
	$(post-bump)

release-minor: ## Force a minor release
	cz bump --yes --increment MINOR
	$(post-bump)

release-major: ## Force a major release
	cz bump --yes --increment MAJOR
	$(post-bump)
