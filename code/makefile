COMPILER = clang 
#ARCHITECTURE = -arch arm64 #TODO(joon): -arch arm64 makes the code slower? #TODO(joon) -march=armv8+simd causes error?
ARCHITECTURE = -march=armv8+simd 
#cpu ?
MAKEFLAGS += --silent

MAIN_CODE_PATH = ../code
MACOS_BUILD_PATH = ../build
MACOS_APP_NAME = simple.app
MACOS_EXE_PATH = $(MACOS_BUILD_PATH)/$(MACOS_APP_NAME)/Contents/MacOS
MACOS_RESOURCE_PATH = $(MACOS_BUILD_PATH)/$(MACOS_APP_NAME)/Contents/Resources
MACOS_FRAMEWORK = -framework Cocoa -framework CoreFoundation -framework CoreGraphics -framework CoreVideo -framework Metal -framework MetalKit

# -O0 = unoptimized, -O2 = compiler optimized
COMPILER_FLAGS = -g -Wall -O0 -std=c++11 -lstdc++ -lm -pthread
# This is a nightmare.. :(
# to disable warning, prefix the name of the warning with no-
COMPILER_IGNORE_WARNINGS = -Wno-unused-variable -Wno-unused-function -Wno-deprecated-declarations -Wno-writable-strings -Wno-switch -Wno-objc-missing-super-calls -Wno-missing-braces -Wnonportable-include-path -Wno-uninitialized -Wno-nonportable-include-path -Wno-tautological-bitwise-compare -Wno-unused-but-set-variable

all : make_directory make_app compile_main cleanup

make_directory : 
	mkdir -p $(MACOS_BUILD_PATH)

make_app : 
	mkdir -p $(MACOS_BUILD_PATH)/$(MACOS_APP_NAME)
	mkdir -p $(MACOS_BUILD_PATH)/$(MACOS_APP_NAME)/Contents
	mkdir -p $(MACOS_BUILD_PATH)/$(MACOS_APP_NAME)/Contents/Resources
	mkdir -p $(MACOS_BUILD_PATH)/$(MACOS_APP_NAME)/Contents/MacOS

# target:  dependency1 dependency2 ...
#       <tab> command
compile_main : $(MAIN_CODE_PATH)/macos_simple.mm
	$(COMPILER) $(ARCHITECTURE) $(COMPILER_FLAGS) $(COMPILER_IGNORE_WARNINGS) $(MACOS_FRAMEWORK) -o $(MACOS_EXE_PATH)/simple $(MAIN_CODE_PATH)/macos_simple.mm 

#clean all the object files.
cleanup : 
	 rm -rf *.o 
