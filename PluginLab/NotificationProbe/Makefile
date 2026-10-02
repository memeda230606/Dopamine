ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MMDLabNotification
MMDLabNotification_FILES = Tweak.x
MMDLabNotification_CFLAGS = -fobjc-arc
MMDLabNotification_FRAMEWORKS = Foundation UIKit
MMDLabNotification_LOGOS_DEFAULT_GENERATOR = internal
include $(THEOS_MAKE_PATH)/tweak.mk
