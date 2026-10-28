list:
	@just -l

test:
	ruby test/test_gem.rb

test-integration:
	ruby test/test_gprism.rb

build:
	gem build gprism.gemspec

install:
	gem install ./gprism-$$(cat VERSION).gem

clean:
	rm -f *.gem
