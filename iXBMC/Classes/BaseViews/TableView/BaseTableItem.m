
#import "BaseTableItem.h"

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation BaseTableItem

@synthesize poster      = _poster;
@synthesize label      = _label;
@synthesize imageURL      = _imageURL;

///////////////////////////////////////////////////////////////////////////////////////////////////

- (id)init {
    self = [super init];
    if (self)
    {
		_poster = nil;
    }
    return self;
}

- (void)dealloc {
    TT_RELEASE_SAFELY(_poster);
    TT_RELEASE_SAFELY(_label);
    TT_RELEASE_SAFELY(_imageURL);
    
    [super dealloc];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Class public


+ (id)item {
    BaseTableItem* item = [[[self alloc] init] autorelease];
    return item;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSCoding

@end