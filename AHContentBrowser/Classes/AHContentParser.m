    //
//  AHContentParser.m
//  AHContentBrowser
//
//  Created by John Wright on 9/10/12.
//  Copyright (c) 2012 John Wright. All rights reserved.
//

#import "AHContentParser.h"


#define kAHContentTagsNames @"(?i:p|pre|h2|blockquote)"
#define kAHContentTagsToKeep @"</?(?i:br|strong|ul|a|img|p)(.|\n)*?>"
#define kAHContentTagsToRemove @"script"

@interface AHContentTextChunk : NSObject

@property (nonatomic) NSString *text;
@property (nonatomic) NSString *elementName;
@property (nonatomic) BOOL isQuote;
@property (nonatomic) NSInteger index;
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
    NSRegularExpression *_contentTagsRe;
    NSRegularExpression *_unwantedRe;
    AHSAXParser *_saxParser;
    NSInteger _numPs;
    AHContentTextChunk *_currentChunk;
    AHContentParserHandler _handler;
    NSMutableString *_html;
}

-(id) init {
    self= [super init];
    if (self) {
        NSError *error;
        _unwantedRe = [NSRegularExpression regularExpressionWithPattern:kAHContentTagsToRemove options:NSRegularExpressionCaseInsensitive error:&error];
        _contentChunks = [NSMutableArray array];
    }
    return self;
}

- (id) initWithString:(NSString*) str {
    self = [self init];
    if (self) {
        _htmlString = str;
        _contentTagsRe = [NSRegularExpression regularExpressionWithPattern:kAHContentTagsNames options:NSCaseInsensitiveSearch error:0];
    }
    return self;
}


- (id) initWithData:(NSData*) data handler:(AHContentParserHandler)handler {
    self = [self init];
    if (self) {
        _handler = [handler copy];
        _html = [[NSMutableString alloc] init];
        if (data) {
            NSDate *startTime = [NSDate date];
            
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
            
            _saxParser = [[AHSAXParser alloc] initWithDelegate:self];
            [_saxParser end:_htmlString];
            
            NSLog(@"Time to parse content: %f", [[NSDate date] timeIntervalSinceDate:startTime] );
            
        }
    }
    return self;
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


#pragma mark - SAX Delegate method


-(void) onOpenTagName:(NSString*)tag{
    if ([tag isEqualToString:@"p"]) {
        _currentChunk = [[AHContentTextChunk alloc] init];
        _currentChunk.elementName = tag;
        _numPs++;
    }
    [_html appendFormat:@"<%@", tag];
}


-(void) onOpenTagEnd {
    [_html appendString:@">"];
    
}

-(void) onAttributeName:(NSString*)name value:(NSString*) value{
    [_html appendFormat:@" %@=\"%@\"", name, value];

}
-(void) onText:(NSString*) text{
    if (_currentChunk) {
        _currentChunk.text = text;
    }
    [_html appendString:text];
}

-(void) onCloseTag:(NSString*)tag{
    if ([tag isEqualToString:@"p"] && _currentChunk) {
        [_contentChunks addObject:_currentChunk];
        _currentChunk = nil;
    }
    [_html appendFormat:@"</%@>", tag];

}

-(void) onError{
    
}
-(void) onEnd{
    self.foundContent = YES;
    NSLog(@"Found %ld, paragraphs", _numPs);
    NSLog(@"%@", _html);
    if (_handler) {
        _handler(self);
    }
}



#pragma mark - Super Awesome NSString methods



-(NSString*)trim:(NSString*) str {
    return [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}



+ (NSString *)stringByStrippingHTML:(NSString *)inputString includeRegEx:(NSString*)includeRegEx excludeRegEx:(NSString*) excludeRegEx;
{
    //NSDate *startTime = [NSDate date];
    NSMutableString *outString;
    
    if (inputString)
    {
        
        outString = [[NSMutableString alloc] initWithString:inputString];
        //remove all by default;
        includeRegEx = includeRegEx ? includeRegEx : @"<[^>]+>";
        
        if ([inputString length] > 0)
        {
            NSRange r;
            NSRange searchRange = NSMakeRange(0, outString.length);
            while ((r = [outString rangeOfString:includeRegEx options:NSRegularExpressionSearch range:searchRange]).location != NSNotFound)
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
