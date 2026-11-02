SWIFT_FILES := $(shell find Sources -name "*.swift")
APP_NAME := mini-satset
APP_BUNDLE := $(APP_NAME).app

.PHONY: all build run app dmg icon clean

all: build

icon:
	@swift Resources/scripts/generate_icon.swift Resources/icon_1024.png
	@chmod +x Resources/scripts/make-icns.sh
	@./Resources/scripts/make-icns.sh

build:
	@mkdir -p bin
	swiftc -O -whole-module-optimization $(SWIFT_FILES) -o bin/$(APP_NAME)
	@echo "Build sukses: bin/$(APP_NAME)"

run: build
	./bin/$(APP_NAME)

app: build
	@if [ ! -f Resources/AppIcon.icns ]; then $(MAKE) icon; fi
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp bin/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/ 2>/dev/null || true
	echo "APPL????" > $(APP_BUNDLE)/Contents/PkgInfo
	chmod +x $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	codesign --force --deep --sign - $(APP_BUNDLE) 2>/dev/null || true
	@echo "App bundle siap: $(APP_BUNDLE)"

dmg: app
	chmod +x Resources/scripts/build-dmg.sh
	./Resources/scripts/build-dmg.sh

clean:
	rm -rf bin $(APP_BUNDLE) dist .build
