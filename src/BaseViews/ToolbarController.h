
@protocol ToolbarControllerDelegate;

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@interface ToolbarController : TTViewController
{
    id<ToolbarControllerDelegate> _delegate;
}

@property(nonatomic,assign) id<ToolbarControllerDelegate> delegate;

@end

@protocol ToolbarControllerDelegate <NSObject>

- (void)ToolbarController:(ToolbarController*)controller willShow:(BOOL)animated;
- (void)ToolbarController:(ToolbarController*)controller willHide:(BOOL)animated;

@end
