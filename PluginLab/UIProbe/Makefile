ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MMDLabUI
MMDLabUI_FILES = Tweak.x
MMDLabUI_CFLAGS = -fobjc-arc
MMDLabUI_FRAMEWORKS = Foundation UIKit
MMDLabUI_LOGOS_DEFAULT_GENERATOR = internal
include $(THEOS_MAKE_PATH)/tweak.mk
