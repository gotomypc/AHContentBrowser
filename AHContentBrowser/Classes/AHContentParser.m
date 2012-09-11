//
//  AHContentParser.m
//  AHContentBrowser
//
//  Created by John Wright on 9/10/12.
//  Copyright (c) 2012 John Wright. All rights reserved.
//

#import "AHContentParser.h"


#define kAHContentTagsToKeep @"</?(?i:br|strong|ul|a|img|p)(.|\n)*?>"

@interface AHContentTextChunk : NSObject

@property (nonatomic) NSString *text;
@property (nonatomic) NSString *elementName;
@property (nonatomic) BOOL isQuote;
@property (nonatomic) NSRange textRange;
@property (nonatomic, weak) AHContentTextChunk *previousChunk;
@property (nonatomic, weak) AHContentTextChunk *nextChunk;

@end

@implementation AHContentTextChunk

-(NSString*) description {
    return [NSString stringWithFormat:@"%@", self.text];
}
@end


@implementation AHContentParser
{
    int numConsectiveReadableElements;
    NSMutableArray *_contentChunks;
    NSString *_htmlString;
}

-(id) init {
    self= [super init];
    if (self) {
        _contentChunks = [NSMutableArray array];
    }
    return self;
}

- (id) initWithString:(NSString*) str {
    self = [self init];
    if (self) {
        _htmlString = str;
        [self parse];
    }
    return self;
}


- (id) initWithData:(NSData*) data {
    self = [self init];
    if (self) {
        if (data) {
            NSInteger encodings[4] = {
                NSUTF8StringEncoding,
                NSASCIIStringEncoding,
                NSMacOSRomanStringEncoding,
                NSUTF16StringEncoding
            };
            
            for( NSInteger i = 0; i < sizeof( encodings ) / sizeof( NSInteger ); i++ )
            {
                if( ( _htmlString = [[NSString alloc] initWithData:data
                                                         encoding:encodings[i]]  ) != nil )
                {
                    break;
                }
            }
            [self parse];
            
            
        }
    }
    return self;
}



-(void) parse {
    
    if  (!_htmlString) {
        return;
    }
    
    NSDate *startTime = [NSDate date];
    
    // We don't parse things into a dom or html because it takes too long, and is really unreliable
    
    // Step 1: First look for paragraphs with lots of text, the quickest way to content on the web
    AHContentTextChunk *currentChunk;
    //get paragraphs
    
    //_htmlString = [AHContentParser stringByStrippingHTML:_htmlString excludeRegEx:kAHContentTagsToKeep];
    //NSUInteger *num = [AHContentParser countString:@"</p>" inText:_htmlString];
    
   NSArray * lines = [_htmlString componentsSeparatedByCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    for (int i =0; i< lines.count; i++) {
        NSRange pRange = [lines[i] rangeOfString:@"p" options:NSCaseInsensitiveSearch];
        if (pRange.location ==0  ) {
            
            // not a paragraph delimiter
            if ([lines[i] length] > 1 && [lines[i] rangeOfString:@"=\""].location == NSNotFound) continue;
            
            NSString *text = lines[i+1];
            text = [AHContentParser stringByStrippingHTML:text excludeRegEx:kAHContentTagsToKeep];
            AHContentTextChunk *contentChunk = [[AHContentTextChunk alloc] init];
            contentChunk.text = text;
            [_contentChunks addObject:contentChunk];
            if (currentChunk) {
                contentChunk.previousChunk = currentChunk;
                currentChunk.nextChunk = contentChunk;
            }
            currentChunk = contentChunk;
            
            self.foundContent = YES;
            
        }
    }
      
    NSLog(@"Time to parse content: %f", [[NSDate date] timeIntervalSinceDate:startTime] );
    
}




-(NSString*) contentHTML {
    
    
    if (_contentChunks.count > 0) {
        
        // Go through and output some very simple html
        NSMutableString *html = [[NSMutableString alloc] init];
        for (AHContentTextChunk* chunk in _contentChunks) {
            if (chunk.text.length == 0) continue;
            if (chunk.isQuote) {
                [html appendFormat:@"<blockquote><p>%@</p></blockquote>", chunk.text];
            } else {
                [html appendFormat:@"<p>%@</p>", chunk.text];
            }
        }
        return html;
    }
    return nil;
}

#pragma mark - Super Awesome NSString methods

-(NSString *) stringByStrippingHTMLFromString:(NSString*) str {
    NSDate *startTime = [NSDate date];
    NSRange r;
    NSString *s = [str copy];
    while ((r = [s rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
        s = [s stringByReplacingCharactersInRange:r withString:@""];
    NSLog(@"Time stringByStrippingHTMLFromString: %f", [[NSDate date] timeIntervalSinceDate:startTime] );
    return s;
}

+ (NSString *)stringByStrippingHTML:(NSString *)inputString excludeRegEx:(NSString*) excludeRegEx;
{
    NSDate *startTime = [NSDate date];
    NSMutableString *outString;
    
    if (inputString)
    {
        
        outString = [[NSMutableString alloc] initWithString:inputString];
        
        if ([inputString length] > 0)
        {
            NSRange r;
            NSRange searchRange = NSMakeRange(0, outString.length);
            while ((r = [outString rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch range:searchRange]).location != NSNotFound)
            {
                NSString *textInQuestion = [outString substringWithRange:r];
                if (!excludeRegEx || [textInQuestion rangeOfString:excludeRegEx options:NSRegularExpressionSearch].location == NSNotFound) {
                    [outString deleteCharactersInRange:r];
                } else {
                    r.location += r.length;
                    
                }
                searchRange =  NSMakeRange(r.location, outString.length - r.location);
            }
            
            while ((r = [outString rangeOfString:@"<!--.*-->" options:NSRegularExpressionSearch]).location != NSNotFound)
            {
                    [outString deleteCharactersInRange:r];
            }

        }
    }
    
    //NSLog(@"Time stringByStrippingHTMLFromString: %f", [[NSDate date] timeIntervalSinceDate:startTime] );
    return outString;
}

+ (int)countString:(NSString *)stringToCount inText:(NSString *)text{
     NSDate *startTime = [NSDate date];
    
    
    int foundCount=0;
    NSRange range = NSMakeRange(0, text.length);
    range = [text rangeOfString:stringToCount options:NSCaseInsensitiveSearch range:range locale:nil];
    while (range.location != NSNotFound) {
        foundCount++;
        range = NSMakeRange(range.location+range.length, text.length-(range.location+range.length));
        range = [text rangeOfString:stringToCount options:NSCaseInsensitiveSearch range:range locale:nil];
    }
    
    NSLog(@"Time countString: %f; found: %d", [[NSDate date] timeIntervalSinceDate:startTime], foundCount );
    return foundCount;
}

@end
