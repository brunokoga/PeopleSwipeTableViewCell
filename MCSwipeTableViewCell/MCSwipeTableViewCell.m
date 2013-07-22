//
//  MCSwipeTableViewCell.m
//  MCSwipeTableViewCell
//
//  Created by Ali Karagoz on 24/02/13.
//  Copyright (c) 2013 Mad Castle. All rights reserved.
//

#import "MCSwipeTableViewCell.h"

static CGFloat const kMCStop1 = 0.20; // Percentage limit to trigger the first action
static CGFloat const kMCStop2 = 0.75; // Percentage limit to trigger the second action
static CGFloat const kMCBounceAmplitude = 20.0; // Maximum bounce amplitude when using the MCSwipeTableViewCellModeSwitch mode
static CGFloat const kMCDefaultButtonsSpacing = 20.0f;
static NSTimeInterval const kMCBounceDuration1 = 0.2; // Duration of the first part of the bounce animation
static NSTimeInterval const kMCBounceDuration2 = 0.1; // Duration of the second part of the bounce animation
static NSTimeInterval const kMCDurationLowLimit = 0.25; // Lowest duration when swipping the cell because we try to simulate velocity
static NSTimeInterval const kMCDurationHightLimit = 0.1; // Highest duration when swipping the cell because we try to simulate velocity

@interface MCSwipeTableViewCell () <UIGestureRecognizerDelegate>

// Init
- (void)initializer;

// Handle Gestures
- (void)handlePanGestureRecognizer:(UIPanGestureRecognizer *)gesture;

// Utils
- (CGFloat)offsetWithPercentage:(CGFloat)percentage relativeToWidth:(CGFloat)width;

- (CGFloat)percentageWithOffset:(CGFloat)offset relativeToWidth:(CGFloat)width;

- (NSTimeInterval)animationDurationWithVelocity:(CGPoint)velocity;

- (MCSwipeTableViewCellDirection)directionWithPercentage:(CGFloat)percentage;

- (NSString *)imageNameWithPercentage:(CGFloat)percentage;

- (UIColor *)colorWithPercentage:(CGFloat)percentage;

- (MCSwipeTableViewCellState)stateWithPercentage:(CGFloat)percentage;

- (CGFloat)imageAlphaWithPercentage:(CGFloat)percentage;

- (BOOL)validateState:(MCSwipeTableViewCellState)state;

// Movement
- (void)slideImageWithPercentage:(CGFloat)percentage imageName:(NSString *)imageName isDragging:(BOOL)isDragging;

- (void)animateWithOffset:(CGFloat)offset;

- (void)moveWithDuration:(NSTimeInterval)duration andDirection:(MCSwipeTableViewCellDirection)direction;

- (void)bounceToOrigin;

// Delegate
- (void)notifyDelegate;

@property(nonatomic, assign) MCSwipeTableViewCellDirection direction;
@property(nonatomic, assign) CGFloat currentPercentage;

@property(nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property(nonatomic, strong) UIImageView *slidingImageView;
@property(nonatomic, strong) NSString *currentImageName;
@property(nonatomic, strong) UIView *colorIndicatorView;
@property(nonatomic, strong) NSMutableArray *leftButtons;
@property(nonatomic, strong) NSMutableArray *rightButtons;
@property(nonatomic, strong) UIView *leftButtonsContainer;
@property(nonatomic, strong) UIView *rightButtonsContainer;

@end

@implementation MCSwipeTableViewCell

#pragma mark - Initialization

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

    if (self) {
        [self initializer];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];

    if (self) {
        [self initializer];
    }
    return self;
}

- (id)init {
    self = [super init];

    if (self) {
        [self initializer];
    }

    return self;
}

#pragma mark Custom Initializer

- (id)initWithStyle:(UITableViewCellStyle)style
    reuseIdentifier:(NSString *)reuseIdentifier
 firstStateIconName:(NSString *)firstIconName
         firstColor:(UIColor *)firstColor
