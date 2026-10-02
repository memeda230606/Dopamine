ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MMDLabFile
MMDLabFile_FILES = Tweak.x
MMDLabFile_CFLAGS = -fobjc-arc
MMDLabFile_FRAMEWORKS = Foundation UIKit
MMDLabFile_LOGOS_DEFAULT_GENERATOR = internal
include $(THEOS_MAKE_PATH)/tweak.mk
