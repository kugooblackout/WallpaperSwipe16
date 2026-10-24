#import "WSPrefs.h"

static NSString *const kPrefsDomain = @"com.example.wallpaperswipe16";

@implementation WSPrefs

+ (id)prefForKey:(NSString *)key default:(id)def {
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", kPrefsDomain];
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
    id v = d[key];
    return v ?: def;
}

+ (BOOL)enabled {
    return [[self prefForKey:@"Enabled" default:@YES] boolValue];
}

+ (BOOL)hapticFeedback {
    return [[self prefForKey:@"Haptic" default:@YES] boolValue];
}

+ (double)longPressDuration {
    return [[self prefForKey:@"LongPress" default:@0.35] doubleValue];
}

+ (NSString *)wallpaperFolder {
    return [self prefForKey:@"Folder" default:@"/var/mobile/Library/WallpaperSwipe16"];
}

@end
