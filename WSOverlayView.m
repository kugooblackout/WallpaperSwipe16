#import "WSOverlayView.h"

static const CGFloat kCardH = 460.0;
static const CGFloat kCardRatio = 220.0 / 460.0;
static const CGFloat kSpacing = 40.0;

@interface WSOverlayView () <UIScrollViewDelegate>
@property (nonatomic, strong) NSArray<UIImage *> *images;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIVisualEffectView *blur;
@property (nonatomic, strong) UILabel *titleLbl;
@property (nonatomic, strong) UIButton *cancelBtn;
@property (nonatomic, strong) UIButton *setBtn;
@property (nonatomic, strong) UIButton *addBtn;
@property (nonatomic, strong) NSMutableArray<UIView *> *cards;
@end

@implementation WSOverlayView

- (instancetype)initWithFrame:(CGRect)frame
                       images:(NSArray<UIImage *> *)images
                 initialIndex:(NSInteger)initialIndex {
    if ((self = [super initWithFrame:frame])) {
        self.images = images ?: @[];
        self.cards = [NSMutableArray array];
        self.currentIndex = initialIndex;
        self.backgroundColor = [UIColor clearColor];

        self.blur = [[UIVisualEffectView alloc] initWithEffect:
            [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        self.blur.frame = self.bounds;
        self.blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:self.blur];

        self.titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 60, frame.size.width, 30)];
        self.titleLbl.text = @"Обои";
        self.titleLbl.textColor = [UIColor whiteColor];
        self.titleLbl.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
        self.titleLbl.textAlignment = NSTextAlignmentCenter;
        [self addSubview:self.titleLbl];

        self.cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.cancelBtn setTitle:@"Отмена" forState:UIControlStateNormal];
        self.cancelBtn.tintColor = [UIColor whiteColor];
        self.cancelBtn.titleLabel.font = [UIFont systemFontOfSize:17];
        self.cancelBtn.frame = CGRectMake(20, 60, 90, 30);
        [self.cancelBtn addTarget:self action:@selector(tapCancel) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.cancelBtn];

        self.setBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.setBtn setTitle:@"Установить" forState:UIControlStateNormal];
        self.setBtn.tintColor = [UIColor whiteColor];
        self.setBtn.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        self.setBtn.frame = CGRectMake(frame.size.width - 110, 60, 90, 30);
        [self.setBtn addTarget:self action:@selector(tapSet) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.setBtn];

        CGFloat top = 130.0;
        CGFloat h = frame.size.height - top - 160;
        self.scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, top, frame.size.width, h)];
        self.scroll.showsHorizontalScrollIndicator = NO;
        self.scroll.decelerationRate = UIScrollViewDecelerationRateFast;
        self.scroll.delegate = self;
        self.scroll.clipsToBounds = NO;
        [self addSubview:self.scroll];

        CGFloat cardH = MIN(kCardH, h - 20);
        CGFloat cardW = cardH * kCardRatio;
        CGFloat sideInset = (frame.size.width - cardW) / 2.0;

        for (NSInteger i = 0; i < self.images.count; i++) {
            UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
            card.layer.cornerRadius = 22;
            card.layer.masksToBounds = YES;
            card.layer.borderWidth = 1.0;
            card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.15].CGColor;

            UIImageView *iv = [[UIImageView alloc] initWithImage:self.images[i]];
            iv.frame = card.bounds;
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            iv.clipsToBounds = YES;
            [card addSubview:iv];

            [self.scroll addSubview:card];
            [self.cards addObject:card];
        }

        CGFloat contentW = sideInset * 2 + cardW * self.images.count + kSpacing * (self.images.count > 0 ? self.images.count - 1 : 0);
        self.scroll.contentSize = CGSizeMake(contentW, h);
        self.scroll.contentInset = UIEdgeInsetsMake(0, sideInset, 0, sideInset);

        CGFloat x = 0;
        for (NSInteger i = 0; i < self.images.count; i++) {
            UIView *card = self.cards[i];
            card.frame = CGRectMake(x, (h - cardH) / 2.0, cardW, cardH);
            x += cardW + kSpacing;
        }
        [self layoutCardScales];

        self.addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.addBtn setTitle:@"+" forState:UIControlStateNormal];
        self.addBtn.titleLabel.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
        self.addBtn.tintColor = [UIColor whiteColor];
        self.addBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.2];
        self.addBtn.layer.cornerRadius = 30;
        self.addBtn.frame = CGRectMake(frame.size.width - 80, frame.size.height - 100, 60, 60);
        [self.addBtn addTarget:self action:@selector(tapAdd) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.addBtn];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.blur.frame = self.bounds;
    CGFloat top = 130.0;
    CGFloat h = self.bounds.size.height - top - 160;
    self.scroll.frame = CGRectMake(0, top, self.bounds.size.width, h);
    self.titleLbl.frame = CGRectMake(0, 60, self.bounds.size.width, 30);
    self.cancelBtn.frame = CGRectMake(20, 60, 90, 30);
    self.setBtn.frame = CGRectMake(self.bounds.size.width - 110, 60, 90, 30);
    self.addBtn.frame = CGRectMake(self.bounds.size.width - 80, self.bounds.size.height - 100, 60, 60);
    [self layoutCardScales];
}

