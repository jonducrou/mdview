.PHONY: build bundle install clean

APP_NAME = MDView
BUNDLE = $(APP_NAME).app
BUILD_DIR = MDView/.build/release

build:
	cd MDView && swift build -c release

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/MDView $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	@echo "Created $(BUNDLE)"

install: bundle
	cp -r $(BUNDLE) /Applications/
	codesign --force --deep --sign - /Applications/$(BUNDLE)
	@echo "Installed to /Applications/$(BUNDLE)"
	@echo "You can now set MDView as default app for .md files"

clean:
	rm -rf $(BUNDLE)
	cd MDView && swift package clean
