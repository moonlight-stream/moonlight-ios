//
//  KeyboardOverlayView.m
//  Moonlight
//
//  虚拟键盘覆盖层实现。
//  提供 19 列 x 6 行的 US QWERTY 键盘布局，支持修饰键（Shift/Ctrl/Alt/CapsLock）
//  的切换状态管理，以及通过 Limelight 协议向远程主机发送 Windows VK 按键事件。
//

#import "KeyboardOverlayView.h"
#include <Limelight.h>

#pragma mark - 按键定义结构体

/// 单个按键的定义
typedef struct {
    const char *label;        // 按键上显示的文字
    const char *shiftLabel;   // Shift 状态下显示的文字（NULL 表示与 label 相同）
    short vkCode;             // Windows 虚拟键码
    int columnSpan;           // 该键占据的列数
} KeyDef;

#pragma mark - 常量定义

// 修饰键标记位，用于区分修饰键和普通键
// 存储在 UIButton.tag 中，高位标记修饰键，低位存储 VK code
static const NSInteger TAG_MODIFIER_BIT = 0x10000;

// 键盘网格列数
static const int TOTAL_COLUMNS = 19;

// 按键间距（像素）
static const CGFloat KEY_GAP = 2.0;

// 键盘底部边距
static const CGFloat BOTTOM_MARGIN = 20.0;

// 动画滑入偏移量
static const CGFloat SLIDE_OFFSET = 300.0;

#pragma mark - 键盘布局数据

// ============================================================
// 第 0 行: ESC, F1-F12 (13 个键)
// ============================================================
static const KeyDef kRow0[] = {
    {"ESC",  NULL, 0x1B, 1},
    {"F1",   NULL, 0x70, 1},
    {"F2",   NULL, 0x71, 1},
    {"F3",   NULL, 0x72, 1},
    {"F4",   NULL, 0x73, 1},
    {"F5",   NULL, 0x74, 1},
    {"F6",   NULL, 0x75, 1},
    {"F7",   NULL, 0x76, 1},
    {"F8",   NULL, 0x77, 1},
    {"F9",   NULL, 0x78, 1},
    {"F10",  NULL, 0x79, 1},
    {"F11",  NULL, 0x7A, 1},
    {"F12",  NULL, 0x7B, 1},
};
static const int kRow0Count = sizeof(kRow0) / sizeof(kRow0[0]);

// ============================================================
// 第 1 行: ` 1 2 3 4 5 6 7 8 9 0 - = Backspace(2列) Ins Home PgUp
// ============================================================
static const KeyDef kRow1[] = {
    {"`",    "~",  0xC0, 1},
    {"1",    "!",  0x31, 1},
    {"2",    "@",  0x32, 1},
    {"3",    "#",  0x33, 1},
    {"4",    "$",  0x34, 1},
    {"5",    "%",  0x35, 1},
    {"6",    "^",  0x36, 1},
    {"7",    "&",  0x37, 1},
    {"8",    "*",  0x38, 1},
    {"9",    "(",  0x39, 1},
    {"0",    ")",  0x30, 1},
    {"-",    "_",  0xBD, 1},
    {"=",    "+",  0xBB, 1},
    {"Bksp", NULL, 0x08, 2},
    {"Ins",  NULL, 0x2D, 1},
    {"Home", NULL, 0x24, 1},
    {"PgUp", NULL, 0x21, 1},
};
static const int kRow1Count = sizeof(kRow1) / sizeof(kRow1[0]);

