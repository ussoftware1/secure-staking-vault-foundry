.PHONY: test build fmt slither clean

build:
	forge build

test:
	forge test -vvv

fmt:
	forge fmt --check

slither:
	slither . --config-file slither.config.json

clean:
	rm -rf out cache broadcast
