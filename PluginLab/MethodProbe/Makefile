ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MMDLabMethod
MMDLabMethod_FILES = Tweak.x
MMDLabMethod_CFLAGS = -fobjc-arc
MMDLabMethod_FRAMEWORKS = Foundation UIKit
MMDLabMethod_LOGOS_DEFAULT_GENERATOR = internal
include $(THEOS_MAKE_PATH)/tweak.mk