- (void)layoutCardScales {
    CGFloat centerX = self.scroll.contentOffset.x + self.scroll.bounds.size.width / 2.0;
    for (UIView *card in self.cards) {
        CGFloat dist = fabs(card.center.x - centerX);
        CGFloat maxDist = self.scroll.bounds.size.width * 0.6;
        CGFloat t = MIN(dist / maxDist, 1.0);
        card.transform = CGAffineTransformMakeScale(1.0 - 0.18 * t, 1.0 - 0.18 * t);
        card.alpha = 1.0 - 0.4 * t;
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)sv {
    [self layoutCardScales];
    CGFloat centerX = sv.contentOffset.x + sv.bounds.size.width / 2.0;
    NSInteger nearest = 0;
    CGFloat nearestDist = CGFLOAT_MAX;
    for (NSInteger i = 0; i < self.cards.count; i++) {
        CGFloat d = fabs(self.cards[i].center.x - centerX);
        if (d < nearestDist) { nearestDist = d; nearest = i; }
    }
    self.currentIndex = nearest;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)sv { [self snapToCurrent]; }
- (void)scrollViewDidEndDragging:(UIScrollView *)sv willDecelerate:(BOOL)d {
    if (!d) [self snapToCurrent];
}

- (void)snapToCurrent {
    if (self.currentIndex < 0 || self.currentIndex >= (NSInteger)self.cards.count) return;
    UIView *card = self.cards[self.currentIndex];
    CGFloat targetX = card.center.x - self.scroll.bounds.size.width / 2.0;
    [self.scroll setContentOffset:CGPointMake(targetX, 0) animated:YES];
}

- (void)present {
    self.alpha = 0;
    [UIView animateWithDuration:0.25 animations:^{ self.alpha = 1; }];
    if (self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.cards.count) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            UIView *card = self.cards[self.currentIndex];
            CGFloat targetX = card.center.x - self.scroll.bounds.size.width / 2.0;
            [self.scroll setContentOffset:CGPointMake(targetX, 0) animated:NO];
            [self layoutCardScales];
        });
    }
}

- (void)dismiss {
    [UIView animateWithDuration:0.2 animations:^{ self.alpha = 0; }
                     completion:^(BOOL f) { [self removeFromSuperview]; }];
}

- (void)tapCancel { [self.delegate overlayDidCancel:self]; }
- (void)tapAdd    { [self.delegate overlayDidTapAdd:self]; }
- (void)tapSet    { [self.delegate overlay:self didSelectIndex:self.currentIndex]; }

@end
