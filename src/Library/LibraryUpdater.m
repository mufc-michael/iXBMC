//
//  LibraryUpdater.m
//  iHaveNoName
//
//  Created by Martin Guillon on 3/24/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ActiveManager.h"
#import "LibraryUpdater.h"
#import "XBMCJSONCommunicator.h"
#import "XBMCStateListener.h"
#import "AppDelegate.h"
#import "Movie.h"
#import "TVShow.h"
#import "Season.h"
#import "Episode.h"
#import "Actor.h"
#import "ActorRole.h"

@implementation NSArray (movieKeyedDictionaryExtension)

- (NSDictionary *)movieKeyedDictionary
{
    NSUInteger arrayCount = [self count];
    id arrayObjects[arrayCount], objectKeys[arrayCount];
    
    [self getObjects:arrayObjects range:NSMakeRange(0UL, arrayCount)];
    for(NSUInteger index = 0UL; index < arrayCount; index++) 
    { 
        objectKeys[index] = [[self objectAtIndex:index] valueForKey:@"movieid"]; 
    }
    
    return([NSDictionary dictionaryWithObjects:arrayObjects forKeys:objectKeys count:arrayCount]);
}

- (NSDictionary *)tvShowKeyedDictionary
{
    NSUInteger arrayCount = [self count];
    id arrayObjects[arrayCount], objectKeys[arrayCount];
    
    [self getObjects:arrayObjects range:NSMakeRange(0UL, arrayCount)];
    for(NSUInteger index = 0UL; index < arrayCount; index++) 
    { 
        objectKeys[index] = [[self objectAtIndex:index] valueForKey:@"tvshowid"]; 
    }
    
    return([NSDictionary dictionaryWithObjects:arrayObjects forKeys:objectKeys count:arrayCount]);
}

- (NSDictionary *)seasonKeyedDictionary
{
    NSUInteger arrayCount = [self count];
    id arrayObjects[arrayCount], objectKeys[arrayCount];
    
    [self getObjects:arrayObjects range:NSMakeRange(0UL, arrayCount)];
    for(NSUInteger index = 0UL; index < arrayCount; index++) 
    { 
        objectKeys[index] = [[self objectAtIndex:index] valueForKey:@"season"]; 
    }
    
    return([NSDictionary dictionaryWithObjects:arrayObjects forKeys:objectKeys count:arrayCount]);
}

- (NSDictionary *)episodeKeyedDictionary
{
    NSUInteger arrayCount = [self count];
    id arrayObjects[arrayCount], objectKeys[arrayCount];
    
    [self getObjects:arrayObjects range:NSMakeRange(0UL, arrayCount)];
    for(NSUInteger index = 0UL; index < arrayCount; index++) 
    { 
        objectKeys[index] = [[self objectAtIndex:index] valueForKey:@"episode"]; 
    }
    
    return([NSDictionary dictionaryWithObjects:arrayObjects forKeys:objectKeys count:arrayCount]);
}

- (NSDictionary *)actorKeyedDictionary
{
    NSUInteger arrayCount = [self count];
    id arrayObjects[arrayCount], objectKeys[arrayCount];
    
    [self getObjects:arrayObjects range:NSMakeRange(0UL, arrayCount)];
    for(NSUInteger index = 0UL; index < arrayCount; index++) 
    { 
        objectKeys[index] = [[self objectAtIndex:index] valueForKey:@"name"]; 
    }
    
    return([NSDictionary dictionaryWithObjects:arrayObjects forKeys:objectKeys count:arrayCount]);
}

@end

@interface LibraryUpdater()
- (void)gotMoviesJson:(id)result clean:(BOOL)canDelete;
- (void)gotMoviesJson:(id)result;

- (void)updateAllTVShowsCoreData:(id)result;
- (void)updateAllTVShowsCoreData:(id)result clean:(BOOL)canDelete;
- (void)updateAllTVShowsCoreDataBackgroundThread:(id)result clean:(BOOL)canDelete;

- (void)updateTVShow:(NSInteger) tvshowid hidden:(BOOL) hid;
- (void)updateTVShowCoreData:(id)result;
- (void)updateTVShowCoreData:(id)result clean:(BOOL)canDelete;
- (void)updateTVShowCoreDataBackgroundThread:(id)result clean:(BOOL)canDelete;


- (void)updateSeason:(NSInteger) tvshowid season:(NSInteger)seasonid hidden:(BOOL) hid;
- (void)updateSeasonCoreData:(id)result;
- (void)updateSeasonCoreData:(id)result clean:(BOOL)canDelete;
- (void)updateSeasonCoreDataBackgroundThread:(id)result clean:(BOOL)canDelete;

@end

@implementation LibraryUpdater
static LibraryUpdater *sharedInstance = nil;
@synthesize recentlyAddedMovies = _recentlyAddedMovies;
@synthesize recentlyAddedEpisodes = _recentlyAddedEpisodes;
@synthesize updating = _updating;

+ (LibraryUpdater *) sharedInstance {
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}
- (void)dealloc {
	
    TT_RELEASE_SAFELY(_recentlyAddedEpisodes);
    TT_RELEASE_SAFELY(_recentlyAddedMovies);
	[self stop];
	// wait for queue to empty
	dispatch_sync(_queue, ^{});
    [super dealloc];
}

+ (BOOL) updating
{
    return sharedInstance.updating;
}

- (void)start
{
	_lettersCharSet = [[ NSCharacterSet letterCharacterSet ] retain];

	_queue = dispatch_queue_create("com.ixbmc.library", NULL);
	_valid = TRUE;
    _updating = false;
	_nbrunningUpdates = 0;
    [self updateLibrary];
//    _updatingTimer = [NSTimer scheduledTimerWithTimeInterval: 600.0
//                                                       target: self
//                                                     selector: @selector(updateLibrary)
//                                                     userInfo: nil repeats:TRUE];
}

- (void)oneUpdateStarted
{
	if (_nbrunningUpdates == 0)
	{
	    [[NSNotificationCenter defaultCenter] 
		 postNotificationName:@"updatingLibrary" 
		 object:nil];	
	}
	_nbrunningUpdates += 1;
}

