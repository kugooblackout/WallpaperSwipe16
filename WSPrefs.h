#import <Foundation/Foundation.h>

@interface WSPrefs : NSObject
+ (BOOL)enabled;
+ (BOOL)hapticFeedback;
+ (double)longPressDuration;
+ (NSString *)wallpaperFolder;
+ (id)prefForKey:(NSString *)key default:(id)def;
@end