secondStateIconName:(NSString *)secondIconName
        secondColor:(UIColor *)secondColor
      thirdIconName:(NSString *)thirdIconName
         thirdColor:(UIColor *)thirdColor
     fourthIconName:(NSString *)fourthIconName
        fourthColor:(UIColor *)fourthColor {
    self = [self initWithStyle:style reuseIdentifier:reuseIdentifier];

    if (self) {
        [self setFirstStateIconName:firstIconName
                         firstColor:firstColor
                secondStateIconName:secondIconName
                        secondColor:secondColor
                      thirdIconName:thirdIconName
                         thirdColor:thirdColor
                     fourthIconName:fourthIconName
                        fourthColor:fourthColor];
    }

    return self;
}

- (void)initializer {
    _mode = MCSwipeTableViewCellModeSwitch;

    _colorIndicatorView = [[UIView alloc] initWithFrame:self.bounds];
    [_colorIndicatorView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [_colorIndicatorView setBackgroundColor:[UIColor clearColor]];
    [self insertSubview:_colorIndicatorView atIndex:0];
    self.leftButtonsContainer.frame = (CGRect){self.bounds.origin, 0, self.bounds.size.height};
    self.rightButtonsContainer.frame = (CGRect){self.bounds.size.width, self.bounds.origin.y, 0, self.bounds.size.height};
    [self insertSubview:self.leftButtonsContainer aboveSubview:_colorIndicatorView];
    [self insertSubview:self.rightButtonsContainer aboveSubview:_colorIndicatorView];
    self.backgroundColor = [UIColor clearColor];

    _slidingImageView = [[UIImageView alloc] init];
    [_slidingImageView setContentMode:UIViewContentModeCenter];
    [_colorIndicatorView addSubview:_slidingImageView];

    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGestureRecognizer:)];
    [self addGestureRecognizer:_panGestureRecognizer];
    [_panGestureRecognizer setDelegate:self];
    
    _isDragging = NO;
    
    // By default the cells are draggable
    _shouldDrag = YES;
}

#pragma mark - Prepare reuse

- (void)prepareForReuse {
    [super prepareForReuse];
    
    // Clearing before presenting back the cell to the user
    [_colorIndicatorView setBackgroundColor:[UIColor clearColor]];
    self.leftButtonsContainer.hidden = self.rightButtonsContainer.hidden = YES;
    
    // clearing the dragging flag
    _isDragging = NO;

    // Before reuse we need to reset it's state
    _shouldDrag = YES;
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    CGRect rightMenuFrame = self.rightButtonsContainer.frame;
    rightMenuFrame.origin.x = CGRectGetWidth(self.bounds) - CGRectGetWidth(self.rightButtonsContainer.bounds);
    self.rightButtonsContainer.frame = rightMenuFrame;
}

#pragma mark - Handle Gestures

