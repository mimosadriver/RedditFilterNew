THEOS_PACKAGE_SCHEME = rootless
export THEOS ?= $(HOME)/theos

# Deployment target — this is the reliable way to set it in Theos.
# Without this it defaults to iOS 9 and every modern UIKit API errors.
export ARCHS = arm64
export TARGET = iphone:clang:latest:15.0
export DEPLOYMENT_TARGET = 15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RedditFilter

RedditFilter_FILES = src/Tweak.x src/FilterManager.m src/SettingsViewController.m
RedditFilter_CFLAGS = -fobjc-arc -I./src -miphoneos-version-min=15.0
RedditFilter_LDFLAGS = -lz
RedditFilter_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