// ============================================================
// 第 2 行: Tab(2列) Q W E R T Y U I O P [ ] \ Del End PgDn
// ============================================================
static const KeyDef kRow2[] = {
    {"Tab",  NULL, 0x09, 2},
    {"Q",    NULL, 0x51, 1},
    {"W",    NULL, 0x57, 1},
    {"E",    NULL, 0x45, 1},
    {"R",    NULL, 0x52, 1},
    {"T",    NULL, 0x54, 1},
    {"Y",    NULL, 0x59, 1},
    {"U",    NULL, 0x55, 1},
    {"I",    NULL, 0x49, 1},
    {"O",    NULL, 0x4F, 1},
    {"P",    NULL, 0x50, 1},
    {"[",    "{",  0xDB, 1},
    {"]",    "}",  0xDD, 1},
    {"\\",   "|",  0xDC, 1},
    {"Del",  NULL, 0x2E, 1},
    {"End",  NULL, 0x23, 1},
    {"PgDn", NULL, 0x22, 1},
};
static const int kRow2Count = sizeof(kRow2) / sizeof(kRow2[0]);

// ============================================================
// 第 3 行: CapsLock(2列) A S D F G H J K L ; ' Enter(3列)
// ============================================================
static const KeyDef kRow3[] = {
    {"Caps", NULL, 0x14, 2},
    {"A",    NULL, 0x41, 1},
    {"S",    NULL, 0x53, 1},
    {"D",    NULL, 0x44, 1},
    {"F",    NULL, 0x46, 1},
    {"G",    NULL, 0x47, 1},
    {"H",    NULL, 0x48, 1},
    {"J",    NULL, 0x4A, 1},
    {"K",    NULL, 0x4B, 1},
    {"L",    NULL, 0x4C, 1},
    {";",    ":",  0xBA, 1},
    {"'",    "\"", 0xDE, 1},
    {"Enter",NULL, 0x0D, 3},
};
static const int kRow3Count = sizeof(kRow3) / sizeof(kRow3[0]);

// ============================================================
// 第 4 行: Shift(3列) Z X C V B N M , . / Shift(2列) Up
// ============================================================
static const KeyDef kRow4[] = {
    {"Shift",NULL, 0x10, 3},
    {"Z",    NULL, 0x5A, 1},
    {"X",    NULL, 0x58, 1},
    {"C",    NULL, 0x43, 1},
    {"V",    NULL, 0x56, 1},
    {"B",    NULL, 0x42, 1},
    {"N",    NULL, 0x4E, 1},
    {"M",    NULL, 0x4D, 1},
    {",",    "<",  0xBC, 1},
    {".",    ">",  0xBE, 1},
    {"/",    "?",  0xBF, 1},
    {"Shift",NULL, 0x10, 2},
    {"\xE2\x86\x91", NULL, 0x26, 1},  // Up arrow (UTF-8)
};
static const int kRow4Count = sizeof(kRow4) / sizeof(kRow4[0]);

// ============================================================
// 第 5 行: Ctrl(2列) Win Alt(2列) Space(7列) Alt(2列) Ctrl(2列) Left Down Right
// ============================================================
static const KeyDef kRow5[] = {
    {"Ctrl", NULL, 0x11, 2},
    {"Win",  NULL, 0x5B, 1},
    {"Alt",  NULL, 0x12, 2},
    {" ",    NULL, 0x20, 7},
    {"Alt",  NULL, 0x12, 2},
    {"Ctrl", NULL, 0x11, 2},
    {"\xE2\x86\x90", NULL, 0x25, 1},  // Left arrow
    {"\xE2\x86\x93", NULL, 0x28, 1},  // Down arrow
    {"\xE2\x86\x92", NULL, 0x27, 1},  // Right arrow
};
static const int kRow5Count = sizeof(kRow5) / sizeof(kRow5[0]);

#pragma mark - KeyboardOverlayView 实现

@interface KeyboardOverlayView ()

/// 内部可写的可见状态
@property (nonatomic, readwrite) BOOL isVisible;

/// 修饰键状态
@property (nonatomic, assign) BOOL shiftActive;
@property (nonatomic, assign) BOOL ctrlActive;
@property (nonatomic, assign) BOOL altActive;
@property (nonatomic, assign) BOOL capsLockActive;

/// 键盘容器视图（用于布局所有按键行）
@property (nonatomic, strong) UIView *keyboardContainer;

