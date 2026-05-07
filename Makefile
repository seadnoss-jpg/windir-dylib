THEOS_DEVICE_IP ?= 0.0.0.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WindirKeygate

WindirKeygate_FILES = Tweak.x
WindirKeygate_CFLAGS = -fobjc-arc
WindirKeygate_FRAMEWORKS = UIKit Foundation
WindirKeygate_PRIVATE_FRAMEWORKS =

# Target iOS 14+ on arm64
TARGET := iphone:clang:14.0:14.0
ARCHS = arm64

include $(THEOS)/makefiles/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
