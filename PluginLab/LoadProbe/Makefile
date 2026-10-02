ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MMDLabLoad
MMDLabLoad_FILES = Tweak.x
MMDLabLoad_CFLAGS = -fobjc-arc
MMDLabLoad_FRAMEWORKS = Foundation UIKit
MMDLabLoad_LOGOS_DEFAULT_GENERATOR = internal
include $(THEOS_MAKE_PATH)/tweak.mk