/// 所有按键按钮的数组（用于更新显示文字）
@property (nonatomic, strong) NSMutableArray<UIButton *> *allKeyButtons;

#if TARGET_OS_TV
/// 第一个按键按钮（用于焦点引擎的初始焦点）
@property (nonatomic, weak) UIButton *firstKeyButton;
#endif

@end

@implementation KeyboardOverlayView

#pragma mark - 初始化

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupView];
    }
    return self;
}

/// 初始化视图：设置背景、创建键盘容器和所有按键
- (void)setupView {
    // 半透明黑色背景覆盖全屏
    self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    self.hidden = YES;
    self.isVisible = NO;

    _allKeyButtons = [NSMutableArray array];

    // 创建键盘容器
    _keyboardContainer = [[UIView alloc] init];
    _keyboardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_keyboardContainer];

    // 构建键盘布局
    [self buildKeyboardLayout];

    // 设置键盘容器的约束：水平居中，底部对齐，左右有间距
    [NSLayoutConstraint activateConstraints:@[
        [_keyboardContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:KEY_GAP],
        [_keyboardContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-KEY_GAP],
        [_keyboardContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-BOTTOM_MARGIN],
    ]];
}

#pragma mark - 键盘布局构建

/// 构建完整的键盘布局（6 行按键）
- (void)buildKeyboardLayout {
    // 所有行的定义数据
    const KeyDef *rows[] = {kRow0, kRow1, kRow2, kRow3, kRow4, kRow5};
    const int rowCounts[] = {kRow0Count, kRow1Count, kRow2Count, kRow3Count, kRow4Count, kRow5Count};
    int totalRows = sizeof(rows) / sizeof(rows[0]);

    CGFloat rowHeight = [self rowHeight];

    // 上一行视图，用于链式约束
    UIView *previousRowView = nil;

    for (int rowIndex = 0; rowIndex < totalRows; rowIndex++) {
        UIView *rowView = [self createRowViewWithKeys:rows[rowIndex]
                                             keyCount:rowCounts[rowIndex]
                                            rowHeight:rowHeight];
        [_keyboardContainer addSubview:rowView];

        // 设置行视图约束
        [NSLayoutConstraint activateConstraints:@[
            [rowView.leadingAnchor constraintEqualToAnchor:_keyboardContainer.leadingAnchor],
            [rowView.trailingAnchor constraintEqualToAnchor:_keyboardContainer.trailingAnchor],
            [rowView.heightAnchor constraintEqualToConstant:rowHeight],
        ]];

        if (previousRowView == nil) {
            // 第一行：顶部对齐容器
            [rowView.topAnchor constraintEqualToAnchor:_keyboardContainer.topAnchor].active = YES;
        } else {
            // 后续行：紧跟上一行底部，间距为 KEY_GAP
            [rowView.topAnchor constraintEqualToAnchor:previousRowView.bottomAnchor constant:KEY_GAP].active = YES;
        }

        previousRowView = rowView;
    }

    // 最后一行底部对齐容器
    if (previousRowView) {
        [previousRowView.bottomAnchor constraintEqualToAnchor:_keyboardContainer.bottomAnchor].active = YES;
    }
}