- (void)handlePanGestureRecognizer:(UIPanGestureRecognizer *)gesture {
    
    // The user do not want you to be dragged!
    if (!_shouldDrag) return;
    
    UIGestureRecognizerState state = [gesture state];
    CGPoint translation = [gesture translationInView:self];
    CGPoint velocity = [gesture velocityInView:self];
    CGFloat percentage = [self percentageWithOffset:CGRectGetMinX(self.contentView.frame) relativeToWidth:CGRectGetWidth(self.bounds)];
    NSTimeInterval animationDuration = [self animationDurationWithVelocity:velocity];
    _direction = [self directionWithPercentage:percentage];

    [self showOrHideMenusWithPercentage:percentage];
    
    if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
        _isDragging = YES;
        
        CGPoint center = {self.contentView.center.x + translation.x, self.contentView.center.y};
        [self.contentView setCenter:center];
        [self animateWithOffset:CGRectGetMinX(self.contentView.frame)];
        [gesture setTranslation:CGPointZero inView:self];
    }
    else if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled) {
        _isDragging = NO;
        
        _currentImageName = [self imageNameWithPercentage:percentage];
        _currentPercentage = percentage;
        MCSwipeTableViewCellState cellState = [self stateWithPercentage:percentage];
        
        if (cellState == MCSwipeTableViewCellStateLeftMenu && velocity.x > 0)
        {
            [self revealMenuSide:MCSwipeTableViewCellSideLeft withDuration:animationDuration];
        }
        else if (cellState == MCSwipeTableViewCellStateRightMenu && velocity.x < 0)
        {
            [self revealMenuSide:MCSwipeTableViewCellSideRight withDuration:animationDuration];
        }
        else if (_mode == MCSwipeTableViewCellModeExit && _direction != MCSwipeTableViewCellDirectionCenter && [self validateState:cellState])
            [self moveWithDuration:animationDuration andDirection:_direction];
        else
            [self bounceToOrigin];
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer class] == [UIPanGestureRecognizer class]) {
        UIPanGestureRecognizer *g = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint point = [g velocityInView:self];
        if (fabsf(point.x) > fabsf(point.y) ) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Utils

- (CGFloat)offsetWithPercentage:(CGFloat)percentage relativeToWidth:(CGFloat)width {
    CGFloat offset = percentage * width;

    if (offset < -width) offset = -width;
    else if (offset > width) offset = width;

    return offset;
}

- (CGFloat)percentageWithOffset:(CGFloat)offset relativeToWidth:(CGFloat)width {
    CGFloat percentage = offset / width;

    if (percentage < -1.0) percentage = -1.0;
    else if (percentage > 1.0) percentage = 1.0;

    return percentage;
}

- (NSTimeInterval)animationDurationWithVelocity:(CGPoint)velocity {
    CGFloat width = CGRectGetWidth(self.bounds);
    NSTimeInterval animationDurationDiff = kMCDurationHightLimit - kMCDurationLowLimit;
    CGFloat horizontalVelocity = velocity.x;

    if (horizontalVelocity < -width) horizontalVelocity = -width;
    else if (horizontalVelocity > width) horizontalVelocity = width;

    return (kMCDurationHightLimit + kMCDurationLowLimit) - fabs(((horizontalVelocity / width) * animationDurationDiff));
}

- (MCSwipeTableViewCellDirection)directionWithPercentage:(CGFloat)percentage {
    if (percentage < -kMCStop1)
        return MCSwipeTableViewCellDirectionLeft;
    else if (percentage > kMCStop1)
        return MCSwipeTableViewCellDirectionRight;
    else
        return MCSwipeTableViewCellDirectionCenter;
}

- (NSString *)imageNameWithPercentage:(CGFloat)percentage {
    NSString *imageName;

    // Image
    // check if should show buttons, if so, there is no sliding image to show
    if (percentage > 0 && self.leftButtons.count)
        imageName = nil;
    else if (percentage < 0 && self.rightButtons.count)
        imageName = nil;
    
    // check for another cases
    else if (percentage >= 0 && percentage < kMCStop2)
        imageName = _firstIconName;
    else if (percentage >= kMCStop2)
        imageName = _secondIconName;
    else if (percentage < 0 && percentage > -kMCStop2)
        imageName = _thirdIconName;
    else if (percentage <= -kMCStop2)
        imageName = _fourthIconName;

    return imageName;
}

- (CGFloat)imageAlphaWithPercentage:(CGFloat)percentage {
    CGFloat alpha;

    if (percentage >= 0 && percentage < kMCStop1)
        alpha = percentage / kMCStop1;
    else if (percentage < 0 && percentage > -kMCStop1)
        alpha = fabsf(percentage / kMCStop1);
    else alpha = 1.0;

    return alpha;
}

- (UIColor *)colorWithPercentage:(CGFloat)percentage {
    UIColor *color;

    // Background Color
    // check if should show buttons, if so, there is no sliding image to show
    if (percentage > 0 && self.leftButtons.count)
        color = self.leftMenuColor;
    else if (percentage < 0 && self.rightButtons.count)
        color = self.rightMenuColor;

    // check for another cases
    else if (percentage >= kMCStop1 && percentage < kMCStop2)
        color = _firstColor;
    else if (percentage >= kMCStop2)
        color = _secondColor;
    else if (percentage < -kMCStop1 && percentage > -kMCStop2)
        color = _thirdColor;
    else if (percentage <= -kMCStop2)
        color = _fourthColor;
    else
        color = [UIColor clearColor];

    return color;
}

- (MCSwipeTableViewCellState)stateWithPercentage:(CGFloat)percentage {
    MCSwipeTableViewCellState state;

    state = MCSwipeTableViewCellStateNone;

    if (percentage > 0 && self.leftButtons.count)
    {
        state = MCSwipeTableViewCellStateLeftMenu;
    }
    else if (percentage < 0 && self.rightButtons.count)
    {
        state = MCSwipeTableViewCellStateRightMenu;
    }
    else
    {
        if (percentage >= kMCStop1 && [self validateState:MCSwipeTableViewCellState1])
            state = MCSwipeTableViewCellState1;
        
        if (percentage >= kMCStop2 && [self validateState:MCSwipeTableViewCellState2])
            state = MCSwipeTableViewCellState2;
        
        if (percentage <= -kMCStop1 && [self validateState:MCSwipeTableViewCellState3])
            state = MCSwipeTableViewCellState3;
        
        if (percentage <= -kMCStop2 && [self validateState:MCSwipeTableViewCellState4])
            state = MCSwipeTableViewCellState4;
    }

    return state;
}

- (BOOL)validateState:(MCSwipeTableViewCellState)state {
    BOOL isValid = YES;

    switch (state) {
        case MCSwipeTableViewCellStateNone: {
            isValid = NO;
        }
            break;

        case MCSwipeTableViewCellState1: {
            if (!_firstColor && !_firstIconName)
                isValid = NO;
        }
            break;

        case MCSwipeTableViewCellState2: {
            if (!_secondColor && !_secondIconName)
                isValid = NO;
        }
            break;

        case MCSwipeTableViewCellState3: {
            if (!_thirdColor && !_thirdIconName)
                isValid = NO;
        }
            break;

        case MCSwipeTableViewCellState4: {
            if (!_fourthColor && !_fourthIconName)
                isValid = NO;
        }
            break;

        default:
            break;
    }

    return isValid;
}

#pragma mark - Movement

- (void)animateWithOffset:(CGFloat)offset {
    CGFloat percentage = [self percentageWithOffset:offset relativeToWidth:CGRectGetWidth(self.bounds)];

    // Image Name
    NSString *imageName = [self imageNameWithPercentage:percentage];

    // Image Position
    if (imageName != nil) {
        [_slidingImageView setImage:[UIImage imageNamed:imageName]];
        [_slidingImageView setAlpha:[self imageAlphaWithPercentage:percentage]];
    }
    [self slideImageWithPercentage:percentage imageName:imageName isDragging:YES];

    // Color
    UIColor *color = [self colorWithPercentage:percentage];
    if (color != nil) {
        [_colorIndicatorView setBackgroundColor:color];
    }
}


- (void)slideImageWithPercentage:(CGFloat)percentage imageName:(NSString *)imageName isDragging:(BOOL)isDragging {
    UIImage *slidingImage = [UIImage imageNamed:imageName];
    CGSize slidingImageSize = slidingImage.size;
    CGRect slidingImageRect;

    CGPoint position = CGPointZero;

    position.y = CGRectGetHeight(self.bounds) / 2.0;

    if (isDragging) {
        if (percentage >= 0 && percentage < kMCStop1) {
            position.x = [self offsetWithPercentage:(kMCStop1 / 2) relativeToWidth:CGRectGetWidth(self.bounds)];
        }

        else if (percentage >= kMCStop1) {
            position.x = [self offsetWithPercentage:percentage - (kMCStop1 / 2) relativeToWidth:CGRectGetWidth(self.bounds)];
        }
        else if (percentage < 0 && percentage >= -kMCStop1) {
            position.x = CGRectGetWidth(self.bounds) - [self offsetWithPercentage:(kMCStop1 / 2) relativeToWidth:CGRectGetWidth(self.bounds)];
        }

        else if (percentage < -kMCStop1) {
            position.x = CGRectGetWidth(self.bounds) + [self offsetWithPercentage:percentage + (kMCStop1 / 2) relativeToWidth:CGRectGetWidth(self.bounds)];
        }
    }
    else {
        if (_direction == MCSwipeTableViewCellDirectionRight) {
            position.x = [self offsetWithPercentage:percentage - (kMCStop1 / 2) relativeToWidth:CGRectGetWidth(self.bounds)];
        }
        else if (_direction == MCSwipeTableViewCellDirectionLeft) {
            position.x = CGRectGetWidth(self.bounds) + [self offsetWithPercentage:percentage + (kMCStop1 / 2) relativeToWidth:CGRectGetWidth(self.bounds)];
        }
        else {
            return;
        }
    }


    slidingImageRect = CGRectMake(position.x - slidingImageSize.width / 2.0,
            position.y - slidingImageSize.height / 2.0,
            slidingImageSize.width,
            slidingImageSize.height);

    slidingImageRect = CGRectIntegral(slidingImageRect);
    [_slidingImageView setFrame:slidingImageRect];
}


- (void)moveWithDuration:(NSTimeInterval)duration andDirection:(MCSwipeTableViewCellDirection)direction {
    CGFloat origin;

    if (direction == MCSwipeTableViewCellDirectionLeft)
        origin = -CGRectGetWidth(self.bounds);
    else
        origin = CGRectGetWidth(self.bounds);

    CGFloat percentage = [self percentageWithOffset:origin relativeToWidth:CGRectGetWidth(self.bounds)];
    CGRect rect = self.contentView.frame;
    rect.origin.x = origin;

    // Color
    UIColor *color = [self colorWithPercentage:_currentPercentage];
    if (color != nil) {
        [_colorIndicatorView setBackgroundColor:color];
    }

    // Image
    if (_currentImageName != nil) {
        [_slidingImageView setImage:[UIImage imageNamed:_currentImageName]];
    }

    [UIView animateWithDuration:duration
                          delay:0.0
                        options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
                         [self.contentView setFrame:rect];
                         [_slidingImageView setAlpha:0];
                         [self slideImageWithPercentage:percentage imageName:_currentImageName isDragging:NO];
                     }
                     completion:^(BOOL finished) {
                         [self notifyDelegate];
                     }];
}

