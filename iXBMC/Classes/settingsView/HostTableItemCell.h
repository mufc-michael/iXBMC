//
//  HostTableItemCell.h
//  iXBMC
//
//  Created by Martin Guillon on 5/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HostTableItemCell : TTTableSubtitleItemCell 
{
    TTTableViewController *delegate;
    UIImageView* _line;
}
@property (nonatomic, retain) TTTableViewController *delegate;

@end
