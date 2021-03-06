//
//  GPULaplacianFilter.m
//  FilterShowcase
//
//  Created by Zitao Xiong on 4/6/12.
//  Copyright (c) 2012 Cell Phone. All rights reserved.
//

#import "GPULaplacianFilter.h"

NSString *const kGPUImageLaplacianVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 const lowp int GAUSSIAN_SAMPLES = 9;
 
 uniform highp float texelWidthOffset; 
 uniform highp float texelHeightOffset;
 uniform highp float blurSize;
 
 varying highp vec2 textureCoordinate;
 varying highp vec2 blurCoordinates[GAUSSIAN_SAMPLES];
 
 uniform highp float kernelValues[GAUSSIAN_SAMPLES];
 
 varying highp float kernelValuesOutput[GAUSSIAN_SAMPLES];

 varying float strength;
 void main() {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
     
     // Calculate the positions for the blur
     int multiplier = 0;
     highp vec2 blurStep;
//     highp vec2 singleStepOffset = vec2(texelHeightOffset, texelWidthOffset) * blurSize;
     highp vec2 singleStepOffset = vec2(texelHeightOffset, texelWidthOffset) * 1.0;

     
     for (lowp int i = 0; i < GAUSSIAN_SAMPLES; i++) {
         multiplier = (i - ((GAUSSIAN_SAMPLES - 1) / 2));
         // Blur in x (horizontal)
         blurStep = float(multiplier) * singleStepOffset;
         blurCoordinates[i] = inputTextureCoordinate.xy + blurStep;
     }
     
     strength = blurSize;
     
     for (lowp int i = 0; i < GAUSSIAN_SAMPLES; i++) {
         kernelValuesOutput[i] = kernelValues[i];
     }
 }
 );

NSString *const kGPUImageLaplacianFragmentShaderString = SHADER_STRING
(
 uniform sampler2D inputImageTexture;
 
 const lowp int GAUSSIAN_SAMPLES = 9;
 
 varying highp vec2 textureCoordinate;
 varying highp vec2 blurCoordinates[GAUSSIAN_SAMPLES];
 
 varying lowp float strength;
 
 varying highp float kernelValuesOutput[GAUSSIAN_SAMPLES];

 
 void main() {
     lowp vec4 sum = vec4(0.0);
     
     sum += texture2D(inputImageTexture, blurCoordinates[0]) * kernelValuesOutput[0];
     sum += texture2D(inputImageTexture, blurCoordinates[1]) * kernelValuesOutput[1];
     sum += texture2D(inputImageTexture, blurCoordinates[2]) * kernelValuesOutput[2];
     sum += texture2D(inputImageTexture, blurCoordinates[3]) * kernelValuesOutput[3];
     sum += texture2D(inputImageTexture, blurCoordinates[4]) * kernelValuesOutput[4];
     sum += texture2D(inputImageTexture, blurCoordinates[5]) * kernelValuesOutput[5];
     sum += texture2D(inputImageTexture, blurCoordinates[6]) * kernelValuesOutput[6];
     sum += texture2D(inputImageTexture, blurCoordinates[7]) * kernelValuesOutput[7];
     sum += texture2D(inputImageTexture, blurCoordinates[8]) * kernelValuesOutput[8];
     lowp vec4 color = texture2D(inputImageTexture, blurCoordinates[4]);
     
     color = color * (1.0 - strength) + sum * strength;
     gl_FragColor = color;
 }
 );

@implementation GPULaplacianFilter
@synthesize blurSize = _blurSize;
@synthesize imageWidthFactor = _imageWidthFactor; 
@synthesize imageHeightFactor = _imageHeightFactor; 
@synthesize strength = strength_;


- (id) initWithFirstStageVertexShaderFromString:(NSString *)firstStageVertexShaderString 
             firstStageFragmentShaderFromString:(NSString *)firstStageFragmentShaderString 
              secondStageVertexShaderFromString:(NSString *)secondStageVertexShaderString
            secondStageFragmentShaderFromString:(NSString *)secondStageFragmentShaderString {
    
    if (!(self = [super initWithFirstStageVertexShaderFromString:firstStageVertexShaderString ? firstStageVertexShaderString : kGPUImageLaplacianVertexShaderString
                              firstStageFragmentShaderFromString:firstStageFragmentShaderString ? firstStageFragmentShaderString : kGPUImageLaplacianFragmentShaderString
                               secondStageVertexShaderFromString:secondStageVertexShaderString ? secondStageVertexShaderString : kGPUImageLaplacianVertexShaderString
                             secondStageFragmentShaderFromString:secondStageFragmentShaderString ? secondStageFragmentShaderString : kGPUImageLaplacianFragmentShaderString])) {
        return nil;
    }
    
    horizontalBlurSizeUniform = [filterProgram uniformIndex:@"blurSize"];
    horizontalGaussianArrayUniform = [filterProgram uniformIndex:@"gaussianValues"];
    horizontalPassTexelWidthOffsetUniform = [filterProgram uniformIndex:@"texelWidthOffset"];
    horizontalPassTexelHeightOffsetUniform = [filterProgram uniformIndex:@"texelHeightOffset"];
    
    verticalBlurSizeUniform = [secondFilterProgram uniformIndex:@"blurSize"];
    verticalGaussianArrayUniform = [secondFilterProgram uniformIndex:@"gaussianValues"];
    verticalPassTexelWidthOffsetUniform = [secondFilterProgram uniformIndex:@"texelWidthOffset"];
    verticalPassTexelHeightOffsetUniform = [secondFilterProgram uniformIndex:@"texelHeightOffset"];
    
    kernelUniform = [filterProgram uniformIndex:@"kernelValues"];
    self.blurSize = 1.0;
    [self setGaussianValues];
    
    return self;
}