- (void)revealMenuSide:(MCSwipeTableViewCellSide)side withDuration:(NSTimeInterval)duration
{
    UIView *containerView = nil;
    
    if (side == MCSwipeTableViewCellSideLeft)
        containerView = self.leftButtonsContainer;
    else
        containerView = self.rightButtonsContainer;
    
    CGRect containerFrame = containerView.frame;
    containerFrame.origin.x = side == MCSwipeTableViewCellSideRight ? self.bounds.size.width - containerFrame.size.width : containerFrame.origin.x;
    containerView.frame = containerFrame;
    
    containerView.hidden = NO;
    
    CGFloat origin = CGRectGetWidth(containerView.bounds);

    CGRect rect = self.contentView.frame;
    rect.origin.x = side == MCSwipeTableViewCellSideLeft ? origin : -origin;
    
    // Color
    UIColor *color = [self colorWithPercentage:_currentPercentage];
    if (color != nil) {
        [_colorIndicatorView setBackgroundColor:color];
    }
    
    // Image
    if (_currentImageName != nil) {
        [_slidingImageView setImage:[UIImage imageNamed:_currentImageName]];
    }
    
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
                         [self.contentView setFrame:rect];
                     }
                     completion:^(BOOL finished) {
                         [self notifyDelegate];
                     }];
}

