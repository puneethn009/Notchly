#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "breakout_icon" asset catalog image resource.
static NSString * const ACImageNameBreakoutIcon AC_SWIFT_PRIVATE = @"breakout_icon";

/// The "flappy_bird_sprite" asset catalog image resource.
static NSString * const ACImageNameFlappyBirdSprite AC_SWIFT_PRIVATE = @"flappy_bird_sprite";

/// The "flappy_icon" asset catalog image resource.
static NSString * const ACImageNameFlappyIcon AC_SWIFT_PRIVATE = @"flappy_icon";

/// The "snake_icon" asset catalog image resource.
static NSString * const ACImageNameSnakeIcon AC_SWIFT_PRIVATE = @"snake_icon";

#undef AC_SWIFT_PRIVATE