- (void)oneUpdateFinished
{
    if (_nbrunningUpdates == 0) return;
	_nbrunningUpdates -= 1;
	if (_nbrunningUpdates == 0)
	{
	    [[NSNotificationCenter defaultCenter] 
		 postNotificationName:@"updatedLibrary" 
		 object:nil];	
	}
}

- (void)stop
{
	
	if (_updatingTimer != nil)
    {
        [_updatingTimer invalidate];
        _updatingTimer = nil;
    }
	_valid = FALSE;
	// wait for queue to empty
	dispatch_sync(_queue, ^{});
	dispatch_release(_queue);
	[_lettersCharSet release];

}

#pragma mark -
#pragma mark Movies


-(void)gotMoviesJson:(id)result
{
    [self gotMoviesJson:result clean:YES];
}

- (void)gotMoviesJson:(id)result clean:(BOOL)canDelete
{
    NSDate *start = [NSDate date];

	BOOL hidden = [[[result objectForKey:@"info"] 
					objectForKey:@"hiddenUpdate"] boolValue];

    if (![[result objectForKey:@"failure"] boolValue])
    {
        [MRCoreDataAction saveDataInBackgroundWithBlock:^(NSManagedObjectContext *localContext){
            NSArray* movies = [[result objectForKey:@"result"] objectForKey:@"movies"];
        
            NSDictionary *newMovies = [movies movieKeyedDictionary];
        
            NSArray *moviesInDB = [Movie MR_findAll];
            NSArray *actorsInDB = [Actor MR_findAll];

            NSDictionary *moviesInDBKeys = [moviesInDB movieKeyedDictionary];

            NSDictionary *actorsInDBKeys = [actorsInDB actorKeyedDictionary];       
        
            NSSet *existingItems = [NSSet setWithArray:[moviesInDBKeys allKeys]];
            NSSet *newItems = [NSSet setWithArray:[newMovies allKeys]];
        
            // Determine which items were added
            NSMutableSet *addedItems = [NSMutableSet setWithSet:newItems];
            [addedItems minusSet:existingItems];
        
            // Determine which items were added
            NSMutableSet *toUpdateItems = [NSMutableSet setWithSet:newItems];
            [toUpdateItems intersectSet:existingItems];       
        

        
            NSLog(@"existing Items count %d", [existingItems count]);
            NSLog(@"adding Items count %d", [addedItems count]);
        

            
            NSEnumerator *enumerator = [addedItems objectEnumerator];
            id anObject;
            anObject = [enumerator nextObject];
            
            while (anObject) 
            {
                id newMovie = [newMovies objectForKey:anObject];
                NSString* label = [newMovie valueForKey:@"label"];
            
                if ([label length] > 0)
                {
           
                    Movie *localMovie = [Movie MR_createInContext:localContext];
                    
                    NSString* sortLabel = [[label stringByReplacingOccurrencesOfString:@"The " withString:@""]
                                           stringByReplacingOccurrencesOfString:@"the " withString:@""];
                    localMovie.label = label;
                    localMovie.sortLabel = sortLabel;
                    
                    [NSCharacterSet alphanumericCharacterSet];
                    if ([_lettersCharSet characterIsMember:[sortLabel characterAtIndex:0]]) {
                        localMovie.firstLetter = [[sortLabel substringToIndex:1] uppercaseString];
                    }
                    else
                    {
                        localMovie.firstLetter = @"#";
                    }
                    
                    localMovie.director = [newMovie valueForKey:@"director"];
                    localMovie.runtime = [newMovie valueForKey:@"runtime"];
                    localMovie.writer = [newMovie valueForKey:@"writer"];
                    localMovie.studio = [newMovie valueForKey:@"studio"];
                    localMovie.movieid = [NSNumber numberWithInt:[[newMovie valueForKey:@"movieid"] intValue]];
                    localMovie.rating = [NSNumber numberWithFloat:[[newMovie valueForKey:@"rating"] floatValue]];
                    localMovie.plot = [newMovie valueForKey:@"plot"];
                    localMovie.tagline = [newMovie valueForKey:@"tagline"];
                    localMovie.genre = [newMovie valueForKey:@"genre"];
                    localMovie.fanart = [newMovie valueForKey:@"fanart"];
                    localMovie.thumbnail = [newMovie valueForKey:@"thumbnail"];
                    localMovie.imdbid = [newMovie valueForKey:@"imdbnumber"];
                    localMovie.year = [newMovie valueForKey:@"year"];
                    localMovie.playcount = [newMovie valueForKey:@"playcount"];
                    localMovie.trailer = [newMovie valueForKey:@"trailer"];
                    localMovie.file = [newMovie valueForKey:@"file"];
                    
                    
//                    if ([newMovie objectForKey:@"cast"] && [[newMovie objectForKey:@"cast"] isKindOfClass:[NSArray class]])
//                    {
//                        for (NSDictionary* role in [newMovie objectForKey:@"cast"])
//                        {
//                            NSString *actorName = [role valueForKey:@"name"];
//                            NSString *actorRole = [role valueForKey:@"role"];
//                            Actor *localActor;
//                            
//                            if ([actorsInDBKeys objectForKey:actorName] != nil) {
//                                localActor = [[actorsInDBKeys objectForKey:actorName] MR_inContext:localContext];
//                            }
//                            else
//                            {
//                                localActor = [Actor MR_createInContext:localContext];
//                                localActor.name = actorName;
//                            }
////                            ActorRole *localRole = [ActorRole MR_createInContext:localContext];
////                            localRole.role = actorRole;
////                            localRole.actorName = actorName;
//////                            localRole.actor = localActor;
////                            [localRole addMoviesObject:localMovie];
////                            [localActor addRolesObject:localRole];
////                            [localMovie addRolesObject:localRole];
//                        }
//                    }
                }

                anObject = [enumerator nextObject];
            }
            enumerator = [toUpdateItems objectEnumerator];
            
            anObject = [enumerator nextObject];
            while (anObject) 
            {
                id newMovie = [newMovies objectForKey:anObject];
                //            NSLog(@"movie %@", newMovie);
                Movie* localMovie = [[moviesInDBKeys objectForKey:anObject] MR_inContext:localContext];
                
                if (![[newMovie valueForKey:@"playcount"] isEqual: localMovie.playcount])
                {
                    localMovie.playcount = [newMovie valueForKey:@"playcount"];
                }
                
                anObject = [enumerator nextObject];
            }
            
            if (canDelete)
            {
                // Determine which items were removed
                NSMutableSet *removedItems = [NSMutableSet setWithSet:existingItems];
                [removedItems minusSet:newItems];
                enumerator = [removedItems objectEnumerator];
                
                anObject = [enumerator nextObject];
                while (anObject) 
                {
                    [[[moviesInDBKeys objectForKey:anObject] MR_inContext:localContext] MR_deleteEntity];
                    anObject = [enumerator nextObject];
                }
            }    
            
        } completion:^{
            if (!hidden) [self oneUpdateFinished];
            NSTimeInterval timeInterval = [start timeIntervalSinceNow];
            NSLog(@"updateMovies time %f",timeInterval);
        }];
        
        
    }
//    [pool drain];
	
    
}

