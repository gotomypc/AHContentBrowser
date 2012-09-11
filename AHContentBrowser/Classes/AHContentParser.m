//
//  AHContentParser.m
//  AHContentBrowser
//
//  Created by John Wright on 9/10/12.
//  Copyright (c) 2012 John Wright. All rights reserved.
//

#import "AHContentParser.h"


#define kAHContentStripUnwantedTags @"</?(?i:br|strong|ul|a|img)(.|\n)*?>"

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
    NSRange pRange = [_htmlString rangeOfString:@"<p" options:NSCaseInsensitiveSearch];
    NSRange endOfPRange = NSMakeRange(pRange.location + 2, pRange.length);
    NSRange closingStartTagRange;
    AHContentTextChunk *currentChunk;
    //get paragraphs
    while (pRange.location != NSNotFound) {
        
        endOfPRange = NSMakeRange(pRange.location + 2, pRange.length);;
        BOOL nestedP = YES;
        while (nestedP) {
            NSRange nextPRange =  [_htmlString rangeOfString:@"<p" options:NSCaseInsensitiveSearch range:NSMakeRange(endOfPRange.location, _htmlString.length - endOfPRange.location)];
            endOfPRange = [_htmlString rangeOfString:@"</p>" options:NSCaseInsensitiveSearch range:NSMakeRange(nextPRange.location, _htmlString.length - nextPRange.location)];
            nestedP =  nextPRange.location < endOfPRange.location;
        }
        
        if (endOfPRange.location != NSNotFound) {
            closingStartTagRange = [_htmlString rangeOfString:@">" options:NSCaseInsensitiveSearch range:NSMakeRange(pRange.location + pRange.length, _htmlString.length - endOfPRange.location)];
            
            
            if (closingStartTagRange.location != NSNotFound) {
                AHContentTextChunk *contentChunk = [[AHContentTextChunk alloc] init];
                NSRange textRange = NSMakeRange(closingStartTagRange.location+1, endOfPRange.location - closingStartTagRange.location -1);
                NSString *text =[_htmlString substringWithRange:textRange];
                
                // todo: score text
                
                text = [AHContentParser stringByStrippingHTML:text excludeRegEx:kAHContentStripUnwantedTags];
                contentChunk.text = text;
                contentChunk.textRange = textRange;
                [_contentChunks addObject:contentChunk];
                if (currentChunk) {
                    contentChunk.previousChunk = currentChunk;
                    currentChunk.nextChunk = contentChunk;
                }
                currentChunk = contentChunk;
                
                self.foundContent = YES;
                pRange = [_htmlString rangeOfString:@"<p" options:NSCaseInsensitiveSearch range:NSMakeRange(endOfPRange.location, _htmlString.length -endOfPRange.location-1)];
            }
        }
    }
    
    
    
    // Look at the text in between our content to tell what we should exclude
    NSUInteger maxDistance = 0;
    for (AHContentTextChunk *chunk in _contentChunks) {
        if (chunk.nextChunk) {
            NSString *text = chunk.text;
            NSString *nextText = chunk.nextChunk.text;
            NSUInteger distanceBetweenChunks = chunk.nextChunk.textRange.location  - chunk.textRange.location + chunk.textRange.length;
            maxDistance = MAX(maxDistance, distanceBetweenChunks);
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
        }
    }
    
    NSLog(@"Time stringByStrippingHTMLFromString: %f", [[NSDate date] timeIntervalSinceDate:startTime] );
    return outString;
}


@end
