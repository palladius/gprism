test:
	ruby test/test_gprism.rb

build:
	@echo "Nothing to build for Ruby script. If converting to Go/Rust later, add build steps here."

install:
	ln -sf $(pwd)/bin/gprism /usr/local/bin/gprism || echo "Please run with sudo or add bin/gprism to your PATH"
