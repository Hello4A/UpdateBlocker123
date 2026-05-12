ARCHS = arm64
TARGET := iphone:clang:latest:13.0
INSTALL_TARGET_PROCESSES = Runner

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = UpdateBlocker123
UpdateBlocker123_FILES = Tweak.xm
UpdateBlocker123_CFLAGS = -fobjc-arc
UpdateBlocker123_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
