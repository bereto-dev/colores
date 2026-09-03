APP     = Colores
BUNDLE  = $(APP).app
EXEC    = $(BUNDLE)/Contents/MacOS/$(APP)
SOURCES = $(wildcard Sources/*.swift)
MIN_OS  = 11.0

.PHONY: all clean run

all: $(BUNDLE)

$(BUNDLE): $(SOURCES) Resources/Info.plist Resources/AppIcon.icns
	@mkdir -p $(BUNDLE)/Contents/MacOS
	@mkdir -p $(BUNDLE)/Contents/Resources
	# Recent Command Line Tools releases only ship arm64/arm64e slices of the Swift
	# runtime-compatibility static libs (libswiftCompatibility56/Concurrency/Packs),
	# so linking x86_64 with the default autolinking fails even though this code
	# never touches async/await. Disabling that autolinking sidesteps the missing
	# libs entirely — full Xcode isn't needed just to get an x86_64 slice.
	swiftc $(SOURCES) \
		-framework Cocoa \
		-target x86_64-apple-macosx$(MIN_OS) \
		-disable-autolinking-runtime-compatibility \
		-disable-autolinking-runtime-compatibility-concurrency \
		-o $(EXEC)-x86_64
	swiftc $(SOURCES) \
		-framework Cocoa \
		-target arm64-apple-macosx$(MIN_OS) \
		-o $(EXEC)-arm64
	lipo -create -output $(EXEC) $(EXEC)-x86_64 $(EXEC)-arm64
	@rm -f $(EXEC)-x86_64 $(EXEC)-arm64
	@cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	@cp Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	@echo "✓ Built universal $(BUNDLE) (x86_64 + arm64)"

run: all
	open $(BUNDLE)

clean:
	rm -rf $(BUNDLE)
