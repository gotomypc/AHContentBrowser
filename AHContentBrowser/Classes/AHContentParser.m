//
//  AHContentParser.m
//  AHContentBrowser
//
//  Created by John Wright on 9/10/12.
//  Copyright (c) 2012 John Wright. All rights reserved.
//

#import "AHContentParser.h"
#import "TBXML.h"


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
    TBXML *tbxml;
    int numConsectiveReadableElements;
    NSMutableArray *_readableElements;
    CGFloat divCount;
    CGFloat paragraphCount;
}

-(id) init {
    self= [super init];
    if (self) {
        divCount = 0;
        paragraphCount = 0;
        _readableElements = [NSMutableArray array];
    }
    return self;
}

- (id) initWithString:(NSString*) str {
    self = [self init];
    if (self) {
        NSError *error;
        tbxml = [TBXML newTBXMLWithXMLString:str error:&error];
        [self extractContent:tbxml.rootXMLElement];
    }
    return self;
}


- (id) initWithData:(NSData*) data {
    self = [self init];
    if (self) {
        NSError *error;
        if (data) {
            tbxml = [TBXML newTBXMLWithXMLData:data error:&error];
            [self extractContent:tbxml.rootXMLElement];
        }
    }
    return self;
}

-(NSString*) cleanBeforeParsing:(NSString*)str {
    NSString *doubleBRsRe = @"(?:<br //>){2,}";
	NSError *error = NULL;
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:doubleBRsRe
                                                                           options:NSRegularExpressionCaseInsensitive
	                                                                         error:&error];
	NSString *modifiedString = [regex stringByReplacingMatchesInString:str options:0 range:NSMakeRange(0, [str length]) withTemplate:@"\n"];
    return modifiedString;
}



-(void) extractContent:(TBXMLElement*) element {
    
    do {
        NSString *elementName = [TBXML elementName:element] ;
        if ([elementName rangeOfString:@"br"].location != NSNotFound) {
            NSLog(@"");
        }
        
        AHContentInfo *contentElement = nil;
        if ([elementName isEqualToString:@"p"]) {
            NSString *text = [TBXML textForElement:element];
            if (text.length > 30) {
                self.foundContent = YES;
                contentElement = [[AHContentInfo alloc] init];
                contentElement.text = [TBXML textForElement:element];
                contentElement.elementName = elementName;
                paragraphCount++;
            }
            
        }
        
        // divs
        if (element->firstChild && [elementName isEqualToString:@"div"] && [[TBXML elementName:element->firstChild] isEqualToString:@"br"]) {
            self.foundContent = YES;
            contentElement = [[AHContentInfo alloc] init];
            contentElement.text = [TBXML textForElement:element];
            contentElement.elementName = elementName;
            divCount++;
            //We are only interested in divs with lots of text, relatively few links, and little nesting
        }
        
        
        // Is this a quote
        if (contentElement && element->parentElement && [[TBXML elementName:element->parentElement] isEqualToString:@"blockquote"]) {
            contentElement.isQuote = YES;
        }
        
        
        if (contentElement) [_readableElements addObject:contentElement];
        
        
        
        // if the element has child elements, process them
        if (element->firstChild) {
            [self extractContent:element->firstChild];
        }
        
        // Obtain next sibling element
    } while ((element = element->nextSibling));
    
    
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
