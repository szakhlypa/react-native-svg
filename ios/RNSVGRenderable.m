/**
 * Copyright (c) 2015-present, Horcrux.
 * All rights reserved.
 *
 * This source code is licensed under the MIT-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RNSVGRenderable.h"
#import "RNSVGPercentageConverter.h"

@implementation RNSVGRenderable
{
    NSMutableDictionary *_originProperties;
    NSArray *_changedList;
    RNSVGPercentageConverter *_widthConverter;
    RNSVGPercentageConverter *_heightConverter;
    CGRect _contextBoundingBox;
    CGRect _renderBoundingBox;
}

- (id)init
{
    if (self = [super init]) {
        _fillOpacity = 1;
        _strokeOpacity = 1;
        _strokeWidth = 1;
    }
    return self;
}

- (void)setFill:(RNSVGBrush *)fill
{
    if (fill == _fill) {
        return;
    }
    [self invalidate];
    _fill = fill;
}

- (void)setFillOpacity:(CGFloat)fillOpacity
{
    if (fillOpacity == _fillOpacity) {
        return;
    }
    [self invalidate];
    _fillOpacity = fillOpacity;
}

- (void)setFillRule:(RNSVGCGFCRule)fillRule
{
    if (fillRule == _fillRule) {
        return;
    }
    [self invalidate];
    _fillRule = fillRule;
}

- (void)setStroke:(RNSVGBrush *)stroke
{
    if (stroke == _stroke) {
        return;
    }
    [self invalidate];
    _stroke = stroke;
}

- (void)setStrokeOpacity:(CGFloat)strokeOpacity
{
    if (strokeOpacity == _strokeOpacity) {
        return;
    }
    [self invalidate];
    _strokeOpacity = strokeOpacity;
}

- (void)setStrokeWidth:(CGFloat)strokeWidth
{
    if (strokeWidth == _strokeWidth) {
        return;
    }
    [self invalidate];
    _strokeWidth = strokeWidth;
}

- (void)setStrokeLinecap:(CGLineCap)strokeLinecap
{
    if (strokeLinecap == _strokeLinecap) {
        return;
    }
    [self invalidate];
    _strokeLinecap = strokeLinecap;
}

- (void)setStrokeJoin:(CGLineJoin)strokeLinejoin
{
    if (strokeLinejoin == _strokeLinejoin) {
        return;
    }
    [self invalidate];
    _strokeLinejoin = strokeLinejoin;
}

- (void)setStrokeMiterlimit:(CGFloat)strokeMiterlimit
{
    if (strokeMiterlimit == _strokeMiterlimit) {
        return;
    }
    [self invalidate];
    _strokeMiterlimit = strokeMiterlimit;
}

- (void)setStrokeDasharray:(RNSVGCGFloatArray)strokeDasharray
{
    if (strokeDasharray.array == _strokeDasharray.array) {
        return;
    }
    if (_strokeDasharray.array) {
        free(_strokeDasharray.array);
    }
    [self invalidate];
    _strokeDasharray = strokeDasharray;
}

- (void)setStrokeDashoffset:(CGFloat)strokeDashoffset
{
    if (strokeDashoffset == _strokeDashoffset) {
        return;
    }
    [self invalidate];
    _strokeDashoffset = strokeDashoffset;
}

- (void)setHitArea:(CGPathRef)hitArea
{
    if (hitArea == _hitArea) {
        return;
    }
    
    CGPathRelease(_hitArea);
    _hitArea = CGPathRetain(CFAutorelease(hitArea));
}

- (void)setPropList:(NSArray<NSString *> *)propList
{
    if (propList == _propList) {
        return;
    }
    _propList = propList;
    self.ownedPropList = [propList mutableCopy];
    [self invalidate];
}

- (void)dealloc
{
    CGPathRelease(_hitArea);
    if (_strokeDasharray.array) {
        free(_strokeDasharray.array);
    }
}

- (void)renderTo:(CGContextRef)context
{
    // This needs to be painted on a layer before being composited.
    CGContextSaveGState(context);
    CGContextConcatCTM(context, self.matrix);
    CGContextSetAlpha(context, self.opacity);
    
    [self beginTransparencyLayer:context];
    [self renderLayerTo:context];
    [self endTransparencyLayer:context];

    CGContextRestoreGState(context);
}

// hitTest delagate
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    return [self hitTest:point withEvent:event withTransform:CGAffineTransformMakeRotation(0)];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event withTransform:(CGAffineTransform)transfrom
{
    if (self.active) {
        if (!event) {
            self.active = NO;
        }
        return self;
    }

    CGPathRef hitArea = CGPathCreateCopyByTransformingPath(self.hitArea, &transfrom);
    BOOL contains = CGPathContainsPoint(hitArea, nil, point, NO);
    CGPathRelease(hitArea);
    if (contains) {
        CGPathRef clipPath = [self getComputedClipPath];
        if (clipPath) {
            return CGPathContainsPoint(clipPath, nil, point, NO) ? self : nil;
        } else {
            return self;
        }
    } else {
        return nil;
    }
}

- (void)setContextBoundingBox:(CGRect)contextBoundingBox
{
    _contextBoundingBox = contextBoundingBox;
    _widthConverter = [[RNSVGPercentageConverter alloc] initWithRelativeAndOffset:contextBoundingBox.size.width
                                                                           offset:0];
    _heightConverter = [[RNSVGPercentageConverter alloc] initWithRelativeAndOffset:contextBoundingBox.size.height
                                                                            offset:0];
}

- (CGRect)getContextBoundingBox
{
    return _contextBoundingBox;
}

- (void)setLayoutBoundingBox:(CGRect)layoutBoundingBox
{
    _renderBoundingBox = layoutBoundingBox;
}

- (CGRect)getLayoutBoundingBox
{
    return _renderBoundingBox;
}

- (CGFloat)getWidthRelatedValue:(NSString *)string
{
    return [_widthConverter stringToFloat:string];
}

- (CGFloat)getHeightRelatedValue:(NSString *)string
{
    return [_heightConverter stringToFloat:string];
}

- (void)mergeProperties:(__kindof RNSVGNode *)target mergeList:(NSArray<NSString *> *)mergeList
{

    [self mergeProperties:target mergeList:mergeList inherited:NO];
}

- (void)mergeProperties:(__kindof RNSVGNode *)target mergeList:(NSArray<NSString *> *)mergeList inherited:(BOOL)inherited
{
    if (mergeList.count == 0) {
        return;
    }
    
    self.ownedPropList = [self.propList mutableCopy];
    
    if (!inherited) {
        _originProperties = [[NSMutableDictionary alloc] init];
        _changedList = mergeList;
    }
    
    for (NSString *key in mergeList) {
        if (inherited) {
            [self inheritProperty:target propName:key];
        } else {
            [_originProperties setValue:[self valueForKey:key] forKey:key];
            [self setValue:[target valueForKey:key] forKey:key];
        }
    }
}

- (void)resetProperties
{
    if (_changedList) {
        for (NSString *key in _changedList) {
            [self setValue:[_originProperties valueForKey:key] forKey:key];
        }
    }
    _changedList = nil;
}

- (void)inheritProperty:(__kindof RNSVGNode *)parent propName:(NSString *)propName
{
    if (![self.ownedPropList containsObject:propName]) {
        // add prop to props
        [self.ownedPropList addObject:propName];
        [self setValue:[parent valueForKey:propName] forKey:propName];
    }
}

- (void)renderLayerTo:(CGContextRef)context
{
    // abstract
}

@end
