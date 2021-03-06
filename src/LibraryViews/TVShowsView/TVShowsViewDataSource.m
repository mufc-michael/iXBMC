
#import "TVShowsViewDataSource.h"

#import "TVShowsViewModel.h"
#import "TVShow.h"
#import "Episode.h"
#import "TVShowTableItem.h"
#import "TVShowTableItemCell.h"

#import "ActiveManager.h"

#import "XBMCHttpInterface.h"

// Three20 Additions
#import <Three20Core/NSDateAdditions.h>


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation TVShowsViewDataSource
@synthesize query = _query;
@synthesize forSearch = _forSearch;
@synthesize filteredListContent = _filteredListContent;
@synthesize hideWatched = _hideWatched;

- (void)setPredicate
{
	self.predicate = nil;
	if(_hideWatched)
	{
		self.predicate = [NSPredicate predicateWithFormat:@"ANY episodes.playcount == 0"];
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (id) initWithWatched:(BOOL)watched controllerTableView:(UITableView *)controllerTableView
{
    self = [super initWithEntity:[[[[ActiveManager shared] managedObjectModel] 
								   entitiesByName] objectForKey:@"TVShow"] controllerTableView:controllerTableView];
    if (self) 
    {
        appDelegate = ((AppDelegate*)[UIApplication sharedApplication].delegate); 
        self.tableView = controllerTableView;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(libraryContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:nil];
        _model = [[TTModel alloc] init];
        _query = @"";
        _forSearch = false;
        _hideWatched = !watched;
		[self setPredicate];
    }

  return self;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	TT_RELEASE_SAFELY(_model);
    //    TT_RELEASE_SAFELY(managedObjectContext);
    TT_RELEASE_SAFELY(_query);
    TT_RELEASE_SAFELY(_filteredListContent);
  [super dealloc];
}

-(NSUInteger) count
{
    return [self.fetchedResultsController.fetchedObjects count];
}

//- (void)tableViewDidLoadModel:(UITableView*)tableView {
////    // the model has loaded, and hence Core Data entities are populated    
////    //self.managedObjectContext = appDelegate.managedObjectContext;
////    
////    NSError* error;
////    if( ![self.fetchedResultsController performFetch:&error] ) {
////        // handle error
////    }
////    [self loadLocal:TRUE];
//}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString*)titleForLoading:(BOOL)reloading {
  return NSLocalizedString(@"Updating Library...", @"");
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString*)titleForEmpty {
  return NSLocalizedString(@"No TVShows found.", @"");
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString*)subtitleForError:(NSError*)error {
  return NSLocalizedString(@"Sorry, there was an error loading the TVShowss.", @"");
}

- (void)libraryContextDidSave:(NSNotification*)saveNotification {
	if ([self isLoaded])
    {
//        [self didStartLoad];
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
		[context setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
//        // Merging changes causes the fetched results controller to update its results
////        [context mergeChangesFromContextDidSaveNotification:saveNotification];	
//        [context performSelectorOnMainThread:@selector(mergeChangesFromContextDidSaveNotification:)
//                                       withObject:saveNotification
//                                    waitUntilDone:YES]; 
		
		// Fault in all updated objects
		NSArray* updates = [[saveNotification.userInfo objectForKey:@"updated"] allObjects];
		for (NSInteger i = [updates count]-1; i >= 0; i--)
		{
			[[context objectWithID:[[updates objectAtIndex:i] objectID]] willAccessValueForKey:nil];
		}
		
		// Merge
		[context mergeChangesFromContextDidSaveNotification:saveNotification];
		
//		[context mergeChangesFromContextDidSaveNotification:saveNotification];
//        [self.model.delegates perform:@selector(modelDidFinishLoad:) withObject:self.model];
//        [self load:TTURLRequestCachePolicyNone more:TRUE];
//        [self.tableView reloadData];
////        [self load:TTURLRequestCachePolicyNone more:TRUE];
//        [self silentDidLoad];        
//    }
//    else
//    {
////        [self didStartLoad];
//        [self load:TTURLRequestCachePolicyNone more:TRUE];
//        [self.tableView reloadData];
//        [self silentDidLoad];        
    }
}

- (void) toggleWatched
{
    _hideWatched = !_hideWatched;
	[self setPredicate];
    [self performFetch];
//    [self silentDidLoad];        
} 

#pragma mark -
#pragma mark Table view data source methods

/*
 The data source methods are handled primarily by the fetch results controller
 */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_forSearch)
    {
		return 1;
        
    }
    else
    {
        return [super numberOfSectionsInTableView:tableView];
    }
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	
    if (_forSearch)
    {
		return [_filteredListContent count];
        
    }
    else
    {
        return [super tableView:tableView numberOfRowsInSection:section];

    }
}

