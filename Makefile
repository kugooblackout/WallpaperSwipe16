TARGET = iphone:clang:latest:15.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WallpaperSwipe16
WallpaperSwipe16_FILES = Tweak.x WSPrefs.m WSOverlayView.m
WallpaperSwipe16_CFLAGS = -fobjc-arc -I.
WallpaperSwipe16_FRAMEWORKS = UIKit Foundation QuartzCore
WallpaperSwipe16_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
