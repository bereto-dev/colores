# Version is defined in Resources/Info.plist (CFBundleShortVersionString + CFBundleVersion).
#   make        -> Colores.app (universal)
#   make zip    -> dist/Colores-<version>.zip
# Sparkle (automatic updates) is downloaded once into vendor/ and checked against its SHA-256.
APP     = Colores
BUNDLE  = $(APP).app
EXEC    = $(BUNDLE)/Contents/MacOS/$(APP)
SOURCES = $(wildcard Sources/*.swift)
MIN_OS  = 11.0
VERSION = $(shell /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)

SPARKLE_VERSION = 2.10.0
SPARKLE_SHA256  = c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
SPARKLE_DIR     = vendor/Sparkle-$(SPARKLE_VERSION)
SPARKLE_FW      = $(SPARKLE_DIR)/Sparkle.framework

SWIFTC_FLAGS = -framework Cocoa \
	-F $(SPARKLE_DIR) -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks

# Recent Command Line Tools releases only ship arm64/arm64e slices of the Swift
# runtime-compatibility static libs (libswiftCompatibility56/Concurrency/Packs),
# so linking x86_64 with the default autolinking fails even though this code
# never touches async/await. Disabling that autolinking sidesteps the missing
# libs entirely — full Xcode isn't needed just to get an x86_64 slice.
X86_FLAGS = -disable-autolinking-runtime-compatibility \
	-disable-autolinking-runtime-compatibility-concurrency

.PHONY: all clean run zip

all: $(BUNDLE)

$(SPARKLE_FW):
	@echo "Fetching Sparkle $(SPARKLE_VERSION)..."
	@mkdir -p vendor
	@curl -fsSL -o vendor/Sparkle.tar.xz \
		https://github.com/sparkle-project/Sparkle/releases/download/$(SPARKLE_VERSION)/Sparkle-$(SPARKLE_VERSION).tar.xz
	@echo "$(SPARKLE_SHA256)  vendor/Sparkle.tar.xz" | shasum -a 256 -c - >/dev/null || { echo "Sparkle checksum mismatch"; rm -f vendor/Sparkle.tar.xz; exit 1; }
	@rm -rf $(SPARKLE_DIR) && mkdir -p $(SPARKLE_DIR)
	@tar -xJf vendor/Sparkle.tar.xz -C $(SPARKLE_DIR) && rm -f vendor/Sparkle.tar.xz

$(BUNDLE): $(SOURCES) Resources/Info.plist Resources/AppIcon.icns | $(SPARKLE_FW)
	@rm -rf $(BUNDLE)
	@mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources $(BUNDLE)/Contents/Frameworks
	swiftc $(SOURCES) $(SWIFTC_FLAGS) $(X86_FLAGS) -target x86_64-apple-macosx$(MIN_OS) -o $(EXEC)-x86_64
	swiftc $(SOURCES) $(SWIFTC_FLAGS) -target arm64-apple-macosx$(MIN_OS) -o $(EXEC)-arm64
	lipo -create -output $(EXEC) $(EXEC)-x86_64 $(EXEC)-arm64
	@rm -f $(EXEC)-x86_64 $(EXEC)-arm64
	@cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	@cp Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	@ditto $(SPARKLE_FW) $(BUNDLE)/Contents/Frameworks/Sparkle.framework
	@# Ad-hoc signature, inside out: Sparkle's helpers, then the framework, then the app.
	@for item in $(BUNDLE)/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/*.xpc \
		$(BUNDLE)/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate \
		$(BUNDLE)/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app; do \
		[ -e "$$item" ] && codesign --force --sign - "$$item" >/dev/null; done; true
	@codesign --force --sign - $(BUNDLE)/Contents/Frameworks/Sparkle.framework >/dev/null
	@codesign --force --sign - --identifier com.colores.app $(BUNDLE) >/dev/null
	@echo "✓ Built universal $(BUNDLE) $(VERSION) ($$(lipo -archs $(EXEC)))"

zip: $(BUNDLE)
	@mkdir -p dist
	@rm -f dist/$(APP)-$(VERSION).zip
	@ditto -c -k --sequesterRsrc --keepParent $(BUNDLE) dist/$(APP)-$(VERSION).zip
	@echo "✓ Packaged dist/$(APP)-$(VERSION).zip"

run: all
	open $(BUNDLE)

clean:
	rm -rf $(BUNDLE)
