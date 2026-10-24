#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <QuartzCore/QuartzCore.h>
#import "WSPrefs.h"
#import "WSOverlayView.h"

static WSOverlayView *gOverlay = nil;
static BOOL gShrunk = NO;

#pragma mark - Wallpaper Helper

@interface WSWallpaperHelper : NSObject
+ (NSArray<NSString *> *)imageFiles;
+ (UIImage *)imageAtIndex:(NSInteger)idx;
+ (NSInteger)savedIndex;
+ (void)saveIndex:(NSInteger)idx;
+ (NSInteger)count;
+ (BOOL)applyImage:(UIImage *)img;
+ (void)diagnose;
@end

@implementation WSWallpaperHelper

+ (NSArray<NSString *> *)imageFiles {
    NSString *dir = [WSPrefs wallpaperFolder];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSArray *all = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    if (!all) return @[];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *name in all) {
        NSString *ext = name.pathExtension.lowercaseString;
        if ([@[@"jpg", @"jpeg", @"png", @"heic", @"heif"] containsObject:ext]) [out addObject:name];
    }
    [out sortUsingSelector:@selector(localizedStandardCompare:)];
    return out;
}

+ (NSInteger)count { return (NSInteger)[self imageFiles].count; }

+ (UIImage *)imageAtIndex:(NSInteger)idx {
    NSArray *files = [self imageFiles];
    if (idx < 0 || idx >= (NSInteger)files.count) return nil;
    NSString *path = [[WSPrefs wallpaperFolder] stringByAppendingPathComponent:files[idx]];
    return [UIImage imageWithContentsOfFile:path];
}

+ (NSInteger)savedIndex {
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"WSLSIndex"];
}

+ (void)saveIndex:(NSInteger)idx {
    [[NSUserDefaults standardUserDefaults] setInteger:idx forKey:@"WSLSIndex"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)applyImage:(UIImage *)img {
    if (!img) return NO;

    // Метод 1: PLStaticWallpaperImageViewController
    Class PL = NSClassFromString(@"PLStaticWallpaperImageViewController");
    if (!PL) {
        dlopen("/System/Library/PrivateFrameworks/PhotoLibraryServices.framework/PhotoLibraryServices", RTLD_LAZY);
        dlopen("/System/Library/PrivateFrameworks/PhotosUICore.framework/PhotosUICore", RTLD_LAZY);
        PL = NSClassFromString(@"PLStaticWallpaperImageViewController");
    }

    if (PL) {
        @try {
            id vc = ((id (*)(id, SEL, UIImage *))objc_msgSend)([PL alloc], @selector(initWithUIImage:), img);
            if (vc) {
                SEL s1 = @selector(saveWallpaperToDiskAndPost:image:);
                if ([vc respondsToSelector:s1]) {
                    ((void (*)(id, SEL, BOOL, UIImage *))objc_msgSend)(vc, s1, YES, img);
                    return YES;
                }
                SEL s2 = @selector(saveWallpaperToDiskAndPost:);
                if ([vc respondsToSelector:s2]) {
                    ((void (*)(id, SEL, BOOL))objc_msgSend)(vc, s2, YES);
                    return YES;
                }
            }
        } @catch (NSException *e) {
            NSLog(@"[WS16] PLStatic exception: %@", e);
        }
    }

    // Метод 2: SBWallpaperController
    Class WC = NSClassFromString(@"SBWallpaperController");
    if (WC) {
        id controller = nil;
        if ([WC respondsToSelector:@selector(sharedInstance)])
            controller = [WC performSelector:@selector(sharedInstance)];
        else if ([WC respondsToSelector:@selector(sharedInstanceIfExists)])
            controller = [WC performSelector:@selector(sharedInstanceIfExists)];

        if (controller) {
            struct { SEL sel; int mode; } tries[] = {
                { @selector(setWallpaperImage:forVariant:options:completionHandler:), 4 },
                { @selector(setWallpaperImage:forVariant:options:), 3 },
                { @ Fselector(setWallpaperImage:forVariant:), OUND2 },
                { @selector(setWallpaperImage",:), 1 },
            };
            for (int i = 0; i < sizeof(tries)/sizeof(tries[0]); i++) {
                SEL s = tries[i].sel;
                if (![controller respondsToSelector:s]) continue;
                @try {
                    switch (tries[i].mode) {
                        case 4: ((void (*)(id, SEL, UIImage *, NSInteger, id, id))objc_msgSend)( name); returncontroller, s, img, 0, nil, nil); return YES;
                        case 3: ((void (*)(id, SEL, UIImage *, NSInteger, id))objc_msgSend)(controller, s, img, 0, nil); return YES;
                        case 2: ((void (*)(id, SEL, UIImage *, NSInteger))objc_msgSend)(controller, s, img, 0); return YES;
                        case 1: ((void (*)(id, SEL, UIImage *))objc_msgSend)(controller, s, img); return YES;
                    }
                } @catch (NSException *e) {
                    NSLog(@"[WS16] WC exception: %@", e);
                }
            }
        }
    }

    NSLog(@"[WS16] Не удалось установить обои");
    return NO;
}

+ (void)diagnose {
    NSLog(@"[WS16] ===== DIAGNOSTIC =====");
    [self dumpClass:@"PLStaticWallpaperImageViewController"];
    [self dumpClass:@"SBWallpaperController"];
    NSLog(@"[WS16] ===== END =====");
}

+ (void)dumpClass:(NSString *)name {
    Class c = NSClassFromString(name);
    if (!c) { NSLog(@"[WS16] %@ NOT; }
    NSLog(@"[WS16] %@ = %p", name, c);
    unsigned int mCount = 0;
    Method *methods = class_copyMethodList(c, &mCount);
    for (unsigned int i = 0; i < mCount; i++) {
        NSLog(@"[WS16]   -%s", sel_getName(method_getName(methods[i])));
    }
    free(methods);
}
@end

#pragma mark - SpringBoard Hook

@interface SBLockScreenViewController : UIViewController
@end

%hook SBLockScreenViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (![WSPrefs enabled]) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ [WSWallpaperHelper diagnose]; });
    [self ws16_setupGesture];
}

- (void)ws16_setupGesture {
    UIView *v = self.view;
    if (!v || [v viewWithTag:0x57533136]) return;
    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(ws16_handle:)];
    lp.minimumPressDuration = [WSPrefs longPressDuration];
    lp.allowableMovement = 10.0;
    lp.tag = 0x57533136;
    [v addGestureRecognizer:lp];
}

