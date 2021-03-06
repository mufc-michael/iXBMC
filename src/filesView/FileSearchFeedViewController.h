#import "FixedTTTableViewController.h"

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@interface FileSearchFeedViewController : FixedTTTableViewController {
	NSString* _path;
	UITapGestureRecognizer *_errorTap;
}
@property (nonatomic, copy) NSString* path;

-(id) initWithNavigatorURL:(NSURL*)URL query:(NSDictionary*)query;
- (void)disconnectedFromXBMC: (NSNotification *) notification;
- (void)connectedToXBMC: (NSNotification *) notification;
@end