- (id)init;
{
    return [self initWithFirstStageVertexShaderFromString:nil
                       firstStageFragmentShaderFromString:nil
                        secondStageVertexShaderFromString:nil
                      secondStageFragmentShaderFromString:nil];
}

- (void)setupFilterForSize:(CGSize)filterFrameSize;
{
    [GPUImageOpenGLESContext useImageProcessingContext];
    [filterProgram use];
    glUniform1f(horizontalPassTexelWidthOffsetUniform, 1.0 / filterFrameSize.width);
    glUniform1f(horizontalPassTexelHeightOffsetUniform, 0.0);
    
    [secondFilterProgram use];
    glUniform1f(verticalPassTexelWidthOffsetUniform, 0.0);
    glUniform1f(verticalPassTexelHeightOffsetUniform, 1.0 / filterFrameSize.height);
}


#pragma mark Getters and Setters

- (void) setKernel:(GLfloat[]) kernels {
    GLsizei gaussianLength = 9;
    GLfloat gaussians[] = { 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    [GPUImageOpenGLESContext useImageProcessingContext];
    [filterProgram use];
    glUniform1fv(horizontalGaussianArrayUniform, gaussianLength, gaussians);
    glUniform1fv(kernelUniform, gaussianLength, kernels);
    
    [secondFilterProgram use];
    glUniform1fv(verticalGaussianArrayUniform, gaussianLength, gaussians);
    glUniform1fv(kernelUniform, gaussianLength, kernels);
}

- (void) setGaussianValues {

    //GLfloat kernels[] = { 0.0, 1.0, 0, 1, -4, 1, 0, 1, 0 };
//    GLfloat kernels[] = { 0.05, 0.09, 0.12, 0.15, 0.18, 0.15, 0.12, 0.09, 0.05 };
//    GLsizei gaussianLength = 9;
//    GLfloat gaussians[] = { 1, 2, 3, 4, 5, 6, 7, 8, 9 };
//    [GPUImageOpenGLESContext useImageProcessingContext];
//    [filterProgram use];
//    glUniform1fv(horizontalGaussianArrayUniform, gaussianLength, gaussians);
//    glUniform1fv(kernelUniform, gaussianLength, kernels);
//
//    [secondFilterProgram use];
//    glUniform1fv(verticalGaussianArrayUniform, gaussianLength, gaussians);
//    glUniform1fv(kernelUniform, gaussianLength, kernels);
    GLfloat kernel[]  = { 0.05, 0.09, 0.12, 0.15, 0.18, 0.15, 0.12, 0.09, 0.05 };
    [self setKernel: kernel];
}

- (void) setBlurSize:(CGFloat)blurSize {
    _blurSize = blurSize;
    
    [GPUImageOpenGLESContext useImageProcessingContext];
    [filterProgram use];
    glUniform1f(horizontalBlurSizeUniform, _blurSize);
    
    [secondFilterProgram use];
    glUniform1f(verticalBlurSizeUniform, _blurSize);
}
#pragma mark -
#pragma mark Accessors

- (void)setImageWidthFactor:(CGFloat)newValue;
{
    hasOverriddenImageSizeFactor = YES;
    _imageWidthFactor = newValue;
    
    [GPUImageOpenGLESContext useImageProcessingContext];
    [secondFilterProgram use];
    glUniform1f(imageWidthFactorUniform, 1.0 / _imageWidthFactor);
}

- (void)setImageHeightFactor:(CGFloat)newValue;
{
    hasOverriddenImageSizeFactor = YES;
    _imageHeightFactor = newValue;
    
    [GPUImageOpenGLESContext useImageProcessingContext];
    [secondFilterProgram use];
    glUniform1f(imageHeightFactorUniform, 1.0 / _imageHeightFactor);
}

-(void)setStrength:(CGFloat)strength {
    strength_ = strength;
    
}
@end