- (void)bounceToOrigin {
    CGFloat bounceDistance = kMCBounceAmplitude * _currentPercentage;

    [UIView animateWithDuration:kMCBounceDuration1
                          delay:0
                        options:(UIViewAnimationOptionCurveEaseOut)
                     animations:^{
                         CGRect frame = self.contentView.frame;
                         frame.origin.x = -bounceDistance;
                         [self.contentView setFrame:frame];
                         [_slidingImageView setAlpha:0.0];
                         [self slideImageWithPercentage:0 imageName:_currentImageName isDragging:NO];
                     }
                     completion:^(BOOL finished1) {

                         [UIView animateWithDuration:kMCBounceDuration2
                                               delay:0
                                             options:UIViewAnimationOptionCurveEaseIn
                                          animations:^{
                                              CGRect frame = self.contentView.frame;
                                              frame.origin.x = 0;
                                              [self.contentView setFrame:frame];
                                          }
                                          completion:^(BOOL finished2) {
                                              [self notifyDelegate];
                                              self.leftButtonsContainer.hidden = self.rightButtonsContainer.hidden = YES;
                                          }];
                     }];
}

- (void)showOrHideMenusWithPercentage:(CGFloat)percentage
{
    if (percentage == 0)
    {
        self.leftButtonsContainer.hidden = self.rightButtonsContainer.hidden = YES;
    }
    else if (percentage < 0)
    {
        self.leftButtonsContainer.hidden = YES;
        self.rightButtonsContainer.hidden = NO;
    }
    else if (percentage > 0)
    {
        self.leftButtonsContainer.hidden = NO;
        self.rightButtonsContainer.hidden = YES;
    }
}

