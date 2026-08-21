DEVICE = fr165
SDK_JAR = $(shell cat ~/.Garmin/ConnectIQ/current-sdk.cfg 2>/dev/null)/bin/monkeybrains.jar
SDK_BIN = $(shell cat ~/.Garmin/ConnectIQ/current-sdk.cfg 2>/dev/null)/bin
DEVKEY = developer.der
OUTPUT = bin/garmin-halo.prg

build:
	xvfb-run -a java -jar $(SDK_JAR) -f monkey.jungle -d $(DEVICE) -o $(OUTPUT) -y $(DEVKEY) -w -l 2

run: build
	xvfb-run -a $(SDK_BIN)/simulator &
	sleep 3
	xvfb-run -a $(SDK_BIN)/monkeydo $(OUTPUT) $(DEVICE)

test:
	xvfb-run -a java -jar $(SDK_JAR) -f monkey.jungle -d $(DEVICE) -o $(OUTPUT) -y $(DEVKEY) -w -l 3 --unit-test
	xvfb-run -a $(SDK_BIN)/simulator > /dev/null 2>&1 &
	sleep 3
	xvfb-run -a $(SDK_BIN)/monkeydo $(OUTPUT) $(DEVICE) -t
	-killall simulator 2>/dev/null || true

test-e2e:
	python3 tests/test_e2e_integration.py

test-lua:
	python3 tests/test_halo_lua.py

release:
	xvfb-run -a java -jar $(SDK_JAR) -e -r -w -o bin/garmin-halo.iq -f monkey.jungle -y $(DEVKEY)

clean:
	rm -rf bin/
