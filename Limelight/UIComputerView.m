//
//  UIComputerView.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/22/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "UIComputerView.h"

@implementation UIComputerView {
    TemporaryHost* _host;
    UIButton* _hostButton;
    UILabel* _hostLabel;
    UIImageView* _hostOverlay;
    id<HostCallback> _callback;
    CGSize _labelSize;
}
static const float REFRESH_CYCLE = 2.0f;

#if TARGET_OS_TV
static const int LABEL_DY = 40;
#else
static const int LABEL_DY = 20;
#endif

- (id) init {
    self = [super init];
    _hostButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_hostButton setContentEdgeInsets:UIEdgeInsetsMake(0, 4, 0, 4)];
    [_hostButton setBackgroundImage:[UIImage imageNamed:@"Computer"] forState:UIControlStateNormal];
    [_hostButton sizeToFit];
    
    _hostButton.layer.shadowColor = [[UIColor blackColor] CGColor];
    _hostButton.layer.shadowOffset = CGSizeMake(5,8);
    _hostButton.layer.shadowOpacity = 0.3;
    
    _hostLabel = [[UILabel alloc] init];
#if !TARGET_OS_TV
    _hostLabel.textColor = [UIColor whiteColor];
#endif
    
    _hostOverlay = [[UIImageView alloc] initWithFrame:CGRectMake(_hostButton.frame.size.width / 3, _hostButton.frame.size.height / 4, _hostButton.frame.size.width / 3, _hostButton.frame.size.height / 3)];

    [self addSubview:_hostButton];
    [self addSubview:_hostLabel];
    [self addSubview:_hostOverlay];
    
    return self;
}

- (id) initForAddWithCallback:(id<HostCallback>)callback {
    self = [self init];
    _callback = callback;
    
    if (@available(iOS 9.0, tvOS 9.0, *)) {
        [_hostButton addTarget:self action:@selector(addClicked) forControlEvents:UIControlEventPrimaryActionTriggered];
    }
    else {
        [_hostButton addTarget:self action:@selector(addClicked) forControlEvents:UIControlEventTouchUpInside];
    }
    
    [_hostLabel setText:@"Add Host"];
    [_hostLabel sizeToFit];
    
    float x = _hostButton.frame.origin.x + _hostButton.frame.size.width / 2;
    _hostLabel.center = CGPointMake(x, _hostButton.frame.origin.y + _hostButton.frame.size.height + LABEL_DY);
    
    [_hostOverlay setImage:[UIImage imageNamed:@"AddOverlayIcon"]];
    
    [self updateBounds];
        
    return self;
}

- (id) initWithComputer:(TemporaryHost*)host andCallback:(id<HostCallback>)callback {
    self = [self init];
    _host = host;
    _callback = callback;
    
    UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(hostLongClicked:)];
    [_hostButton addGestureRecognizer:longPressRecognizer];
    
    if (@available(iOS 9.0, tvOS 9.0, *)) {
        [_hostButton addTarget:self action:@selector(hostClicked) forControlEvents:UIControlEventPrimaryActionTriggered];
    }
    else {
        [_hostButton addTarget:self action:@selector(hostClicked) forControlEvents:UIControlEventTouchUpInside];
    }
    
    [self updateContentsForHost:host];
    [self updateBounds];
    [self startUpdateLoop];

    return self;
}

- (void) updateBounds {
    float x = FLT_MAX;
    float y = FLT_MAX;
    float width = 0;
    float height;
    
    x = MIN(x, _hostButton.frame.origin.x);
    x = MIN(x, _hostLabel.frame.origin.x);
    
    y = MIN(y, _hostButton.frame.origin.y);
    y = MIN(y, _hostLabel.frame.origin.y);

    width = MAX(width, _hostButton.frame.size.width);
    width = MAX(width, _hostLabel.frame.size.width);
    
    height = _hostButton.frame.size.height +
        _hostLabel.frame.size.height +
        LABEL_DY / 2;
    
    self.bounds = CGRectMake(x, y, width, height);
    self.frame = CGRectMake(x, y, width, height);
}

- (void) updateContentsForHost:(TemporaryHost*)host {
    _hostLabel.text = _host.name;
    [_hostLabel sizeToFit];
    
    if (host.state == StateOnline) {
        if (host.pairState == PairStateUnpaired) {
            [_hostOverlay setImage:[UIImage imageNamed:@"LockedOverlayIcon"]];
        }
        else {
            [_hostOverlay setImage:nil];
        }
    }
    else if (host.state == StateOffline) {
        [_hostOverlay setImage:[UIImage imageNamed:@"ErrorOverlayIcon"]];
    }
    else {
        [_hostOverlay setImage:[UIImage imageNamed:@"UpdatingOverlayIcon"]];
    }
    
    float x = _hostButton.frame.origin.x + _hostButton.frame.size.width / 2;
    _hostLabel.center = CGPointMake(x, _hostButton.frame.origin.y + _hostButton.frame.size.height + LABEL_DY);
}

- (void) startUpdateLoop {
    [self performSelector:@selector(updateLoop) withObject:self afterDelay:REFRESH_CYCLE];
}

- (void) updateLoop {
    [self updateContentsForHost:_host];
    
    // Stop updating when we detach from our parent view
    if (self.superview != nil) {
        [self performSelector:@selector(updateLoop) withObject:self afterDelay:REFRESH_CYCLE];
    }
}

- (void) hostLongClicked:(UILongPressGestureRecognizer*)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [_callback hostLongClicked:_host view:self];
    }
}

- (void) hostClicked {
    [_callback hostClicked:_host view:self];
}

- (void) addClicked {
    [_callback addHostClicked];
}

#if TARGET_OS_TV
- (void) didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    UIButton *previousButton = (UIButton *)context.previouslyFocusedItem;
    UIButton *nextButton = (UIButton *) context.nextFocusedItem;
    
    previousButton.layer.shadowColor = [[UIColor blackColor] CGColor];
    nextButton.layer.shadowColor = [[UIColor greenColor] CGColor];
}
#endif

@end
