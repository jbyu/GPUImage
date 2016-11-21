#import "GPUImageFilter.h"

@interface MultiFaceFilter<AVCaptureMetadataOutputObjectsDelegate> : GPUImageFilter
{
    NSMutableArray *filters;
    NSUInteger face_count;
}

@property(readwrite, nonatomic) BOOL mirror;

- (void)addFilter:(GPUImageOutput<GPUImageInput> *)newFilter;

@end