- (void) updateMovies:(NSInteger) number hidden:(BOOL)hid
{
    if (![XBMCStateListener connected]) return;
	if (!hid) [self oneUpdateStarted];
	
    NSMutableDictionary *requestParams = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										  [NSArray arrayWithObjects:@"title", @"sorttitle"
										   , @"plot", @"director", @"writer"
										   , @"studio", @"genre", @"year", @"runtime", @"rating"
										   , @"tagline", @"imdbnumber",@"trailer",
										   @"lastplayed",@"thumbnail",@"fanart",
										   @"playcount", @"file"
										   , @"streamdetails", @"cast", nil]
										  , @"properties", nil];
    if (number > 0)
    {
        [requestParams addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
												 [NSDictionary dictionaryWithObjectsAndKeys:
												  [NSNumber numberWithInt:0], @"start", 
												  [NSNumber numberWithInt:number], @"end", nil]
												 , @"limits", nil]];
    }
    
    [requestParams addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
											 [NSDictionary dictionaryWithObjectsAndKeys:
											  @"none", @"method", nil]
											 , @"sort", nil]];
	
//    dispatch_async(_queue, ^{

        NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
							 @"VideoLibrary.GetMovies", @"cmd", requestParams, @"params",nil];
        [[XBMCJSONCommunicator sharedInstance] addJSONRequest:request target:self selector:@selector(gotMoviesJson:)];
//    });
}


- (void)gotRecentlyAddedMovies:(id)result
{
    if (![[result objectForKey:@"failure"] boolValue])
    {
        TT_RELEASE_SAFELY(_recentlyAddedMovies);
        
        [self gotMoviesJson:result clean:NO];
        
        if ([[result objectForKey:@"result"] objectForKey:@"movies"] != nil)
        {
            NSMutableArray* movies = [[NSMutableArray alloc] init];
            for (NSDictionary* movie in [[result objectForKey:@"result"] objectForKey:@"movies"])
            {
                //NSDictionary* movie = [result objectForKey:@"movies"];
                [movies addObject:[[[NSDictionary alloc] initWithObjectsAndKeys:
                                    [NSNumber numberWithInt:[[movie valueForKey:@"movieid"] intValue]], @"id"
                                    ,[movie objectForKey:@"label"], @"label"
                                    ,[movie objectForKey:@"thumbnail"], @"thumbnail"
                                    ,[movie objectForKey:@"fanart"], @"fanart"
                                    ,[movie objectForKey:@"trailer"], @"trailer"
                                    ,[movie objectForKey:@"imdbnumber"], @"imdb"
                                    ,[movie objectForKey:@"playcount"], @"playcount"
                                    ,[movie objectForKey:@"file"], @"file"
                                    , nil] autorelease]];
            }
            _recentlyAddedMovies = [movies retain];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"recentlyAddedMovies"  object:nil];
        }
    }
}

- (void) updateRecentlyAddedMovies:(NSInteger) number hidden:(BOOL)hid
{
    if (![XBMCStateListener connected]) return;
	if (!hid) [self oneUpdateStarted];

    NSMutableDictionary *requestParams = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                           [NSArray arrayWithObjects:@"plot", @"director", @"writer"
                                            , @"studio", @"genre", @"year", @"runtime", @"rating"
                                            , @"tagline", @"imdbnumber",@"trailer",
                                            @"lastplayed",@"thumbnail",@"fanart",
                                            @"playcount", @"file", nil]
                                           , @"properties", nil];
    if (number > 0)
    {
        [requestParams addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
												  [NSDictionary dictionaryWithObjectsAndKeys:
													[NSNumber numberWithInt:0], @"start", 
												   [NSNumber numberWithInt:number], @"end", nil]
												  , @"limits", nil]];
    }
    
    [requestParams addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
											  [NSDictionary dictionaryWithObjectsAndKeys:
												@"none", @"method", nil]
											  , @"sort", nil]];
    
    NSDictionary *request = [[[NSDictionary alloc] initWithObjectsAndKeys:
                              @"VideoLibrary.GetRecentlyAddedMovies", @"cmd", requestParams, @"params",nil] autorelease];
    [[XBMCJSONCommunicator sharedInstance] addJSONRequest:request target:self selector:@selector(gotRecentlyAddedMovies:)];    
}

- (void) updateRecentlyAddedMovies:(BOOL)hid
{
    [self updateRecentlyAddedMovies:0 hidden:hid];
}


#pragma mark -
#pragma mark AllTVShows

- (void)updateAllTVShowsCoreDataBackgroundThread:(id)result clean:(BOOL)canDelete

