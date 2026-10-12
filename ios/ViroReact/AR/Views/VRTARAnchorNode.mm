//
//  VRTARNode.mm
//  ViroReact
//
//  Created by Andy Chu on 6/15/17.
//  Copyright © 2017 Viro Media. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "VRTARAnchorNode.h"
#import "VRTARUtils.h"
#import <ARKit/ARKit.h>
#import <ViroKit/VROARScene.h>
#import <ViroKit/VROARSessioniOS.h>

@implementation VRTARAnchorNode

- (std::shared_ptr<VRONode>)createVroNode {
    return std::make_shared<VROARNode>();
}

- (void)setIsAnchored:(BOOL)isAttached {
    _isAnchored = isAttached;
    [self handleAppearanceChange];
}

- (void)setAnchorId:(NSString *)anchorId {
    _anchorId = anchorId;
}

- (BOOL)shouldAppear {
    return [super shouldAppear] && self.isAnchored;
}

- (void)setPauseUpdates:(BOOL)pauseUpdates {
    _pauseUpdates = pauseUpdates;
    std::shared_ptr<VROARNode> arNode = std::dynamic_pointer_cast<VROARNode>([self node]);
    if (arNode) {
        arNode->setPauseUpdates(pauseUpdates);
    }
}

- (ARImageAnchor *)liveImageAnchorFor:(std::shared_ptr<VROARAnchor>)anchor API_AVAILABLE(ios(11.3)) {
    if (!anchor || !self.scene) return nil;

    std::shared_ptr<VROARScene> arScene = std::dynamic_pointer_cast<VROARScene>(self.scene);
    if (!arScene) return nil;
    std::shared_ptr<VROARSession> session = arScene->getARSession();
    if (!session) return nil;

    // ViroKit can be built without RTTI. The iOS AR session is always VROARSessioniOS.
    std::shared_ptr<VROARSessioniOS> sessioniOS = std::static_pointer_cast<VROARSessioniOS>(session);
    ARSession *nativeSession = sessioniOS->getARSession();
    ARFrame *frame = nativeSession.currentFrame;
    if (!frame) return nil;

    NSString *anchorId = [NSString stringWithUTF8String:anchor->getId().c_str()];
    for (ARAnchor *candidate in frame.anchors) {
        if (![candidate isKindOfClass:[ARImageAnchor class]]) continue;
        if ([candidate.identifier.UUIDString isEqualToString:anchorId]) {
            return (ARImageAnchor *)candidate;
        }
    }
    return nil;
}

- (NSDictionary *)eventDictionaryForAnchor:(std::shared_ptr<VROARAnchor>)anchor {
    NSMutableDictionary *dict = [[VRTARUtils createDictionaryFromAnchor:anchor] mutableCopy];
    if (@available(iOS 11.3, *)) {
        ARImageAnchor *imageAnchor = [self liveImageAnchorFor:anchor];
        if (imageAnchor) {
            BOOL tracked = imageAnchor.isTracked;
            dict[@"type"] = @"image";
            dict[@"isTracked"] = @(tracked);
            dict[@"trackingMethod"] = tracked ? @"tracking" : @"lastKnownPose";
        }
    }
    return dict;
}

#pragma mark - VROARNodeDelegateProtocol Implementation
- (void)onARAnchorAttached:(std::shared_ptr<VROARAnchor>) anchor {
    self.isAnchored = true;
    [self handleAppearanceChange];
    if (_onAnchorFoundViro) {
        _onAnchorFoundViro(@{ @"anchorFoundMap" : [self eventDictionaryForAnchor:anchor]});
    }
}

- (void)onARAnchorUpdated:(std::shared_ptr<VROARAnchor>) anchor {
    if (_onAnchorUpdatedViro) {
        _onAnchorUpdatedViro(@{ @"anchorUpdatedMap" : [self eventDictionaryForAnchor:anchor]});
    }
}

- (void)onARAnchorRemoved {
    self.isAnchored = false;
    [self handleAppearanceChange];
    if (_onAnchorRemovedViro) {
        // we don't need to return any args for anchor removed
        _onAnchorRemovedViro(@{});
    }
}

@end
