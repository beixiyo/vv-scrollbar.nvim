NVIM ?= nvim
TEST_FILES := $(sort $(wildcard tests/test_*.lua))

.PHONY: test

test:
	@set -e; \
	for test_file in $(TEST_FILES); do \
		$(NVIM) --headless -u NONE -l "$$test_file"; \
	done