{
	BOOL hidden = [[[result objectForKey:@"info"] 
					objectForKey:@"hiddenUpdate"] boolValue];
	//	NSLog(@"AllTVShows update %@", result);
	NSManagedObjectContext *context = [[[NSManagedObjectContext alloc] init] autorelease];
    NSPersistentStoreCoordinator *coordinator = [[ActiveManager shared] persistentStoreCoordinator];
    [context setPersistentStoreCoordinator:coordinator];
    [context setUndoManager:nil];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (![[result objectForKey:@"failure"] boolValue])
    {
        NSError *error = nil;
        NSArray* shows = [[result objectForKey:@"result"] objectForKey:@"tvshows"];
        
        NSDictionary *newshows = [shows tvShowKeyedDictionary];
        
		
        NSFetchRequest *showFetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *showEntity = [NSEntityDescription entityForName:@"TVShow" inManagedObjectContext:context];
        [showFetchRequest setEntity:showEntity];
        NSArray *showsArray = [context executeFetchRequest:showFetchRequest error:&error];
        [showFetchRequest release];
        if (error) 
        {
			[self oneUpdateFinished];
            NSLog(@"error during update: %@", [error localizedDescription]);
            [pool drain];
            return;
        }
        NSDictionary *oldshows = [showsArray tvShowKeyedDictionary];
        
//        NSFetchRequest *actorFetchRequest = [[NSFetchRequest alloc] init];
//        NSEntityDescription *actorEntity = [NSEntityDescription entityForName:@"Actor" inManagedObjectContext:context];
//        [actorFetchRequest setEntity:actorEntity];
//        NSArray *actorArray = [context executeFetchRequest:actorFetchRequest error:&error];
//        [actorFetchRequest release];
//		
//        NSDictionary *oldActors = [actorArray actorKeyedDictionary];       
        
        NSSet *existingItems = [NSSet setWithArray:[oldshows allKeys]];
        NSSet *newItems = [NSSet setWithArray:[newshows allKeys]];
        
        // Determine which items were added
        NSMutableSet *addedItems = [NSMutableSet setWithSet:newItems];
        [addedItems minusSet:existingItems];
        
        // Determine which items were added
        NSMutableSet *toUpdateItems = [NSMutableSet setWithSet:newItems];
        [toUpdateItems intersectSet:existingItems];       
        
        NSEnumerator *enumerator = [addedItems objectEnumerator];
        id anObject;
        
        NSLog(@"existing shows count %d", [existingItems count]);
        NSLog(@"adding shows count %d", [addedItems count]);
        
        anObject = [enumerator nextObject];
        while (anObject) 
        {
            id newshow = [newshows objectForKey:anObject];
            NSString* label = [newshow valueForKey:@"label"];
            
            if (![label isEqualToString:@""])
            {
				
                TVShow *show;
                show = [NSEntityDescription insertNewObjectForEntityForName:@"TVShow" inManagedObjectContext:context];
				
                NSString* sortLabel = [[label stringByReplacingOccurrencesOfString:@"The " withString:@""]
									   stringByReplacingOccurrencesOfString:@"the " withString:@""];
                [show setValue:label forKey:@"label"];
                [show setValue:sortLabel forKey:@"sortLabel"];
                
                [NSCharacterSet alphanumericCharacterSet];
                if ([_lettersCharSet characterIsMember:[sortLabel characterAtIndex:0]]) {
                    [show setValue:[[sortLabel substringToIndex:1] uppercaseString] forKey:@"firstLetter"];
                }
                else
                {
                    [show setValue:@"#" forKey:@"firstLetter"];
                }
				
                [show setValue:[newshow valueForKey:@"premiered"] forKey:@"premiered"];
                [show setValue:[newshow valueForKey:@"studio"] forKey:@"studio"];
                [show setValue:[NSNumber numberWithInt:[[newshow valueForKey:@"tvshowid"] intValue]] forKey:@"tvshowid"];
                [show setValue:[NSNumber numberWithFloat:[[newshow valueForKey:@"rating"] floatValue]] forKey:@"rating"];
                [show setValue:[newshow valueForKey:@"plot"] forKey:@"plot"];
                [show setValue:[newshow valueForKey:@"genre"] forKey:@"genre"];
                [show setValue:[newshow valueForKey:@"fanart"] forKey:@"fanart"];
                [show setValue:[newshow valueForKey:@"thumbnail"] forKey:@"thumbnail"];
                [show setValue:[newshow valueForKey:@"imdbnumber"] forKey:@"tvdbid"];
                
//                if ([newshow objectForKey:@"cast"] && [[newshow objectForKey:@"cast"] isKindOfClass:[NSArray class]])
//                {
//                    for (NSDictionary* role in [newshow objectForKey:@"cast"])
//                    {
//                        NSString *actorName = [role valueForKey:@"name"];
//                        NSString *actorRole = [role valueForKey:@"role"];
//                        Actor *actor;
//                        
//                        if ([oldActors objectForKey:actorName] != nil) {
//                            actor = [oldActors objectForKey:actorName];
//                        }
//                        else
//                        {
//                            actor = [NSEntityDescription insertNewObjectForEntityForName:@"Actor" inManagedObjectContext:context];
//                            [actor setValue:actorName forKey:@"name"];
//                        }
//                        ActorRole *newRole = [NSEntityDescription insertNewObjectForEntityForName:@"ActorRole" inManagedObjectContext:context];;
//                        newRole.role = actorRole;
//                        [actor addActorToRoleObject:newRole];
//                        [show addTVShowToRoleObject:newRole];
//                    }
//                }
				
            }
            anObject = [enumerator nextObject];
        }
		
//		enumerator = [toUpdateItems objectEnumerator];
//        
//        anObject = [enumerator nextObject];
//        while (anObject) 
//        {
//            id newshow = [newshows objectForKey:anObject];
//			//            NSLog(@"season %@", newseason);
//            NSManagedObject *oldseason = [oldshows objectForKey:anObject];
//			
////            if (![[newshow valueForKey:@"playcount"] isEqual: [oldseason valueForKey:@"playcount"]])
////            {
////                [oldseason setValue:[newshow valueForKey:@"playcount"] forKey:@"playcount"];
////            }
//			if (![[newshow valueForKey:@"episode"] isEqual: [oldseason valueForKey:@"nbepisodes"]])
//            {
//                [oldseason setValue:[newshow valueForKey:@"episode"] forKey:@"nbepisodes"];
//            }
//			
//            anObject = [enumerator nextObject];
//        }
        
        if (canDelete)
        {
            // Determine which items were removed
            NSMutableSet *removedItems = [NSMutableSet setWithSet:existingItems];
            [removedItems minusSet:newItems];
            enumerator = [removedItems objectEnumerator];
            
            anObject = [enumerator nextObject];
            while (anObject) 
            {
                [context deleteObject:[oldshows objectForKey:anObject]];
                
                anObject = [enumerator nextObject];
            }
        }
		
//		[[[ActiveManager shared] persistentStoreCoordinator] lock];
//		[context save:&error];
//		if(error) {
//			// handle error
//		}
//		[[[ActiveManager shared] persistentStoreCoordinator] unlock];
		for (NSDictionary* show in shows)
		{
			dispatch_sync(dispatch_get_main_queue(), ^{
			[self updateTVShow:[[show valueForKey:@"tvshowid"] intValue] hidden:hidden];
			});
		}
    }
    [pool drain];
	if (!hidden) [self oneUpdateFinished];
}

