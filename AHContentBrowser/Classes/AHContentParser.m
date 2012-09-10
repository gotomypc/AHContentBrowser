//
//  AHContentParser.m
//  AHContentBrowser
//
//  Created by John Wright on 9/10/12.
//  Copyright (c) 2012 John Wright. All rights reserved.
//

#import "AHContentParser.h"


@interface AHContentInfo : NSObject

@property (nonatomic) NSString *text;
@property (nonatomic) NSString *elementName;
@property (nonatomic) BOOL isQuote;

@end

@implementation AHContentInfo

-(NSString*) description {
    return [NSString stringWithFormat:@"%@", self.elementName];
}
@end


@implementation AHContentParser
{
    int numConsectiveReadableElements;
    NSMutableArray *_readableElements;
    CGFloat divCount;
    CGFloat paragraphCount;
    NSString *htmlString;
    NSRegularExpression *paragraphsRe;
}

-(id) init {
    self= [super init];
    if (self) {
        divCount = 0;
        paragraphCount = 0;
        _readableElements = [NSMutableArray array];
        NSError *error;
        paragraphsRe = [[NSRegularExpression alloc] initWithPattern:@"<p>" options:NSRegularExpressionCaseInsensitive error:&error];
    }
    return self;
}

- (id) initWithString:(NSString*) str {
    self = [self init];
    if (self) {
        htmlString = str;
        [self parse];
    }
    return self;
}


- (id) initWithData:(NSData*) data {
    self = [self init];
    if (self) {
        NSError *error;
        if (data) {
            NSInteger encodings[4] = {
                NSUTF8StringEncoding,
                NSASCIIStringEncoding,
                NSMacOSRomanStringEncoding,
                NSUTF16StringEncoding
            };
            
            for( NSInteger i = 0; i < sizeof( encodings ) / sizeof( NSInteger ); i++ )
            {
                if( ( htmlString = [[NSString alloc] initWithData:data
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
    
    if  (!htmlString) {
        return;
    }
    
    NSDate *startTime = [NSDate date];
    
    // We don't parse things into a dom or html because it takes too long, and is really unreliable
    
    // Step 1: First look for paragraphs with lots of text, the quickest way to content on the web
    NSRange pRange = [htmlString rangeOfString:@"<p" options:NSCaseInsensitiveSearch];
    //get paragraphs
    while (pRange.location != NSNotFound) {
        NSRange endOfPRange = [htmlString rangeOfString:@"</p>" options:NSCaseInsensitiveSearch range:NSMakeRange(pRange.location, htmlString.length - pRange.location)];
        if (endOfPRange.location != NSNotFound) {
            AHContentInfo *contentInfo = [[AHContentInfo alloc] init];
            NSRange closingStartTagRange = [htmlString rangeOfString:@">" options:NSCaseInsensitiveSearch range:NSMakeRange(pRange.location+2, htmlString.length - pRange.location +2su)];
            NSString *text =[htmlString substringWithRange:NSMakeRange(closingStartTagRange.location+1, endOfPRange.location)];
            
            // test the text out

            // sufficient length
            if (text.length < 100) break;
            
            
            contentInfo.text = text;
            [_readableElements addObject:contentInfo];
            self.foundContent = YES;
            pRange = [htmlString rangeOfString:@"<p" options:NSCaseInsensitiveSearch range:NSMakeRange(endOfPRange.location, htmlString.length -endOfPRange.location)];
        }
    }
    
    
    // If 5 or more paragraphs with good content were found, we are pretty good
    
    NSLog(@"Time to parse content: %f", [[NSDate date] timeIntervalSinceDate:startTime] );
    
}



-(NSString*) removeTagsNamed:(NSString*) tagName fromString:(NSString*) str {
    NSScanner *theScanner;
    NSString *gt =nil;
    NSString *ret = str;
    
    theScanner = [NSScanner scannerWithString:str];
    [theScanner setCaseSensitive:NO];
    
    while ([theScanner isAtEnd] == NO) {
        
        
        // find start of tag
        [theScanner scanUpToString:[NSString stringWithFormat:@"<%@", tagName] intoString:NULL] ;
        
        // find end of tag
        [theScanner scanUpToString:[NSString stringWithFormat:@"</%@>", tagName] intoString:&gt] ;
        
        // replace the found tag with a space
        //(you can filter multi-spaces out later if you wish)
        
        ret = [ret stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@</script>", gt] withString:@""];
        
    }
    return ret;
}

-(NSString*) contentHTML {
    
    
    if (_readableElements.count > 0) {
        
        // Remove any divs with text less than 100 if the majority are paragraphs
        // Harsh I know but it works heuristically
        if (paragraphCount > divCount) {
            [_readableElements filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(AHContentInfo *evaluatedObject, NSDictionary *bindings) {
                return [evaluatedObject.elementName isEqualToString:@"p"] || ([evaluatedObject.elementName isEqualToString:@"p"] && evaluatedObject.text.length > 100);
            }]];
        }
        
        // Go through and output some very simple html
        NSMutableString *html = [[NSMutableString alloc] init];
        for (AHContentInfo* elem in _readableElements) {
            if (elem.isQuote) {
                [html appendFormat:@"<blockquote><p>%@</p></blockquote>", elem.text];
            } else {
                [html appendFormat:@"<p>%@</p>", elem.text];
            }
        }
        return html;
    }
    return nil;
}



@end
