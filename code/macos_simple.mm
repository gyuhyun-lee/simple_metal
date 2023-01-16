#include <Cocoa/Cocoa.h> 
#include <CoreGraphics/CoreGraphics.h> 
#include <mach/mach_time.h> // mach_absolute_time
#include <stdio.h> // printf for debugging purpose
#include <sys/stat.h>
#include <libkern/OSAtomic.h>
#include <pthread.h>
#include <semaphore.h>
#include <Carbon/Carbon.h>
#include <dlfcn.h> // dlsym
#include <metalkit/metalkit.h>
#include <metal/metal.h>

#include <stdint.h>
#include <float.h>

// NOTE(gh) Common type names that I use
// i means signed integer
// u means unsigned integer
// b means boolean
// r and f means floating point number
typedef int8_t i8;
typedef int16_t i16;
typedef int32_t i32;
typedef int64_t i64;
typedef int32_t b32;

typedef uint8_t u8; 
typedef uint16_t u16; 
typedef uint32_t u32;
typedef uint64_t u64;

typedef uintptr_t uintptr;

typedef float r32;
typedef float f32;
typedef double r64;

#undef internal
#undef assert

#define internal static
#define global static
#define local_persist static

#define assert(expression) if(!(expression)) {int *a = 0; *a = 0;}
#define array_count(array) (sizeof(array) / sizeof(array[0]))
#define array_size(array) (sizeof(array))
#define invalid_code_path assert(0)

@interface 
app_delegate : NSObject<NSApplicationDelegate>
@end
@implementation app_delegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [NSApp stop:nil];

    // NOTE(gh) Technique from GLFW, posting an empty event 
    // so that we can put the application to front 
    NSAutoreleasePool* pool = [NSAutoreleasePool new];
    NSEvent* event =
        [NSEvent otherEventWithType: NSApplicationDefined
                 location: NSMakePoint(0, 0)
                 modifierFlags: 0
                 timestamp: 0
                 windowNumber: 0
                 context: nil
                 subtype: 0
                 data1: 0
                 data2: 0];
    [NSApp postEvent: event atStart: YES];
    [pool drain];
}
@end

internal void
metal_render_and_display()
{
}