-(void)updateAllTVShowsCoreData:(id)result clean:(BOOL)canDelete
{	
	dispatch_async(_queue, ^{
        [self updateAllTVShowsCoreDataBackgroundThread:result clean:canDelete];});
}

-(void)updateAllTVShowsCoreData:(id)result
{
    [self updateAllTVShowsCoreData:result clean:YES];
}

- (void) updateAllTVShows:(NSInteger) number hidden:(BOOL)hid
{
	if (![XBMCStateListener connected]) return;
	if (!hid) [self oneUpdateStarted];
    NSMutableDictionary *requestParams = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										  [NSArray arrayWithObjects:@"title", @"originaltitle"
										   , @"plot", @"cast", @"episode", @"premiered", @"file"
										   , @"studio", @"genre", @"rating", @"imdbnumber", @"fanart", @"thumbnail", nil]
										  , @"properties", nil];
    if (number > 0)
    {
        [requestParams addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
												 [NSDictionary dictionaryWithObjectsAndKeys:
												  [NSNumber numberWithInt:0], @"start", 
												  [NSNumber numberWithInt:number], @"end", nil]
												 , @"limits", nil]];
    }
    
    [requestParams addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
											 [NSDictionary dictionaryWithObjectsAndKeys:
											  @"date", @"method", nil]
											 , @"sort", nil]];
	
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
							 @"VideoLibrary.GetTVShows", @"cmd", requestParams, @"params",nil];
    [[XBMCJSONCommunicator sharedInstance] addJSONRequest:request target:self selector:@selector(updateAllTVShowsCoreData:)]; 
}

#pragma mark -
#pragma mark Recent Episodes

- (void)gotRecentlyAddedEpisodes:(id)result
{
    if (![[result objectForKey:@"failure"] boolValue])
    {
        TT_RELEASE_SAFELY(_recentlyAddedEpisodes);
//		NSLog(@"recentEpisodes %@", result);
        
//        [self updateEpisodesCoreData:result clean:NO];
        
        if ([[result objectForKey:@"result"] objectForKey:@"episodes"] != nil)
        {
            NSMutableArray* episodes = [[NSMutableArray alloc] init];
            for (NSDictionary* episode in [[result objectForKey:@"result"] objectForKey:@"episodes"])
            {
                [episodes addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:[[episode valueForKey:@"episodeid"] intValue]], @"id"
                                    ,[episode objectForKey:@"label"], @"label"
                                    ,[episode objectForKey:@"thumbnail"], @"thumbnail"
                                    ,[episode objectForKey:@"fanart"], @"fanart"
                                    ,[episode objectForKey:@"season"], @"season"
                                    ,[episode objectForKey:@"showtitle"], @"showtitle"
                                    ,[episode objectForKey:@"episode"], @"episode"
                                    ,[episode objectForKey:@"playcount"], @"playcount"
                                    ,[episode objectForKey:@"file"], @"file"
                                    , nil]];
            }
            _recentlyAddedEpisodes = [episodes retain];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"recentlyAddedEpisodes"  object:nil];
        }
    }
}

- (void) updateRecentlyAddedEpisodes:(NSInteger) number hidden:(BOOL)hid
{
    if (![XBMCStateListener connected]) return;
	if (!hid) [self oneUpdateStarted];
	
    NSMutableDictionary *requestParams = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										  [NSArray arrayWithObjects:@"season", @"showtitle"
										   , @"episode", @"playcount",@"file"
										   , @"fanart", @"thumbnail", nil]
										  , @"properties", nil];
    if (number > 0)
    {
        [requestParams addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
												 [NSDictionary dictionaryWithObjectsAndKeys:
												  [NSNumber numberWithInt:0], @"start", 
												  [NSNumber numberWithInt:number], @"end", nil]
												 , @"limits", nil]];
    }
    
    [requestParams addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
											 [NSDictionary dictionaryWithObjectsAndKeys:
											  @"none", @"method", nil]
											 , @"sort", nil]];
    
    NSDictionary *request = [[[NSDictionary alloc] initWithObjectsAndKeys:
                              @"VideoLibrary.GetRecentlyAddedEpisodes", @"cmd", requestParams, @"params",nil] autorelease];
    [[XBMCJSONCommunicator sharedInstance] addJSONRequest:request target:self selector:@selector(gotRecentlyAddedEpisodes:)];    
}

- (void) updateRecentlyAddedEpisodes:(BOOL)hid
{
    [self updateRecentlyAddedEpisodes:0 hidden:hid];
}


#pragma mark -
#pragma mark TVShow

- (void)updateTVShowCoreDataBackgroundThread:(id)result clean:(BOOL)canDelete