/// 创建单行按键视图
/// @param keys 该行的按键定义数组
/// @param keyCount 按键数量
/// @param rowHeight 行高
/// @return 包含所有按键的行视图
- (UIView *)createRowViewWithKeys:(const KeyDef *)keys
                         keyCount:(int)keyCount
                        rowHeight:(CGFloat)rowHeight {
    UIView *rowView = [[UIView alloc] init];
    rowView.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *previousButton = nil;

    for (int i = 0; i < keyCount; i++) {
        const KeyDef *keyDef = &keys[i];
        UIButton *button = [self createButtonForKey:keyDef];
        [rowView addSubview:button];

        // 垂直约束：充满行高
        [NSLayoutConstraint activateConstraints:@[
            [button.topAnchor constraintEqualToAnchor:rowView.topAnchor],
            [button.bottomAnchor constraintEqualToAnchor:rowView.bottomAnchor],
        ]];

        if (previousButton == nil) {
            // 第一个按键：左对齐
            [button.leadingAnchor constraintEqualToAnchor:rowView.leadingAnchor].active = YES;
        } else {
            // 后续按键：紧跟上一个按键右侧，间距为 KEY_GAP
            [button.leadingAnchor constraintEqualToAnchor:previousButton.trailingAnchor constant:KEY_GAP].active = YES;
        }

        // 宽度按比例分配：
        // 按键宽度 = (行总宽度 - 间距) * (columnSpan / TOTAL_COLUMNS)
        // 使用 multiplier 来实现比例宽度
        // button.width = rowView.width * (columnSpan / TOTAL_COLUMNS) - 间距补偿
        //
        // 精确公式：每个按键的宽度 = (总宽度 - (keyCount-1)*gap) * span/totalColumns
        // 但用 Auto Layout 的 multiplier 近似处理：
        // width = rowView.width * span/TOTAL_COLUMNS - gap_adjustment
        //
        // 为了简化，使用比例约束并减去间距
        CGFloat spanRatio = (CGFloat)keyDef->columnSpan / (CGFloat)TOTAL_COLUMNS;
        NSLayoutConstraint *widthConstraint = [NSLayoutConstraint
            constraintWithItem:button
                     attribute:NSLayoutAttributeWidth
                     relatedBy:NSLayoutRelationEqual
                        toItem:rowView
                     attribute:NSLayoutAttributeWidth
                    multiplier:spanRatio
                      constant:-(KEY_GAP * (CGFloat)(keyCount - 1) * spanRatio)];
        widthConstraint.active = YES;

        previousButton = button;

#if TARGET_OS_TV
        // 记录第一个按键用于焦点引擎
        if (_firstKeyButton == nil) {
            _firstKeyButton = button;
        }
#endif
    }

    return rowView;
}

/// 为单个按键创建 UIButton
/// @param keyDef 按键定义
/// @return 配置好的按键按钮
- (UIButton *)createButtonForKey:(const KeyDef *)keyDef {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;

    // 设置显示文字
    NSString *label = [NSString stringWithUTF8String:keyDef->label];
    [button setTitle:label forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    // 存储 shiftLabel 到 accessibilityValue 以便后续读取
    // 同时将原始 label 存储到 accessibilityIdentifier，以便 Shift 切换时恢复
    if (keyDef->shiftLabel != NULL) {
        button.accessibilityValue = [NSString stringWithUTF8String:keyDef->shiftLabel];
        button.accessibilityIdentifier = label;
    }

    // 视觉样式
    button.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.8];
    button.layer.cornerRadius = 4.0;
    button.clipsToBounds = YES;
    button.titleLabel.font = [UIFont systemFontOfSize:[self fontSize]];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.5;

    // 设置 tag：高位标记修饰键，低位存储 VK code
    BOOL isModifier = [self isModifierVKCode:keyDef->vkCode];
    button.tag = (isModifier ? TAG_MODIFIER_BIT : 0) | (keyDef->vkCode & 0xFFFF);

    // 绑定点击事件（UIControlEventPrimaryActionTriggered 兼容 iOS 和 tvOS）
    [button addTarget:self
               action:@selector(keyButtonPressed:)
     forControlEvents:UIControlEventPrimaryActionTriggered];

    [_allKeyButtons addObject:button];

    return button;
}

#pragma mark - 平台相关参数

/// 获取行高（tvOS 较大以适应遥控器操作）
- (CGFloat)rowHeight {
#if TARGET_OS_TV
    return 52.0;
#else
    return 36.0;
#endif
}

/// 获取字体大小
- (CGFloat)fontSize {
#if TARGET_OS_TV
    return 18.0;
#else
    return 12.0;
#endif
}

