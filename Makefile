SWIFT_FILES := $(shell find Sources -name "*.swift")
APP_NAME := mini-satset
APP_BUNDLE := $(APP_NAME).app

.PHONY: all build run app dmg clean

all: build

build:
	@mkdir -p bin
	swiftc $(SWIFT_FILES) -o bin/$(APP_NAME)
	@echo "Build sukses: bin/$(APP_NAME)"

run: build
	./bin/$(APP_NAME)

app: build
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp bin/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	echo "APPL????" > $(APP_BUNDLE)/Contents/PkgInfo
	chmod +x $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@echo "App bundle siap: $(APP_BUNDLE)"

dmg: app
	chmod +x Resources/scripts/build-dmg.sh
	./Resources/scripts/build-dmg.sh

clean:
	rm -rf bin $(APP_BUNDLE) dist .build