{
	BOOL hidden = [[[result objectForKey:@"info"] 
					objectForKey:@"hiddenUpdate"] boolValue];
	NSManagedObjectContext *context = [[[NSManagedObjectContext alloc] init] autorelease];
    NSPersistentStoreCoordinator *coordinator = [[ActiveManager shared] persistentStoreCoordinator];
    [context setPersistentStoreCoordinator:coordinator];
    [context setUndoManager:nil];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (![[result objectForKey:@"failure"] boolValue])
    {
		NSNumber* tvshowid = [[result objectForKey:@"info"] objectForKey:@"tvshowid"];
        NSError *error = nil;
        NSArray* seasons = [[result objectForKey:@"result"] objectForKey:@"seasons"];
        
        NSDictionary *newseasons = [seasons seasonKeyedDictionary];
        
		
        NSFetchRequest *seasonFetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *seasonEntity = [NSEntityDescription entityForName:@"Season" inManagedObjectContext:context];
        [seasonFetchRequest setPredicate:[NSPredicate 
										predicateWithFormat:@"tvshowid == %@"
										,tvshowid]];
		[seasonFetchRequest setEntity:seasonEntity];
        NSArray *seasonsArray = [context executeFetchRequest:seasonFetchRequest error:&error];
        [seasonFetchRequest release];
        if (error) 
        {
			[self oneUpdateFinished];
            NSLog(@"error during update: %@", [error localizedDescription]);
            [pool drain];
            return;
        }
        NSDictionary *oldseasons = [seasonsArray seasonKeyedDictionary];      
        
        NSSet *existingItems = [NSSet setWithArray:[oldseasons allKeys]];
        NSSet *newItems = [NSSet setWithArray:[newseasons allKeys]];
        
        // Determine which items were added
        NSMutableSet *addedItems = [NSMutableSet setWithSet:newItems];
        [addedItems minusSet:existingItems];
        
        // Determine which items were added
        NSMutableSet *toUpdateItems = [NSMutableSet setWithSet:newItems];
        [toUpdateItems intersectSet:existingItems];       
        
        NSEnumerator *enumerator = [addedItems objectEnumerator];
        id anObject;
        
        anObject = [enumerator nextObject];
        while (anObject) 
        {
            id newseason = [newseasons objectForKey:anObject];
            NSString* label = [newseason valueForKey:@"label"];
            
            if (![label isEqualToString:@""])
            {
                Season *season;
                season = [NSEntityDescription insertNewObjectForEntityForName:@"Season" inManagedObjectContext:context];
				
                [season setValue:label forKey:@"label"];
				
                [season setValue:tvshowid forKey:@"tvshowid"];
                [season setValue:[NSNumber numberWithInt:[[newseason valueForKey:@"season"] intValue]] forKey:@"season"];
                [season setValue:[newseason valueForKey:@"fanart"] forKey:@"fanart"];
                [season setValue:[newseason valueForKey:@"thumbnail"] forKey:@"thumbnail"];
				
				NSArray *array = [context fetchObjectsForEntityName:@"TVShow" withPredicate:
								  [NSPredicate predicateWithFormat:@"tvshowid == %@", tvshowid]];
				
				if (array == nil || [array count] ==0) {
					[self oneUpdateFinished];
					NSLog(@"Could not find tvshow %@ dealing with season %@"
						  , tvshowid, [newseason valueForKey:@"season"]);
					[pool drain];
					return;
				}
				TVShow* show = (TVShow*)[array objectAtIndex:0];
				[show addSeasonsObject:season];
				season.tvshow = show;
			}
            anObject = [enumerator nextObject];
        }
        
//        enumerator = [toUpdateItems objectEnumerator];
//        
//        anObject = [enumerator nextObject];
//        while (anObject) 
//        {
//            id newseason = [newseasons objectForKey:anObject];
//			//            NSLog(@"season %@", newseason);
//            NSManagedObject *oldseason = [oldseasons objectForKey:anObject];
//			
//            if (![[newseason valueForKey:@"playcount"] isEqual: [oldseason valueForKey:@"playcount"]])
//            {
//                [oldseason setValue:[newseason valueForKey:@"playcount"] forKey:@"playcount"];
//            }
//			if (![[newseason valueForKey:@"episode"] isEqual: [oldseason valueForKey:@"nbepisodes"]])
//            {
//                [oldseason setValue:[newseason valueForKey:@"episode"] forKey:@"nbepisodes"];
//            }
//			
//            anObject = [enumerator nextObject];
//        }
        
        if (canDelete)
        {
            // Determine which items were removed
            NSMutableSet *removedItems = [NSMutableSet setWithSet:existingItems];
            [removedItems minusSet:newItems];
            enumerator = [removedItems objectEnumerator];
            
            anObject = [enumerator nextObject];
            while (anObject) 
            {
                [context deleteObject:[oldseasons objectForKey:anObject]];
                
                anObject = [enumerator nextObject];
            }
        }
//		[[[ActiveManager shared] persistentStoreCoordinator] lock];
//		[context save:&error];
//		if(error) {
//			// handle error
//		}
//		[[[ActiveManager shared] persistentStoreCoordinator] unlock];
		for (NSDictionary* season in seasons)
		{
			dispatch_sync(dispatch_get_main_queue(), ^{ 
				[self updateSeason:[tvshowid intValue]
				  season:[[season valueForKey:@"season"] intValue] hidden:hidden];
			});
		}
    }
    [pool drain];
	if (!hidden) [self oneUpdateFinished];
}

-(void)updateTVShowCoreData:(id)result clean:(BOOL)canDelete
{	
	dispatch_async(_queue, ^{
        [self updateTVShowCoreDataBackgroundThread:result clean:canDelete];});
}

-(void)updateTVShowCoreData:(id)result
{
//	NSLog(@"updateTVShowCoreData: %@", result);
    [self updateTVShowCoreData:result clean:YES];
}