#pragma mark -
#pragma mark TTTable view data source methods

- (Class)tableView:(UITableView *)tableView cellClassForObject:(id)object {
    return [TVShowTableItemCell class];
}

// override TTTableViewDataSource's method to return the cell TableItem we want - three20 will take care of returning the right cell
- (id)tableView:(UITableView*)tableView objectForRowAtIndexPath:(NSIndexPath*)indexPath {
    
    TVShow *show = nil;
    if (_forSearch)
    {
		show = (TVShow*)[_filteredListContent objectAtIndex:[indexPath row]];
    }
    else
    {
		show = (TVShow*)[self.fetchedResultsController objectAtIndexPath:indexPath];
    }
    TVShowTableItem* item = [TVShowTableItem item];
	item.dataSource = self;
    item.forSearch = _forSearch;
    item.label = show.label;
    item.imageURL = show.thumbnail;
    item.genre = show.genre;
    item.tagline = show.tagline;
    item.tvdb = show.tvdbid;
    item.itemId = show.tvshowid;
    item.rating = [NSString stringWithFormat:@"%.1f",[show.rating floatValue]];
	item.premiered = show.premiered;
    item.watched = TRUE;
	item.nbUnWatched = [NSNumber numberWithInt:0];
	item.nbEpisodes = [NSNumber numberWithInt:[show.episodes count]];
	for (Episode* ep in show.episodes)
	{
		if ([ep.playcount intValue] == 0)
		{
			item.watched = FALSE;
			item.nbUnWatched = [NSNumber numberWithInt:[item.nbUnWatched intValue] + 1];
		}
	}
    return item;
}

- (void)search:(NSString*)text {
    if (_filteredListContent != nil)
    {
        TT_RELEASE_SAFELY(_filteredListContent);
    }
    //    [self.model.delegates perform:@selector(modelDidCancelLoad:) withObject:self.model];    
    if (text.length)
    {
        [self.model.delegates perform:@selector(modelDidStartLoad:) withObject:self.model];
        NSPredicate * predicate = [NSPredicate predicateWithFormat:@"label contains[cd] %@", text];
        self.filteredListContent = [[_fetchedResultsController fetchedObjects] filteredArrayUsingPredicate:predicate];        
        [self.model.delegates perform:@selector(modelDidFinishLoad:) withObject:self.model];
    }
    else        
    {
        [self.model.delegates perform:@selector(modelDidFinishLoad:) withObject:self.model];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSArray*)sectionIndexTitlesForTableView:(UITableView*)tableView {
    if (!_forSearch && [[self currentSortName] isEqualToString:@"Title"] )
    {        
        //        return [TTSectionedDataSource lettersForSectionsWithSearch:YES summary:YES];
        NSMutableArray* titles = [NSMutableArray array];
        [titles addObject:UITableViewIndexSearch];
        
        int count = [[self.fetchedResultsController sections] count];
        for (int i = 0; i < count; ++i) {
            id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:i];
            [titles addObject:[sectionInfo indexTitle]];
        }
        
        return titles;
    }
    else
    {
        return nil;
    }
}

- (NSString *)controller:(NSFetchedResultsController *)controller sectionIndexTitleForSectionName:(NSString *)sectionName 
{
    return sectionName;
}



@end

