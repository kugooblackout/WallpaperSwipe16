#import <UIKit/UIKit.h>

@class WSOverlayView;

@protocol WSOverlayViewDelegate <NSObject>
- (void)overlayDidCancel:(WSOverlayView *)v;
- (void)overlay:(WSOverlayView *)v didSelectIndex:(NSInteger)index;
- (void)overlayDidTapAdd:(WSOverlayView *)v;
@end

@interface WSOverlayView : UIView
@property (nonatomic, weak) id<WSOverlayViewDelegate> delegate;
@property (nonatomic, assign) NSInteger currentIndex;
- (instancetype)initWithFrame:(CGRect)frame
                       images:(NSArray<UIImage *> *)images
                 initialIndex:(NSInteger)initialIndex;
- (void)present;
- (void)dismiss;
@end
