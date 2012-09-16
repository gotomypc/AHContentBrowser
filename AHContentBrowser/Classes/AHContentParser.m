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


@interface AHContentElement : NSObject

@property (nonatomic) NSString* name;
@property (nonatomic, weak) AHContentElement *parent;
@property (nonatomic) NSMutableDictionary *attributes;
@property (nonatomic) NSMutableArray *children;
@property (nonatomic) NSInteger tagScore;
@property (nonatomic) NSInteger attributeScore;
@property (nonatomic) NSInteger totalScore;
@property (nonatomic) NSMutableString *elementData;

// Info properties
@property (nonatomic) NSInteger *textLength;
@property (nonatomic) NSInteger *linkLength;
@property (nonatomic) NSInteger *commas;
@property (nonatomic) NSInteger *density;
@property (nonatomic) NSMutableDictionary *tagCount;

@property (nonatomic) BOOL isCandidate;

@property (nonatomic, readonly) NSString *outerHTML;
@property (nonatomic, readonly) NSString *innerHTML;

@end

@implementation AHContentElement

-(id) initWithTagName:(NSString*) tagName parent:(AHContentElement*) parent {
    self = [super init];
    if (self) {
        self.name = tagName;
        self.parent = parent;
        self.children = [NSMutableArray array];
        self.attributes = [NSMutableDictionary dictionary];
        self.tagScore = 0;
        self.attributeScore = 0;
        self.elementData = [[NSMutableString alloc] init];
        self.textLength = 0;
        self.linkLength = 0;
        self.commas = 0;
        self.density = 0;
        self.tagCount = 0;
        self.isCandidate = NO;
    }
    return self;
}

-(NSString*) innerHTML {
    NSMutableString *ret = [[NSMutableString alloc] init];
    for (NSUInteger i=0,j= self.children.count; i< j; i++) {
        id child = self.children[i];
        if ([child isKindOfClass:[NSString class]]) {
            [ret appendString:child];
        } else {
            [ret appendString:[child outerHTML]];
        }
    }
    return ret;
}


-(NSString*) outerHTML {
    NSMutableString *ret = [[NSMutableString alloc] initWithFormat:@"<%@", self.name];
    for (NSString *attribute in self.attributes.allKeys) {
        [ret appendFormat:@" %@=\"%@\"", attribute, [self.attributes objectForKey:attribute]];
    }
    
    if  (self.children.count == 0) {
        if  ([@[@"br", @"hr"] containsObject:self.name]) {
            return [ret stringByAppendingString:@"/>"];
        } else {
            return [ret stringByAppendingFormat:@"></%@>", self.name];
        }
    }
    
    return [ret stringByAppendingFormat:@">%@</%@>", self.innerHTML, self.name];
    
    
}


-(NSString*) description {
    return [NSString stringWithFormat:@"%@", self.name];
}
@end


@implementation AHContentParser {
    AHContentParserHandler _handler;
    NSString *_htmlString;
    AHSAXParser *_saxParser;
    
    NSMutableArray *_paragraphs;
    
    AHContentElement* _currentElement;
    AHContentElement* _topCandidate;
    NSString *_origTitle;
    NSString *_headerTitle;
    NSMutableDictionary *_scannedLinks;
    
    
    NSArray *_tagsToSkip;
    NSDictionary *_tagCounts;
    NSArray *_removeIfEmpty;
    NSArray *_embeds;
    NSArray *_goodAttributes;
    NSArray *_cleanConditionally;
    NSArray  *_unpackDivs;
    NSArray *_noContent;
    NSArray *_formatTags;
    NSArray *_headerTags;
    NSArray *_newLinesAfter;
    
    NSArray *_divToPElements;
    NSArray *_okIfEmpty;
    
    NSRegularExpression *_reVideos;
    NSRegularExpression *_reNextLink;
    NSRegularExpression *_rePrevLink;
    NSRegularExpression *_reExtraneous;
    NSRegularExpression *_rePages;
    NSRegularExpression *_rePageNum;
    
    NSRegularExpression *_reSafe;
    NSRegularExpression *_reFinal;
    
    NSRegularExpression *_rePositive;
    NSRegularExpression *_reNegative;
    NSRegularExpression *_reUnlikelyCandidates;
    NSRegularExpression *_reOKMaybeItsACandidate;
    
    NSRegularExpression *_reSentence;
    NSRegularExpression *_reWhitespace;
    
    NSRegularExpression *_rePageInURL;
    NSRegularExpression *_reBadFirst;
    NSRegularExpression *_reNoLetters;
    NSRegularExpression *_reParams;
    NSRegularExpression *_reExtension;
    NSRegularExpression *_reDigits;
    NSRegularExpression *_reJustDigits;
    NSRegularExpression *_reSlashes;
    NSRegularExpression *_reDomain;
    
    
    NSRegularExpression *_reProtocol;
    NSRegularExpression *_reCleanPaths;
    
    NSRegularExpression *_reClosing;
    NSRegularExpression *_reImgUrl;
    
    NSRegularExpression *_reCommas;
    
}

-(id) init {
    self= [super init];
    if (self) {
        _formatTags = @[@"br", @"hr"];
    }
    return self;
}


- (id) initWithData:(NSData*) data handler:(AHContentParserHandler)handler {
    self = [self init];
    if (self) {
        _handler = [handler copy];
        _paragraphs = [NSMutableArray array];
        
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
    NSMutableString *html = [[NSMutableString alloc] init];
    for (AHContentElement *elem in _paragraphs) {
        [html appendString:elem.outerHTML];
    }
    return html;
}



#pragma mark - SAX Delegate method


-(void) onOpenTagName:(NSString*)tag{
    if (!([@[@"p", @"a", @"blockquote", @"img"] containsObject:tag])) {
        return;
    }

    _currentElement = [[AHContentElement alloc] initWithTagName:tag parent:_currentElement];
}


-(void) onAttributeName:(NSString*)name value:(NSString*) value{
    [_currentElement.attributes setValue:value forKey:name];
}

-(void) onText:(NSString*) text{
    if (_currentElement) {
        [_currentElement.children addObject:text];
    }
}

-(void) onCloseTag:(NSString*)tag{
    AHContentElement *elem = _currentElement;
    if (elem.parent) {
        _currentElement = elem.parent;
    }
    [elem.parent.children addObject:elem];
    if ([tag isEqualToString:@"p"]) {
        [_paragraphs addObject:elem];
    }
}

-(void) onError{
    
}

-(void) onEnd{
    self.foundContent = YES;
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
