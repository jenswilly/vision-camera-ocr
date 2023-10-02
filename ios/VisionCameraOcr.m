#import <Foundation/Foundation.h>

#import "VisionCameraOcr.h"
#if defined __has_include && __has_include("VisionCameraOcr-Swift.h")
#import "VisionCameraOcr-Swift.h"
#else
#import <VisionCameraOcr/VisionCameraOcr-Swift.h>
#endif

@implementation RegisterPluginsOcr

+ (void) load {
	[FrameProcessorPluginRegistry addFrameProcessorPlugin:@"scanOCR"
										  withInitializer:^FrameProcessorPlugin*(NSDictionary* options) {
		return [[OCRFrameProcessorPlugin alloc] init];
	}];
	NSLog(@"📷 Plugin registered: scanOCR");
}

@end
