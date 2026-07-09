THEOS_PACKAGE_SCHEME = rootless
THEOS ?= $(HOME)/theos
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RedditFilter

RedditFilter_FILES = src/Tweak.x src/FilterManager.m src/SettingsViewController.m
RedditFilter_CFLAGS = -fobjc-arc -I./src/headers
RedditFilter_LDFLAGS = -lz
RedditFilter_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
