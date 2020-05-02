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
    UIImageView* _hostIcon;
    UILabel* _hostLabel;
    UIImageView* _hostOverlay;
    UIActivityIndicatorView* _hostSpinner;
    id<HostCallback> _callback;
    CGSize _labelSize;
}
static const float REFRESH_CYCLE = 2.0f;

#if TARGET_OS_TV
static const int ITEM_PADDING = 50;
static const int LABEL_DY = 40;
#else
static const int ITEM_PADDING = 0;
static const int LABEL_DY = 20;
#endif

- (id) init {
    self = [super init];
        
#if TARGET_OS_TV
    self.frame = CGRectMake(0, 0, 400, 400);
#else
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.frame = CGRectMake(0, 0, 200, 200);
    } else {
        self.frame = CGRectMake(0, 0, 100, 100);
    }
#endif
    
    _hostIcon = [[UIImageView alloc] initWithFrame:self.frame];
    [_hostIcon setImage:[UIImage imageNamed:@"Computer"]];
    
    self.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.layer.shadowOffset = CGSizeMake(5,8);
    self.layer.shadowOpacity = 0.3;

    [self addTarget:self action:@selector(hostButtonSelected:) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(hostButtonDeselected:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    
    _hostLabel = [[UILabel alloc] init];
    _hostLabel.textColor = [UIColor whiteColor];
    
    _hostOverlay = [[UIImageView alloc] initWithFrame:CGRectMake(self.frame.size.width / 3, _hostIcon.frame.size.height / 4, _hostIcon.frame.size.width / 3, self.frame.size.height / 3)];
    _hostSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [_hostSpinner setFrame:_hostOverlay.frame];
    _hostSpinner.userInteractionEnabled = NO;
    _hostSpinner.hidesWhenStopped = YES;

    [self addSubview:_hostLabel];
    [self addSubview:_hostIcon];
    
#if TARGET_OS_TV
    _hostIcon.clipsToBounds = NO;
    _hostIcon.adjustsImageWhenAncestorFocused = YES;
    _hostIcon.masksFocusEffectToContents = YES;
    
    self.adjustsImageWhenHighlighted = NO;
    
    _hostOverlay.masksFocusEffectToContents = YES;
    _hostOverlay.adjustsImageWhenAncestorFocused = NO;
    
    [_hostIcon.overlayContentView addSubview:_hostOverlay];
    [_hostIcon.overlayContentView addSubview:_hostSpinner];
#else
    [self addSubview:_hostOverlay];
    [self addSubview:_hostSpinner];
    
    if (@available(iOS 13.4.1, *)) {
        // Allow the button style to change when moused over
        self.pointerInteractionEnabled = YES;
    }
#endif
    
    return self;
}

- (void) hostButtonSelected:(id)sender {
    _hostIcon.layer.opacity = 0.5f;
    _hostSpinner.layer.opacity = 0.5f;
    _hostOverlay.layer.opacity = 0.5f;
}
- (void) hostButtonDeselected:(id)sender {
    _hostIcon.layer.opacity = 1.0f;
    _hostSpinner.layer.opacity = 1.0f;
    _hostOverlay.layer.opacity = 1.0f;
}

- (id) initForAddWithCallback:(id<HostCallback>)callback {
    self = [self init];
    _callback = callback;
    
    if (@available(iOS 9.0, tvOS 9.0, *)) {
        [self addTarget:self action:@selector(addClicked) forControlEvents:UIControlEventPrimaryActionTriggered];
    }
    else {
        [self addTarget:self action:@selector(addClicked) forControlEvents:UIControlEventTouchUpInside];
    }
    
    [_hostLabel setText:@"Add Host"];
    [_hostLabel sizeToFit];
    
    [_hostOverlay setImage:[UIImage imageNamed:@"AddOverlayIcon"]];
    
    [self updateBounds];
        
    return self;
}

- (id) initWithComputer:(TemporaryHost*)host andCallback:(id<HostCallback>)callback {
    self = [self init];
    _host = host;
    _callback = callback;
    
    UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(hostLongClicked:)];
    [self addGestureRecognizer:longPressRecognizer];
    
    if (@available(iOS 9.0, tvOS 9.0, *)) {
        [self addTarget:self action:@selector(hostClicked) forControlEvents:UIControlEventPrimaryActionTriggered];
    }
    else {
        [self addTarget:self action:@selector(hostClicked) forControlEvents:UIControlEventTouchUpInside];
    }
    
    [self updateContentsForHost:host];
    [self startUpdateLoop];

    return self;
}

- (void) updateBounds {
    float x = FLT_MAX;
    float y = FLT_MAX;
    float width = 0;
    float height;
    
    float iconX = _hostIcon.frame.origin.x + _hostIcon.frame.size.width / 2;
    _hostLabel.center = CGPointMake(iconX, _hostIcon.frame.origin.y + _hostIcon.frame.size.height + LABEL_DY);
    
    x = MIN(x, _hostIcon.frame.origin.x);
    x = MIN(x, _hostLabel.frame.origin.x);
    
    y = MIN(y, _hostIcon.frame.origin.y);
    y = MIN(y, _hostLabel.frame.origin.y);

    width = MAX(width, _hostIcon.frame.size.width);
    width = MAX(width, _hostLabel.frame.size.width);
    
    height = _hostIcon.frame.size.height +
        _hostLabel.frame.size.height +
        LABEL_DY / 2;
    
    self.bounds = CGRectMake(x - ITEM_PADDING, y - ITEM_PADDING, width + 2 * ITEM_PADDING, height + 2 * ITEM_PADDING);
}

- (void) updateContentsForHost:(TemporaryHost*)host {
    _hostLabel.text = _host.name;
    [_hostLabel sizeToFit];
    
    if (host.state == StateOnline) {
        [_hostSpinner stopAnimating];

        if (host.pairState == PairStateUnpaired) {
            [_hostOverlay setImage:[UIImage imageNamed:@"LockedOverlayIcon"]];
        }
        else {
            [_hostOverlay setImage:nil];
        }
    }
    else if (host.state == StateOffline) {
        [_hostSpinner stopAnimating];
        [_hostOverlay setImage:[UIImage imageNamed:@"ErrorOverlayIcon"]];
    }
    else {
        [_hostSpinner startAnimating];
    }
    
    [self updateBounds];
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

@end