int main(void)
{
    i32 window_width = 1920;
    i32 window_height = 1080;

    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy :NSApplicationActivationPolicyRegular];
    app_delegate *delegate = [app_delegate new];
    [app setDelegate: delegate];

    NSMenu *app_main_menu = [NSMenu alloc];
    NSMenuItem *menu_item_with_item_name = [NSMenuItem new];
    [app_main_menu addItem : menu_item_with_item_name];
    [NSApp setMainMenu:app_main_menu];

    NSMenu *SubMenuOfMenuItemWithAppName = [NSMenu alloc];
    NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit" 
                                                    action:@selector(terminate:)  // Decides what will happen when the menu is clicked or selected
                                                    keyEquivalent:@"q"];
    [SubMenuOfMenuItemWithAppName addItem:quitMenuItem];
    [menu_item_with_item_name setSubmenu:SubMenuOfMenuItemWithAppName];

    // TODO(gh) When connected to the external display, this should be window_width and window_height
    // but if not, this should be window_width/2 and window_height/2. Turns out it's based on the resolution(or maybe ppi),
    // because when connected to the apple studio display, the application should use the same value as the macbook monitor
    //NSRect window_rect = NSMakeRect(100.0f, 100.0f, (f32)window_width, (f32)window_height);
    f32 window_bottom_left_x = 100.0f;
    f32 window_bottom_left_y = 100.0f;
    NSRect window_rect = NSMakeRect(window_bottom_left_x, window_bottom_left_y, (f32)window_width/2.0f, (f32)window_height/2.0f);

    NSWindow *window = [[NSWindow alloc] initWithContentRect : window_rect
                                        // Apple window styles : https://developer.apple.com/documentation/appkit/nswindow/stylemask
                                        styleMask : NSTitledWindowMask|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable
                                        backing : NSBackingStoreBuffered
                                        defer : NO];

    NSString *app_name = [[NSProcessInfo processInfo] processName];
    [window setTitle:app_name];
    [window makeKeyAndOrderFront:0];
    [window makeKeyWindow];
    [window makeMainWindow];

    // NOTE(gh) Setting up Metal 
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    NSString *name = device.name;
    bool has_unified_memory = device.hasUnifiedMemory;
    u64 max_allocation_size = device.recommendedMaxWorkingSetSize;

    MTKView *view = [[MTKView alloc] initWithFrame : window_rect
                                     device:device];
    CAMetalLayer *metal_layer = (CAMetalLayer *)[view layer];

    [window setContentView:view];
    view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;

    NSError *error;

    const char *metallib_path = "abcd";

    // NOTE(gh) Load a metal library(which is a pre-compiled metal shaders)
    id<MTLLibrary> shader_library = [device newLibraryWithFile: 
                                        [NSString stringWithUTF8String: metallib_path]
                                        error: &error];

    id<MTLFunction> vertex_function = [shader_library newFunctionWithName: @"simple_vertex"];
    id<MTLFunction> fragment_function = [shader_library newFunctionWithName: @"simple_fragment"];

    MTLRenderPipelineDescriptor *pipeline_desc = [[MTLRenderPipelineDescriptor alloc] init];
    pipeline_desc.vertexFunction = vertex_function;
    pipeline_desc.fragmentFunction = fragment_function;
    // NOTE(gh) MTKView already has the color pixel format that we need to use
    pipeline_desc.colorAttachments[0].pixelFormat = view.colorPixelFormat; 

    // NOTE(gh) The official name is Pipeline'State', which actually makes more sense considering 
    // how GPU works with these 'states', but I'll stick to the name without state just for convenience
    id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor: 
                                        pipeline_desc
                                        error:&error];
    // NOTE(gh) Create a command queue. This is what you submit to the GPU.
    // To encode the commands, you first make a command buffer out of this command queue,
    // then make a command encoder that encodes commands into the command buffer.
    // Finally, you commit the command buffer to the command queue.
    // The main reason for this structure is for multi_threaded command encoding
    // (Remeber that the GPU needs to execute commands sequencally, especially when the commands are touching the same memory).
    id<MTLCommandQueue> command_queue = [device newCommandQueue];

    [app activateIgnoringOtherApps:YES];
    [app run];

    while(1)
    {
        @autoreleasepool
        {
            // NOTE(gh) currentDrawable is very similar to swapchain image in Vulkan.
            id<MTLTexture> drawable_texture = view.currentDrawable.texture; 
            if(drawable_texture)
            {
                id<MTLCommandBuffer> command_buffer = [command_queue commandBuffer];

                // NOTE(gh) Renderpass just to render to the currentdrawable is also automatically generated.
                // We can modify the renderpass by making renderpass ourselves and saying that 
                // the 0th color attachment texture = current drawable texture.
                MTLRenderPassDescriptor *renderpass_desc = view.currentRenderPassDescriptor;
                id<MTLRenderCommandEncoder> render_encoder = [command_buffer renderCommandEncoderWithDescriptor: renderpass_desc];

                // NOTE(gh) Not necessary because Metal will automatically use default values for the viewport.
                // Which is why I'm not gonna bother writing setScissorRect
                MTLViewport viewport = {};
                viewport.originX = 0.0f;
                viewport.originY = 0.0f;
                viewport.width = window_width;
                viewport.height = window_height;
                viewport.znear = 0.0f;
                viewport.zfar = 1.0f;
                [render_encoder setViewport: viewport];

                [render_encoder drawPrimitives:
                    MTLPrimitiveTypeTriangle
                    vertexStart: 0
                    vertexCount: 6];

                [render_encoder endEncoding];

                [command_buffer presentDrawable: view.currentDrawable];

                // NOTE(gh) Now we're done with encoding, we can commit the command buffer
                [command_buffer commit];
            }
        }
    }

    return 0;
}
