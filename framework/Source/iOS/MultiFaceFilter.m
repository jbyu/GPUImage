#import "MultiFaceFilter.h"
#import <AVFoundation/AVFoundation.h>

@implementation MultiFaceFilter

@synthesize mirror;

#pragma mark -
#pragma mark Initialization and teardown


#define DEGREES_TO_RADIANS(x) (M_PI * x / 180.0)
const int MAXIMUM_FACES = 8;
CGPoint faceVertices[8*MAXIMUM_FACES];
CGAffineTransform matrix;

- (id)init;
{
    if (!(self = [super init]))
    {
		return nil;
    }
    
    filters = [[NSMutableArray alloc] init];
    
    CGAffineTransform rotate = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(-90));
    rotate.ty = 1;
    CGAffineTransform mapping = CGAffineTransformMake(-2, 0, 0, -2, 1, 1);
    
    matrix = CGAffineTransformConcat(rotate,mapping);
    face_count = 0;

    return self;
}

- (void)addFilter:(GPUImageOutput<GPUImageInput> *)newFilter;
{
    [filters addObject:newFilter];
}

#pragma mark AVCaptureMetadataOutputObjectsDelegate

- (CGPoint)rotatedTexture:(CGPoint)pointToRotate forRotation:(GPUImageRotationMode)rotation;
{
    CGPoint rotatedPoint;
    switch(rotation)
    {
        default:
        case kGPUImageRotateRight: return pointToRotate;
        case kGPUImageNoRotation: return [self rotatedPoint:pointToRotate forRotation:kGPUImageRotateLeft];
        case kGPUImageRotateLeft: return [self rotatedPoint:pointToRotate forRotation:kGPUImageRotate180];
        case kGPUImageRotate180: return [self rotatedPoint:pointToRotate forRotation:kGPUImageRotateRight];
        case kGPUImageRotateRightFlipVertical: return [self rotatedPoint:pointToRotate forRotation:kGPUImageFlipVertical];
        case kGPUImageRotateRightFlipHorizontal: return [self rotatedPoint:pointToRotate forRotation:kGPUImageFlipHorizonal];
/*
        case kGPUImageFlipHorizonal:
        {
            rotatedPoint.x = 1.0 - pointToRotate.x;
            rotatedPoint.y = pointToRotate.y;
        }; break;
        case kGPUImageFlipVertical:
        {
            rotatedPoint.x = pointToRotate.x;
            rotatedPoint.y = 1.0 - pointToRotate.y;
        }; break;
 */
    }
    
    return rotatedPoint;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    face_count = [metadataObjects count];
    if (MAXIMUM_FACES < face_count)
        face_count = MAXIMUM_FACES;
    
    for (int i = 0; i < face_count; ++i) {
        //NSLog( @"[metadataObjects count] = %d", [metadataObjects count] );
        AVMetadataFaceObject *face = [metadataObjects objectAtIndex:i];
        CGRect r = [face bounds];
        
        if (mirror) {
            r.origin.y = 1 - r.origin.y;
            r.size.height = -r.size.height;
        }
        int idx = i * 8;
        CGPoint pt = r.origin;
        faceVertices[idx+0] = CGPointApplyAffineTransform(pt, matrix);
        faceVertices[idx+4] = [self rotatedTexture:pt forRotation:inputRotation];
        
        pt.x = r.origin.x + r.size.width;
        pt.y = r.origin.y;
        faceVertices[idx+1] = CGPointApplyAffineTransform(pt, matrix);
        faceVertices[idx+5] = [self rotatedTexture:pt forRotation:inputRotation];

        pt.x = r.origin.x;
        pt.y = r.origin.y + r.size.height;
        faceVertices[idx+2] = CGPointApplyAffineTransform(pt, matrix);
        faceVertices[idx+6] = [self rotatedTexture:pt forRotation:inputRotation];

        pt.x = r.origin.x + r.size.width;
        pt.y = r.origin.y + r.size.height;
        faceVertices[idx+3] = CGPointApplyAffineTransform(pt, matrix);
        faceVertices[idx+7] = [self rotatedTexture:pt forRotation:inputRotation];
    }
}

#pragma mark -

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
{
    [super setInputSize:newSize atIndex:textureIndex];
    
    for (GPUImageFilter *currentFilter in filters)
    {
        [currentFilter setInputSize:newSize atIndex:textureIndex];
    }
}

#pragma mark -
#pragma mark GPUImageInput

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;
{
    if (self.preventRendering)
    {
        [firstInputFramebuffer unlock];
        return;
    }
    
    [GPUImageContext setActiveShaderProgram:filterProgram];
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];
    if (usingNextFrameForImageCapture)
    {
        [outputFramebuffer lock];
    }
    
    [self setUniformsForProgramAtIndex:0];
    
    glClearColor(backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    
    glUniform1i(filterInputTextureUniform, 2);
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    for (GPUImageFilter *currentFilter in filters)
    {
        for (int i = 0; i < face_count; ++i) {
            CGPoint *ptr = (faceVertices + i * 8);
            [currentFilter draw:(GLfloat*)ptr textureCoordinates:(GLfloat*)(ptr+4)];
        }
    }
    
    [firstInputFramebuffer unlock];
    
    if (usingNextFrameForImageCapture)
    {
        dispatch_semaphore_signal(imageCaptureSemaphore);
    }
}

@end
