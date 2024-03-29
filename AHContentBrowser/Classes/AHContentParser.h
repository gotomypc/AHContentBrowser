//
//  AHContentParser.h
//  AHContentBrowser
//
//  Created by John Wright on 9/10/12.
//  Copyright (c) 2012 John Wright. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AHSAXParser.h" 


@class AHContentParser;
typedef void(^AHContentParserHandler)(AHContentParser *parser);

@interface AHContentParser : NSObject <AHSaxParserDelegate>


@property (nonatomic, readonly) NSMutableArray *imageURLs;
@property (nonatomic, readonly) NSString* contentHTML;
@property (nonatomic) NSString* contentHTMLWithTemplate;
@property (nonatomic, readonly) NSString *htmlString;
@property (nonatomic) BOOL foundContent;
@property (nonatomic) NSURL *url;

-(void) start;

//- (id) initWithURL:(NSURL*) url;
- (id) initWithData:(NSData*) data handler:(AHContentParserHandler) handler;
//- (id) initWithString:(NSString*) string;

//- (NSArray*) imageURLsLargerThanSize:(CGSize) size;

@end
