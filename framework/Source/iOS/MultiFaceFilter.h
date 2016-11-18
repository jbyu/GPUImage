#import "GPUImageFilter.h"

@interface MultiFaceFilter<AVCaptureMetadataOutputObjectsDelegate> : GPUImageFilter
{
    NSMutableArray *filters;
    int face_count;
}

@property(readwrite, nonatomic) BOOL mirror;

- (void)addFilter:(GPUImageOutput<GPUImageInput> *)newFilter;

@end