#pragma mark - 修饰键判断

/// 判断给定的 VK code 是否为修饰键
/// @param vkCode Windows 虚拟键码
/// @return 是否为修饰键（Shift/Ctrl/Alt/CapsLock）
- (BOOL)isModifierVKCode:(short)vkCode {
    return (vkCode == 0x10 ||  // Shift
            vkCode == 0x11 ||  // Ctrl
            vkCode == 0x12 ||  // Alt (Menu)
            vkCode == 0x14);   // CapsLock
}

#pragma mark - 按键事件处理

/// 按键按下事件处理
/// @param sender 被按下的按键按钮
- (void)keyButtonPressed:(UIButton *)sender {
    NSInteger tag = sender.tag;
    BOOL isModifier = (tag & TAG_MODIFIER_BIT) != 0;
    short vkCode = (short)(tag & 0xFFFF);

    if (isModifier) {
        [self handleModifierKeyPress:vkCode];
    } else {
        [self handleRegularKeyPress:vkCode];
    }
}

/// 处理修饰键按下：切换修饰键的激活状态
/// @param vkCode 修饰键的 VK code
- (void)handleModifierKeyPress:(short)vkCode {
    switch (vkCode) {
        case 0x10: // Shift
            self.shiftActive = !self.shiftActive;
            break;
        case 0x11: // Ctrl
            self.ctrlActive = !self.ctrlActive;
            break;
        case 0x12: // Alt
            self.altActive = !self.altActive;
            break;
        case 0x14: // CapsLock
            self.capsLockActive = !self.capsLockActive;
            // CapsLock 需要向主机发送实际的按键事件
            [self sendKeyEventWithVKCode:0x14];
            break;
        default:
            break;
    }

    // 更新所有按键的视觉状态
    [self updateAllButtonAppearance];
}

/// 处理普通按键按下：发送按键事件并自动取消 Shift
/// @param vkCode 按键的 VK code
- (void)handleRegularKeyPress:(short)vkCode {
    [self sendKeyEventWithVKCode:vkCode];

    // Shift 在按下非修饰键后自动取消（除非 CapsLock 开启）
    if (self.shiftActive && !self.capsLockActive) {
        self.shiftActive = NO;
        [self updateAllButtonAppearance];
    }
}

/// 向远程主机发送按键事件（按下 + 50ms 延迟后释放）
/// @param vkCode Windows 虚拟键码
- (void)sendKeyEventWithVKCode:(short)vkCode {
    char modifiers = [self currentModifierFlags];

    // 发送按下事件，0x8000 前缀标记为非标准化扫描码（与 KeyboardSupport.m 一致）
    LiSendKeyboardEvent(0x8000 | vkCode, KEY_ACTION_DOWN, modifiers);

    // 50ms 后发送释放事件
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{
        LiSendKeyboardEvent(0x8000 | vkCode, KEY_ACTION_UP, modifiers);
    });
}

/// 计算当前修饰键状态的位标记
/// @return 修饰键组合字节（MODIFIER_SHIFT | MODIFIER_CTRL | MODIFIER_ALT）
- (char)currentModifierFlags {
    char flags = 0;
    if (self.shiftActive || self.capsLockActive) {
        flags |= MODIFIER_SHIFT;
    }
    if (self.ctrlActive) {
        flags |= MODIFIER_CTRL;
    }
    if (self.altActive) {
        flags |= MODIFIER_ALT;
    }
    return flags;
}

#pragma mark - 按键外观更新