#pragma mark - Menu buttons Methods

- (void)addButton:(UIButton *)button toCellSide:(MCSwipeTableViewCellSide)side
{
    NSAssert(button != nil, @"The button object shouldn't be nil");
    
    // get the matching buttons array according to the side;
    NSMutableArray *buttons = side == MCSwipeTableViewCellSideLeft ? self.leftButtons : self.rightButtons;
    
    // get the matching container view according to the side;
    UIView *containerView = side == MCSwipeTableViewCellSideLeft ? self.leftButtonsContainer : self.rightButtonsContainer;
    
    // Set the next position to be at the right side of the last added button with a space between (if the space was not set by the user, a default value will be used)
    CGFloat spacing = self.menuButtonSpacing ? : kMCDefaultButtonsSpacing;
    CGPoint buttonPosition = CGPointZero;
    buttonPosition.x = containerView.frame.size.width == 0 ? spacing : containerView.frame.size.width;
    buttonPosition.y = (containerView.frame.size.height / 2);
    CGRect nextButtonFrame = (CGRect){buttonPosition, button.frame.size};
    button.frame = nextButtonFrame;
    
    // Resize the container view to fit the new button
    CGRect containerFrame = containerView.frame;
    CGFloat additionalWidth = nextButtonFrame.origin.x + nextButtonFrame.size.width - containerFrame.size.width + spacing;
    containerFrame.size.width += additionalWidth;
    
    // if the buttons is being inserted on the right menu, move the container view to left
    containerFrame.origin.x = side == MCSwipeTableViewCellSideRight ? self.bounds.size.width - containerFrame.size.width : containerFrame.origin.x;
    
    containerView.frame = containerFrame;
    
    // Add the button to the container view and the buttons array;
    [containerView addSubview:button];
    [containerView sizeToFit];
    
    // Tell the cell to go back to center mode when one button is touched
    [button addTarget:self action:@selector(bounceToOrigin) forControlEvents:UIControlEventTouchUpInside];
    
    [buttons addObject:button];
}

#pragma mark - Delegate Notification

- (void)notifyDelegate {
    MCSwipeTableViewCellState state = [self stateWithPercentage:_currentPercentage];

    if (state != MCSwipeTableViewCellStateNone) {
        if (_delegate != nil && [_delegate respondsToSelector:@selector(swipeTableViewCell:didTriggerState:withMode:)]) {
            [_delegate swipeTableViewCell:self didTriggerState:state withMode:_mode];
        }
    }
}

#pragma mark - Getter

- (NSMutableArray *)leftButtons
{
    if (!_leftButtons)
    {
        _leftButtons = [NSMutableArray array];
    }
    return _leftButtons;
}

- (NSMutableArray *)rightButtons
{
    if (!_rightButtons)
    {
        _rightButtons = [NSMutableArray array];
    }
    return _rightButtons;
}

- (UIView *)leftButtonsContainer
{
    if (!_leftButtonsContainer)
    {
        _leftButtonsContainer = [[UIView alloc] init];
    }
    return _leftButtonsContainer;
}

- (UIView *)rightButtonsContainer
{
    if (!_rightButtonsContainer)
    {
        _rightButtonsContainer = [[UIView alloc] init];
    }
    return _rightButtonsContainer;
}

#pragma mark - Setter

- (void)setFirstStateIconName:(NSString *)firstIconName
                   firstColor:(UIColor *)firstColor
          secondStateIconName:(NSString *)secondIconName
                  secondColor:(UIColor *)secondColor
                thirdIconName:(NSString *)thirdIconName
                   thirdColor:(UIColor *)thirdColor
               fourthIconName:(NSString *)fourthIconName
                  fourthColor:(UIColor *)fourthColor {
    [self setFirstIconName:firstIconName];
    [self setSecondIconName:secondIconName];
    [self setThirdIconName:thirdIconName];
    [self setFourthIconName:fourthIconName];

    [self setFirstColor:firstColor];
    [self setSecondColor:secondColor];
    [self setThirdColor:thirdColor];
    [self setFourthColor:fourthColor];
}

@end