- (void) updateTVShow:(NSInteger) tvshowid hidden:(BOOL)hid
{
	if (![XBMCStateListener connected]) return;
	[self oneUpdateStarted];
    NSDictionary *requestParams = [NSDictionary dictionaryWithObjectsAndKeys:
										  [NSArray arrayWithObjects:@"season", @"showtitle"
										   , @"episode", @"fanart", @"thumbnail", nil]
										  , @"properties"
								   , [NSNumber numberWithInt:tvshowid],@"tvshowid"
										  ,[NSDictionary dictionaryWithObjectsAndKeys:
										   @"date", @"method", nil]
										  , @"sort", nil];
	
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
							 @"VideoLibrary.GetSeasons", @"cmd", requestParams, @"params"
							 ,[NSDictionary dictionaryWithObjectsAndKeys:
							   [NSNumber numberWithBool:hid], @"hiddenUpdate"
							   ,[NSNumber numberWithInt:tvshowid], @"tvshowid", nil], @"info",nil];
    [[XBMCJSONCommunicator sharedInstance] addJSONRequest:request target:self selector:@selector(updateTVShowCoreData:)]; 
}

#pragma mark -
#pragma mark Season

- (void)updateSeasonCoreDataBackgroundThread:(id)result clean:(BOOL)canDelete

{
	BOOL hidden = [[[result objectForKey:@"info"] 
					objectForKey:@"hiddenUpdate"] boolValue];
	NSManagedObjectContext *context = [[[NSManagedObjectContext alloc] init] autorelease];
    NSPersistentStoreCoordinator *coordinator = [[ActiveManager shared] persistentStoreCoordinator];
    [context setPersistentStoreCoordinator:coordinator];
    [context setUndoManager:nil];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (![[result objectForKey:@"failure"] boolValue])
    {
        NSError *error = nil;
        NSArray* episodes = [[result objectForKey:@"result"] objectForKey:@"episodes"];
        
        NSDictionary *newepisodes = [episodes episodeKeyedDictionary];
        
		
        NSFetchRequest *episodeFetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *episodeEntity = [NSEntityDescription entityForName:@"Episode" inManagedObjectContext:context];
        [episodeFetchRequest setPredicate:[NSPredicate 
										  predicateWithFormat:@"(tvshowid == %@) AND (seasonid == %@)"
										  ,[[result objectForKey:@"info"] objectForKey:@"tvshowid"]
										   ,[[result objectForKey:@"info"] objectForKey:@"season"]]];
		[episodeFetchRequest setEntity:episodeEntity];
        NSArray *episodesArray = [context executeFetchRequest:episodeFetchRequest error:&error];
        [episodeFetchRequest release];
        if (error) 
        {
			[self oneUpdateFinished];
            NSLog(@"error during update: %@", [error localizedDescription]);
            [pool drain];
            return;
        }
        NSDictionary *oldepisodes = [episodesArray episodeKeyedDictionary];      
        
//        NSFetchRequest *actorFetchRequest = [[NSFetchRequest alloc] init];
//        NSEntityDescription *actorEntity = [NSEntityDescription entityForName:@"Actor" inManagedObjectContext:context];
//        [actorFetchRequest setEntity:actorEntity];
//        NSArray *actorArray = [context executeFetchRequest:actorFetchRequest error:&error];
//        [actorFetchRequest release];
//		
//        NSDictionary *oldActors = [actorArray actorKeyedDictionary];       

        NSSet *existingItems = [NSSet setWithArray:[oldepisodes allKeys]];
        NSSet *newItems = [NSSet setWithArray:[newepisodes allKeys]];
        
        // Determine which items were added
        NSMutableSet *addedItems = [NSMutableSet setWithSet:newItems];
        [addedItems minusSet:existingItems];
        
        // Determine which items were added
        NSMutableSet *toUpdateItems = [NSMutableSet setWithSet:newItems];
        [toUpdateItems intersectSet:existingItems];       
        
        NSEnumerator *enumerator = [addedItems objectEnumerator];
        id anObject;
        
        anObject = [enumerator nextObject];
        while (anObject) 
        {
            id newepisode = [newepisodes objectForKey:anObject];
            NSString* label = [newepisode valueForKey:@"label"];
            
            if (![label isEqualToString:@""])
            {
                Episode *episode;
                episode = [NSEntityDescription insertNewObjectForEntityForName:@"Episode" inManagedObjectContext:context];
				
                [episode setValue:label forKey:@"label"];
				
				[episode setValue:[[result objectForKey:@"info"] objectForKey:@"tvshowid"] forKey:@"tvshowid"];
				[episode setValue:[NSNumber numberWithInt:[[newepisode valueForKey:@"season"] intValue]] forKey:@"seasonid"];
                [episode setValue:[NSNumber numberWithInt:[[newepisode valueForKey:@"episodeid"] intValue]] forKey:@"episodeid"];
                [episode setValue:[NSNumber numberWithInt:[[newepisode valueForKey:@"episode"] intValue]] forKey:@"episode"];

				
                [episode setValue:[newepisode valueForKey:@"director"] forKey:@"director"];
                [episode setValue:[newepisode valueForKey:@"runtime"] forKey:@"runtime"];
                [episode setValue:[newepisode valueForKey:@"writer"] forKey:@"writer"];
                [episode setValue:[newepisode valueForKey:@"firstaired"] forKey:@"firstaired"];
                [episode setValue:[NSNumber numberWithFloat:[[newepisode valueForKey:@"rating"] floatValue]] forKey:@"rating"];
                [episode setValue:[newepisode valueForKey:@"plot"] forKey:@"plot"];
                [episode setValue:[newepisode valueForKey:@"showtitle"] forKey:@"showtitle"];
                [episode setValue:[newepisode valueForKey:@"fanart"] forKey:@"fanart"];
                [episode setValue:[newepisode valueForKey:@"thumbnail"] forKey:@"thumbnail"];
                [episode setValue:[newepisode valueForKey:@"playcount"] forKey:@"playcount"];
                [episode setValue:[newepisode valueForKey:@"file"] forKey:@"file"];
                
//                if ([newepisode objectForKey:@"cast"] && [[newepisode objectForKey:@"cast"] isKindOfClass:[NSArray class]])
//                {
//                    for (NSDictionary* role in [newepisode objectForKey:@"cast"])
//                    {
//                        NSString *actorName = [role valueForKey:@"name"];
//                        NSString *actorRole = [role valueForKey:@"role"];
//                        Actor *actor;
//                        
//                        if ([oldActors objectForKey:actorName] != nil) {
//                            actor = [oldActors objectForKey:actorName];
//                        }
//                        else
//                        {
//                            actor = [NSEntityDescription insertNewObjectForEntityForName:@"Actor" inManagedObjectContext:context];
//                            [actor setValue:actorName forKey:@"name"];
//                        }
//						NSArray *array = [context fetchObjectsForEntityName:@"ActorRole" withPredicate:
//										  [NSPredicate predicateWithFormat:@"tvshowid == %@", [result objectForKey:@"info"]]];
//						if (array == nil || [array count] ==0) {
//							[self oneUpdateFinished];
//							NSLog(@"Could not find tvshow %@ dealing with episode %@"
//								  , [result objectForKey:@"info"], [newepisode valueForKey:@"episode"]);
//							[pool drain];
//							return;
//						}
//                        ActorRole *newRole = [NSEntityDescription insertNewObjectForEntityForName:@"ActorRole" inManagedObjectContext:context];;
//                        newRole.role = actorRole;
//                        [actor addActorToRoleObject:newRole];
//						[newRole setValue:episode forKey:@"name"];
//                        [episode add:newRole];
//                    }
//                }
				
				NSArray *array = [context fetchObjectsForEntityName:@"Season" withPredicate:
								  [NSPredicate 
								   predicateWithFormat:@"(tvshowid == %@) AND (season == %@)"
								   ,[[result objectForKey:@"info"] objectForKey:@"tvshowid"]
								   ,[[result objectForKey:@"info"] objectForKey:@"season"]]];
				
				if (array == nil || [array count] ==0) {
					[self oneUpdateFinished];
					NSLog(@"Could not find tvshow %@ dealing with episode %@"
						  , [result objectForKey:@"info"], [newepisode valueForKey:@"episode"]);
					[pool drain];
					return;
				}
				Season* season = (Season*)[array objectAtIndex:0];
				[season addEpisodesObject:episode];
				[season.tvshow addEpisodesObject:episode];
				episode.tvshow = season.tvshow;
				episode.season = season;
            }
            anObject = [enumerator nextObject];
        }
        
        enumerator = [toUpdateItems objectEnumerator];
        
        anObject = [enumerator nextObject];
        while (anObject) 
        {
            id newepisode = [newepisodes objectForKey:anObject];
			//            NSLog(@"episode %@", newepisode);
            NSManagedObject *oldepisode = [oldepisodes objectForKey:anObject];
			
            if (![[newepisode valueForKey:@"playcount"] isEqual: [oldepisode valueForKey:@"playcount"]])
            {
                [oldepisode setValue:[newepisode valueForKey:@"playcount"] forKey:@"playcount"];
            }
			
            anObject = [enumerator nextObject];
        }
        
        if (canDelete)
        {
            // Determine which items were removed
            NSMutableSet *removedItems = [NSMutableSet setWithSet:existingItems];
            [removedItems minusSet:newItems];
            enumerator = [removedItems objectEnumerator];
            
            anObject = [enumerator nextObject];
            while (anObject) 
            {
                [context deleteObject:[oldepisodes objectForKey:anObject]];
                
                anObject = [enumerator nextObject];
            }
        }
//		[[[ActiveManager shared] persistentStoreCoordinator] lock];
//		[context save:&error];
//		if(error) {
//			// handle error
//		}
//		[[[ActiveManager shared] persistentStoreCoordinator] unlock];
    }
    [pool drain];
	if (!hidden) [self oneUpdateFinished];
}