/// 更新所有按键的外观（修饰键高亮 + Shift 文字切换）
- (void)updateAllButtonAppearance {
    BOOL shiftOrCaps = self.shiftActive || self.capsLockActive;

    for (UIButton *button in _allKeyButtons) {
        NSInteger tag = button.tag;
        BOOL isModifier = (tag & TAG_MODIFIER_BIT) != 0;
        short vkCode = (short)(tag & 0xFFFF);

        if (isModifier) {
            // 修饰键：激活时使用蓝色高亮背景
            BOOL active = [self isModifierActive:vkCode];
            if (active) {
                button.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:0.9];
            } else {
                button.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.8];
            }
        } else {
            // 普通键：根据 Shift/CapsLock 状态切换显示文字
            if (shiftOrCaps) {
                NSString *shiftLabel = button.accessibilityValue;
                if (shiftLabel != nil) {
                    // OEM 键：使用存储的 shiftLabel
                    [button setTitle:shiftLabel forState:UIControlStateNormal];
                } else {
                    // 字母键：转为大写
                    NSString *currentTitle = [button titleForState:UIControlStateNormal];
                    [button setTitle:[currentTitle uppercaseString] forState:UIControlStateNormal];
                }
            } else {
                // 非 Shift 状态：恢复原始文字
                NSString *originalLabel = button.accessibilityIdentifier;
                if (originalLabel != nil) {
                    // OEM 键：从 accessibilityIdentifier 恢复原始 label
                    [button setTitle:originalLabel forState:UIControlStateNormal];
                } else {
                    // 仅对单字母键转为小写（避免 ESC/F1/Tab 等功能键被错误小写）
                    NSString *currentTitle = [button titleForState:UIControlStateNormal];
                    if (currentTitle.length == 1) {
                        [button setTitle:[currentTitle lowercaseString] forState:UIControlStateNormal];
                    }
                }
            }
        }
    }
}

/// 判断指定修饰键是否处于激活状态
/// @param vkCode 修饰键的 VK code
/// @return 是否激活
- (BOOL)isModifierActive:(short)vkCode {
    switch (vkCode) {
        case 0x10: return self.shiftActive;
        case 0x11: return self.ctrlActive;
        case 0x12: return self.altActive;
        case 0x14: return self.capsLockActive;
        default: return NO;
    }
}

#pragma mark - 显示/隐藏动画

- (void)showAnimated:(BOOL)animated {
    if (self.isVisible) return;

    self.isVisible = YES;
    self.hidden = NO;

    // 重置所有修饰键状态
    self.shiftActive = NO;
    self.ctrlActive = NO;
    self.altActive = NO;
    self.capsLockActive = NO;
    [self updateAllButtonAppearance];

    if (animated) {
        // 动画前状态：向下偏移 + 完全透明
        self.alpha = 0.0;
        self.transform = CGAffineTransformMakeTranslation(0, SLIDE_OFFSET);

        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.alpha = 1.0;
            self.transform = CGAffineTransformIdentity;
        } completion:nil];
    } else {
        self.alpha = 1.0;
        self.transform = CGAffineTransformIdentity;
    }

#if TARGET_OS_TV
    // 在 tvOS 上请求焦点更新，使焦点落到键盘上
    [self setNeedsFocusUpdate];
    [self updateFocusIfNeeded];
#endif
}

- (void)dismissAnimated:(BOOL)animated {
    if (!self.isVisible) return;

    self.isVisible = NO;

    if (animated) {
        [UIView animateWithDuration:0.2
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            self.alpha = 0.0;
            self.transform = CGAffineTransformMakeTranslation(0, SLIDE_OFFSET);
        } completion:^(BOOL __unused finished) {
            self.hidden = YES;
            self.transform = CGAffineTransformIdentity;
        }];
    } else {
        self.alpha = 0.0;
        self.hidden = YES;
    }
}

#pragma mark - tvOS 焦点引擎支持

#if TARGET_OS_TV

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    // 键盘可见时，优先将焦点引导到第一个按键
    if (self.isVisible && self.firstKeyButton) {
        return @[self.firstKeyButton];
    }
    return @[];
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context {
    // 键盘可见时，阻止焦点离开键盘区域
    if (self.isVisible) {
        UIView *nextView = context.nextFocusedView;
        if (nextView && ![nextView isDescendantOfView:self]) {
            return NO;
        }
    }
    return YES;
}

#endif

@end