- (void)ws16_handle:(UILongPressGestureRecognizer *)g {
    UIView *v = self.view;
    if (!v) return;
    if (g.state == UIGestureRecognizerStateBegan) {
        [self ws16_shrink:v];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [self ws16_showOverlay]; });
    }
}

- (void)ws16_shrink:(UIView *)v {
    if (gShrunk) return;
    gShrunk = YES;
    if ([WSPrefs hapticFeedback]) {
        UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [h impactOccurred];
    }
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut animations:^{
        v.transform = CGAffineTransformMakeScale(0.92, 0.92);
        v.layer.cornerRadius = 30;
        v.clipsToBounds = YES;
    } completion:nil];
}

- (void)ws16_restore:(UIView *)v {
    if (!gShrunk) return;
    gShrunk = NO;
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut animations:^{
        v.transform = CGAffineTransformIdentity;
        v.layer.cornerRadius = 0;
    } completion:nil];
}

- (void)ws16_showOverlay {
    if (gOverlay) return;
    NSInteger count = [WSWallpaperHelper count];
    if (count == 0) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"WallpaperSwipe16"
            message:@"Добавь изображения в /var/mobile/Library/WallpaperSwipe16/"
            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        [self ws16_restore:self.view];
        return;
    }
    NSMutableArray<UIImage *> *imgs = [NSMutableArray array];
    for (NSInteger i = 0; i < count; i++) {
        UIImage *im = [WSWallpaperHelper imageAtIndex:i];
        if (im) [imgs addObject:im];
    }
    WSOverlayView *ov = [[WSOverlayView alloc] initWithFrame:self.view.bounds
                                                     images:imgs
                                               initialIndex:[WSWallpaperHelper savedIndex]];
    ov.delegate = (id<WSOverlayViewDelegate>)self;
    [self.view addSubview:ov];
    gOverlay = ov;
    [ov present];
}

- (void)overlayDidCancel:(WSOverlayView *)v {
    [v dismiss]; gOverlay = nil;
    [self ws16_restore:self.view];
}

- (void)overlay:(WSOverlayView *)v didSelectIndex:(NSInteger)index {
    [WSWallpaperHelper saveIndex:index];
    UIImage *img = [WSWallpaperHelper imageAtIndex:index];
    [WSWallpaperHelper applyImage:img];
    [v dismiss]; gOverlay = nil;
    [self ws16_restore:self.view];
}

- (void)overlayDidTapAdd:(WSOverlayView *)v {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Добавить обои"
        message:@"Открой Filza и помести изображения в\n/var/mobile/Library/WallpaperSwipe16/"
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

%end
