#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <QuartzCore/QuartzCore.h>

static UIView *gOverlay = nil;
static BOOL gShrunk = NO;
static NSInteger gCurrentIndex = 0;

#pragma mark - Overlay View (UI)

@interface WSOverlayView : UIView <UIScrollViewDelegate>
@property (nonatomic, strong) NSArray *images;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIVisualEffectView *blur;
@property (nonatomic, strong) UIButton *cancelBtn;
@property (nonatomic, strong) UIButton *setBtn;
@property (nonatomic, strong) NSMutableArray *cards;
@end

@implementation WSOverlayView

- (instancetype)initWithFrame:(CGRect)frame images:(NSArray *)images {
    if ((self = [super initWithFrame:frame])) {
        self.images = images;
        self.cards = [NSMutableArray array];
        self.backgroundColor = [UIColor clearColor];

        self.blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        self.blur.frame = self.bounds;
        self.blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:self.blur];

        self.cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.cancelBtn setTitle:@"Отмена" forState:UIControlStateNormal];
        self.cancelBtn.tintColor = [UIColor whiteColor];
        self.cancelBtn.frame = CGRectMake(20, 60, 90, 30);
        [self.cancelBtn addTarget:self action:@selector(tapCancel) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.cancelBtn];

        self.setBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.setBtn setTitle:@"Установить" forState:UIControlStateNormal];
        self.setBtn.tintColor = [UIColor whiteColor];
        self.setBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
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

        CGFloat cardH = MIN(460.0, h - 20);
        CGFloat cardW = cardH * (220.0 / 460.0);
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

        CGFloat contentW = sideInset * 2 + cardW * self.images.count + 40.0 * (self.images.count > 0 ? self.images.count - 1 : 0);
        self.scroll.contentSize = CGSizeMake(contentW, h);
        self.scroll.contentInset = UIEdgeInsetsMake(0, sideInset, 0, sideInset);

        CGFloat x = 0;
        for (NSInteger i = 0; i < self.images.count; i++) {
            UIView *card = self.cards[i];
            card.frame = CGRectMake(x, (h - cardH) / 2.0, cardW, cardH);
            x += cardW + 40.0;
        }
        [self layoutCardScales];
    }
    return self;
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
        CGFloat d = fabs([(UIView *)self.cards[i] center].x - centerX);
        if (d < nearestDist) { nearestDist = d; nearest = i; }
    }
    gCurrentIndex = nearest;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)sv { [self snapToCurrent]; }
- (void)scrollViewDidEndDragging:(UIScrollView *)sv willDecelerate:(BOOL)d { if (!d) [self snapToCurrent]; }

- (void)snapToCurrent {
    if (gCurrentIndex < 0 || gCurrentIndex >= (NSInteger)self.cards.count) return;
    UIView *card = self.cards[gCurrentIndex];
    CGFloat targetX = card.center.x - self.scroll.bounds.size.width / 2.0;
    [self.scroll setContentOffset:CGPointMake(targetX, 0) animated:YES];
}

- (void)tapCancel {
    [UIView animateWithDuration:0.2 animations:^{ self.alpha = 0; } completion:^(BOOL f) { [self removeFromSuperview]; gOverlay = nil; }];
}

- (void)tapSet {
    if (gCurrentIndex < 0 || gCurrentIndex >= (NSInteger)self.cards.count) return;
    UIImage *img = self.images[gCurrentIndex];
    [[NSUserDefaults standardUserDefaults] setInteger:gCurrentIndex forKey:@"WSLSIndex"];
    
    Class PL = NSClassFromString(@"PLStaticWallpaperImageViewController");
    if (!PL) {
        dlopen("/System/Library/PrivateFrameworks/PhotoLibraryServices.framework/PhotoLibraryServices", RTLD_LAZY);
        PL = NSClassFromString(@"PLStaticWallpaperImageViewController");
    }
    if (PL) {
        id vc = ((id (*)(id, SEL, UIImage *))objc_msgSend)([PL alloc], @selector(initWithUIImage:), img);
        if ([vc respondsToSelector:@selector(saveWallpaperToDiskAndPost:image:)]) {
            ((void (*)(id, SEL, BOOL, UIImage *))objc_msgSend)(vc, @selector(saveWallpaperToDiskAndPost:image:), YES, img);
        }
    }
    [self tapCancel];
}

@end

#pragma mark - SpringBoard Hook

@interface SBLockScreenViewController : UIViewController
- (void)ws16_setupGesture;
- (void)ws16_handle:(UILongPressGestureRecognizer *)g;
- (void)ws16_shrink:(UIView *)v;
- (void)ws16_restore:(UIView *)v;
- (void)ws16_showOverlay;
@end

%hook SBLockScreenViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self ws16_setupGesture];
}

- (void)ws16_setupGesture {
    UIView *v = self.view;
    if (!v) return;
    for (UIGestureRecognizer *gr in v.gestureRecognizers) {
        if ([gr isKindOfClass:[UILongPressGestureRecognizer class]] && gr.minimumPressDuration == 0.35) return;
    }
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(ws16_handle:)];
    lp.minimumPressDuration = 0.35;
    lp.allowableMovement = 10.0;
    [v addGestureRecognizer:lp];
}

- (void)ws16_handle:(UILongPressGestureRecognizer *)g {
    UIView *v = self.view;
    if (!v) return;
    if (g.state == UIGestureRecognizerStateBegan) {
        [self ws16_shrink:v];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self ws16_showOverlay];
        });
    }
}

- (void)ws16_shrink:(UIView *)v {
    if (gShrunk) return;
    gShrunk = YES;
    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [h impactOccurred];
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.4 options:UIViewAnimationOptionCurveEaseOut animations:^{
        v.transform = CGAffineTransformMakeScale(0.92, 0.92);
        v.layer.cornerRadius = 30;
        v.clipsToBounds = YES;
    } completion:nil];
}

- (void)ws16_restore:(UIView *)v {
    if (!gShrunk) return;
    gShrunk = NO;
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.4 options:UIViewAnimationOptionCurveEaseOut animations:^{
        v.transform = CGAffineTransformIdentity;
        v.layer.cornerRadius = 0;
    } completion:nil];
}

- (void)ws16_showOverlay {
    if (gOverlay) return;
    
    NSString *dir = @"/var/mobile/Library/WallpaperSwipe16";
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    NSMutableArray *imgs = [NSMutableArray array];
    for (NSString *name in files) {
        if ([@[@"jpg", @"jpeg", @"png", @"heic"] containsObject:name.pathExtension.lowercaseString]) {
            [imgs addObject:[UIImage imageWithContentsOfFile:[dir stringByAppendingPathComponent:name]]];
        }
    }
    
    if (imgs.count == 0) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"WallpaperSwipe16" message:@"Нет картинок в /var/mobile/Library/WallpaperSwipe16/" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        [self ws16_restore:self.view];
        return;
    }

    WSOverlayView *ov = [[WSOverlayView alloc] initWithFrame:self.view.bounds images:imgs];
    ov.alpha = 0;
    [self.view addSubview:ov];
    gOverlay = ov;
    
    [UIView animateWithDuration:0.25 animations:^{ ov.alpha = 1; }];
}

%end
