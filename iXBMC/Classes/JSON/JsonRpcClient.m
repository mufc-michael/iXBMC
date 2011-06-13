//
//  JsonRpcClient.m
//
//  Created by mstegmann on 28.07.09.
//

#import "JsonRpcClient.h"
#import "JSONKit.h"

@implementation CustomURLConnection

@synthesize tag;

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)startImmediately tag:(NSDictionary*)tg {
    self = [super initWithRequest:request delegate:delegate startImmediately:startImmediately];
    
    if (self) {
        self.tag = [tg retain];
    }
    return self;
}

- (void)dealloc {
    [tag release];
    [super dealloc];
}

@end

@implementation JsonRpcClient

@synthesize requestId;
@synthesize url;
@synthesize delegate;

- (NSMutableData*)dataForConnection:(CustomURLConnection*)connection {
   NSMutableData *data = [receivedData objectForKey:[connection.tag objectForKey:@"id"]];
    return data;
}

- (void)connection:(CustomURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSMutableData *dataForConnection = [self dataForConnection:connection];
    [dataForConnection setLength:0];
}

- (void)connection:(CustomURLConnection *)connection didReceiveData:(NSData *)data {
    NSMutableData *dataForConnection = [self dataForConnection:connection];
    [dataForConnection appendData:data];
}

- (void)connection:(CustomURLConnection *)connection didFailWithError:(NSError *)error {    
//    NSMutableData *dataForConnection = [self dataForConnection:(CustomURLConnection*)connection];
	NSDictionary *tag = [[[NSDictionary alloc] initWithDictionary:connection.tag] autorelease];
	NSDictionary *message = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"Unable to parse server response", @"message", nil];
	[self jsonRpcClient:self 
   didFailWithErrorCode:[NSNumber numberWithInt:0] 
                message:message
                    tag:tag];
    //NSMutableData *dataForConnection = [self dataForConnection:connection];
    [receivedData removeObjectForKey:[connection.tag objectForKey:@"id"]];
    [connection release];
}

- (void)connectionDidFinishLoading:(CustomURLConnection *)connection {
    NSMutableData *dataForConnection = [self dataForConnection:(CustomURLConnection*)connection];
    //[connection release];
    	
	NSError *error = nil;
	NSDictionary *dictionary = [dataForConnection objectFromJSONData];
 	//NSLog(@"json %@",dictionary);
    [receivedData removeObjectForKey:[connection.tag objectForKey:@"id"]];
	NSDictionary *tag = [NSDictionary dictionaryWithDictionary:connection.tag];
    [connection release];
	// Handle parse error
	if(error) {
		[self jsonRpcClient:self 
       didFailWithErrorCode:[NSNumber numberWithInt:[error code]] 
                    message:[NSDictionary dictionaryWithObjectsAndKeys:
                             @"Unable to parse server response", @"message", nil]
                        tag:tag];
		return;
	}
	
	// Handle error from server
	if([dictionary objectForKey:@"error"]) {
		NSDictionary *serverError = [dictionary objectForKey:@"error"];
		[self jsonRpcClient:self didFailWithErrorCode:[serverError objectForKey:@"code"] message:[serverError objectForKey:@"data"] tag:tag];
		return;
	}
	if ([[dictionary objectForKey:@"result"] isKindOfClass:[NSDictionary class]])
    {
        [self jsonRpcClient:self 
           didReceiveResult:[NSDictionary dictionaryWithDictionary:[dictionary objectForKey:@"result"]] tag:tag];
    }
        //    theConnection = nil;
}



- (id)init {
	self = [super init];
	protocol = @"2.0";
	requestId = @"0";
    receivedData = [[NSMutableDictionary alloc] init];
	return self;
}

- (id)initWithUrl:(NSURL *)newUrl delegate:(id)newDelegate {
	self = [self init];
	self.url = newUrl;
	self.delegate = newDelegate;
	
	return self;
}

- (void)requestWithUrl:(NSURL*)Rqurl data:(NSData *)requestData tag:(NSDictionary*)tag {
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:Rqurl];
	[request setValue:[[NSNumber numberWithInt:[requestData length]] stringValue] forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody: requestData];
	
    CustomURLConnection *connection = [[CustomURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES tag:tag];  
    if (connection) {
        [receivedData setObject:[NSMutableData data] forKey:[connection.tag objectForKey:@"id"]];
    }else {
        NSLog(@"Connection Failed!");
    }
}

- (void)requestWithMethod:(NSString *)method 
                   params:(NSObject *)params 
                   info:(NSDictionary *)info 
                   target:(NSObject*)object 
                 selector:(SEL)sel
{
    NSArray *jsonRpc = [NSDictionary dictionaryWithObjectsAndKeys:
						protocol, @"jsonrpc",
						method, @"method",
						params, @"params",
						self.requestId, @"id",
						nil];

//    NSLog(@"sending message %@", serialized);
	NSData *serializedData = [jsonRpc JSONData];
    
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
    NSDictionary* tag = [NSDictionary dictionaryWithObjectsAndKeys:
                         [NSString stringWithFormat:@"%f",time], @"id",
                         info?info:[[[NSDictionary alloc] init] autorelease], @"info",
                         method, @"cmd",
						object, @"object",
						[NSValue valueWithPointer:sel], @"selector",
						nil];
	[self requestWithUrl:self.url data:serializedData tag:tag];
}
- (void)requestWithMethod:(NSString *)method params:(NSObject *)params {
    [self requestWithMethod:method params:params info:nil target:nil selector:nil];
}

- (void)requestWithMethod:(NSString *)method {
	[self requestWithMethod:method params:[NSArray array]];
}




# pragma mark delegate

- (void)jsonRpcClientDidStartLoading:(JsonRpcClient *)client {
	if([[self delegate] respondsToSelector:@selector(jsonRpcClientDidStartLoading:)]) {
		[[self delegate] jsonRpcClientDidStartLoading:client];
	}		
}

- (void)jsonRpcClient:(JsonRpcClient *)client didReceiveResult:(id)result  tag:(NSDictionary*)tag {
	if([[self delegate] respondsToSelector:@selector(jsonRpcClient:didReceiveResult:tag:)]) {
		[[self delegate] jsonRpcClient:client didReceiveResult:result tag:tag];
//           NSLog(@"test %@",result);
	}	
}

- (void)jsonRpcClient:(JsonRpcClient *)client didFailWithErrorCode:(NSNumber *)code message:(NSDictionary *)message  tag:(NSDictionary*)tag {
	if([[self delegate] respondsToSelector:@selector(jsonRpcClient:didFailWithErrorCode:message:tag:)]) {
		[[self delegate] jsonRpcClient:client didFailWithErrorCode:code message: message tag:tag];
	}	
}

- (void)dealloc {
	[requestId release];
    [receivedData release];
	[url release];
	[super dealloc];
}

@end