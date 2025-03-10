#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "MenuBarIcon" asset catalog image resource.
static NSString * const ACImageNameMenuBarIcon AC_SWIFT_PRIVATE = @"MenuBarIcon";

/// The "AILogos/chatgpt" asset catalog image resource.
static NSString * const ACImageNameAILogosChatgpt AC_SWIFT_PRIVATE = @"AILogos/chatgpt";

/// The "AILogos/claude" asset catalog image resource.
static NSString * const ACImageNameAILogosClaude AC_SWIFT_PRIVATE = @"AILogos/claude";

/// The "AILogos/copilot" asset catalog image resource.
static NSString * const ACImageNameAILogosCopilot AC_SWIFT_PRIVATE = @"AILogos/copilot";

/// The "AILogos/deekseek" asset catalog image resource.
static NSString * const ACImageNameAILogosDeekseek AC_SWIFT_PRIVATE = @"AILogos/deekseek";

/// The "AILogos/grok" asset catalog image resource.
static NSString * const ACImageNameAILogosGrok AC_SWIFT_PRIVATE = @"AILogos/grok";

/// The "AILogos/perplexity" asset catalog image resource.
static NSString * const ACImageNameAILogosPerplexity AC_SWIFT_PRIVATE = @"AILogos/perplexity";

#undef AC_SWIFT_PRIVATE