-(void)updateSeasonCoreData:(id)result clean:(BOOL)canDelete
{	
	dispatch_async(_queue, ^{
        [self updateSeasonCoreDataBackgroundThread:result clean:canDelete];});
}

-(void)updateSeasonCoreData:(id)result
{
	//	NSLog(@"updateTVShowCoreData: %@", result);
    [self updateSeasonCoreData:result clean:YES];
}

- (void) updateSeason:(NSInteger) tvshowid season:(NSInteger)seasonid hidden:(BOOL)hid
{
	if (![XBMCStateListener connected]) return;
	if (!hid) [self oneUpdateStarted];
    NSDictionary *requestParams = [NSDictionary dictionaryWithObjectsAndKeys:
								   [NSArray arrayWithObjects:@"season", @"showtitle"
									, @"episode", @"playcount",@"streamdetails"
									,@"firstaired",@"runtime",@"director",@"file"
									,@"writer",@"rating",@"cast", @"fanart", @"thumbnail", nil]
								   , @"properties"
								   , [NSNumber numberWithInt:tvshowid],@"tvshowid"
								   , [NSNumber numberWithInt:seasonid],@"season"
								   ,[NSDictionary dictionaryWithObjectsAndKeys:
									 @"date", @"method", nil]
								   , @"sort", nil];
	
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
							 @"VideoLibrary.GetEpisodes", @"cmd", requestParams, @"params"
							 ,[NSDictionary dictionaryWithObjectsAndKeys:
							   [NSNumber numberWithBool:hid], @"hiddenUpdate"
							   ,[NSNumber numberWithInt:tvshowid], @"tvshowid"
							   ,[NSNumber numberWithInt:seasonid], @"season", nil], @"info",nil];
    [[XBMCJSONCommunicator sharedInstance] addJSONRequest:request target:self selector:@selector(updateSeasonCoreData:)]; 
}


- (void) updateLibrary
{
    [self updateLibrary:0];
}

- (void) updateLibrary:(NSInteger) number
{
    [self updateMovies:number hidden:FALSE];
    
//    [self updateAllTVShows:number hidden:FALSE];
}

@end
