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

@interface AHContentParser()

+(NSString*) trim:(NSString*) str;

@end


@interface AHContentElement : NSObject

@property (nonatomic) NSString* name;
@property (nonatomic) AHContentElement *parent;
@property (nonatomic) NSMutableDictionary *attributes;
@property (nonatomic) NSMutableArray *children;
@property (nonatomic) NSMutableString *elementData;

// Scoring properties
@property (nonatomic) NSInteger textLength;
@property (nonatomic) NSInteger linkLength;
@property (nonatomic) NSInteger numOfCommas;
@property (nonatomic) NSInteger numOfSentences;
@property (nonatomic) CGFloat linkDensity;
@property (nonatomic) NSMutableDictionary *tagCount;
@property (nonatomic) NSInteger tagScore;
@property (nonatomic) NSInteger attributeScore;
@property (nonatomic) NSInteger totalScore;
@property (nonatomic) BOOL isCandidate;

// Converting to html
@property (nonatomic, readonly) NSString *outerHTML;
@property (nonatomic, readonly) NSString *innerHTML;

-(void) score;

@end

@implementation AHContentElement {
    NSRegularExpression *_reCommas;
    NSDictionary *_tagCounts;
    NSRegularExpression *_reSentence;
    
}

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
        self.numOfCommas = 0;
        self.numOfSentences = 0;
        self.linkDensity = 0;
        self.totalScore = 0;
        self.tagCount = [NSMutableDictionary dictionary];
        self.isCandidate = NO;
        
        _tagCounts = @{@"address": [NSNumber numberWithInteger:-3], @"article": [NSNumber numberWithInteger:30], @"blockquote": [NSNumber numberWithInteger:3], @"body": [NSNumber numberWithInteger:-5], @"dd": [NSNumber numberWithInteger:-3], @"div": [NSNumber numberWithInteger:5],  @"br": [NSNumber numberWithInteger:10], @"dl": [NSNumber numberWithInteger:-3], @"dt": [NSNumber numberWithInteger:-3], @"form": [NSNumber numberWithInteger:-3], @"h2": [NSNumber numberWithInteger:-5], @"h3": [NSNumber numberWithInteger:-5], @"h4": [NSNumber numberWithInteger:-5],@"h5": [NSNumber numberWithInteger:-5], @"h6": [NSNumber numberWithInteger:-5],@"li": [NSNumber numberWithInteger:-3], @"ol": [NSNumber numberWithInteger:-3], @"pre": [NSNumber numberWithInteger:3], @"section": [NSNumber numberWithInteger:15],@"td": [NSNumber numberWithInteger:3], @"th": [NSNumber numberWithInteger:-5],@"ul": [NSNumber numberWithInteger:-3]};
        
        _reCommas = [NSRegularExpression regularExpressionWithPattern:@",[\\s\\,]*" options:0 error:0];
        _reSentence = [NSRegularExpression regularExpressionWithPattern:@"\\. |\\.$" options:0 error:0];
    }
    return self;
}

//// add points for the tag names
//if ([_tagCounts.allKeys containsObject:elem.name]) {
//    elem.tagScore += [[_tagCounts valueForKey:elem.name] integerValue];
//}
//
//score = floor((elem.tagScore + elem.attributeScore) * (1-elem.density));


-(void) score {
    if ([self.attributes.allValues containsObject:@"articleBody"]) {
        NSLog(@"");
    }

    // aggregrate totals, from children
    for (NSUInteger i=0; i < self.children.count; i++) {
        AHContentElement *elem = self.children[i];
        if ([elem isKindOfClass:[NSString class]]) {
            NSString *elemString = (NSString*) elem;
            self.textLength += [AHContentParser trim:elemString].length;
            
            self.numOfCommas += [_reCommas numberOfMatchesInString:elemString options:0 range:NSMakeRange(0, elemString.length)];
            
            self.numOfSentences += [_reSentence numberOfMatchesInString:elemString options:0 range:NSMakeRange(0, elemString.length)];
        } else {
            if ([self.attributes.allValues containsObject:@"articleBody"]) {
                NSLog(@"");
            }
            
            if ([elem.name isEqualToString:@"a"]) {
                self.linkLength += elem.textLength + elem.linkLength;
            } else {
                self.textLength += elem.textLength;
                self.linkLength += elem.linkLength;
            }
            self.numOfCommas += elem.numOfCommas;
            self.numOfSentences += elem.numOfSentences;
            
            // aggregrate tag counts
            for (NSString *key in elem.tagCount.allKeys) {
                if ([elem.tagCount.allKeys containsObject:key]) {
                    NSInteger currentTagCount = [[self.tagCount valueForKey:key] integerValue];
                    NSInteger elemTagCount = [[elem.tagCount objectForKey: key] intValue];
                    [self.tagCount setObject: [NSNumber numberWithInteger:(currentTagCount + elemTagCount)] forKey: key];
                } else {
                    [self.tagCount setValue:[elem.tagCount valueForKey:key] forKey:key];
                }
            }
            if ([self.tagCount.allKeys containsObject:elem.name]) {
                [self.tagCount setObject: [NSNumber numberWithInt: [[self.tagCount objectForKey: elem.name] intValue] + 1] forKey: elem.name];
            } else {
                [self.tagCount setValue:[NSNumber numberWithInteger:1] forKey:elem.name];
            }
        }
    }
    
    // Score...
    
    // Score up longer text
    if (self.textLength > 1000) {
        self.totalScore += 10;
    }
    if (self.textLength > 200) {
        self.totalScore += 5;
    }
    
    // Score up text by number of commas
    self.totalScore += self.numOfCommas;

    // Score up sentences
    self.totalScore += self.numOfSentences;

    // score up for low linkDensitys
    if (self.linkLength != 0) {
        self.linkDensity = (float) self.linkLength / (float)(self.textLength + self.linkLength);
        if (self.linkDensity < 0.2) {
            self.totalScore+= 5;
        }
        if (self.linkDensity < 0.1) {
            self.totalScore += 5;
        }
    }
    
    // Todo: Score tags
    
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
    return [self.children componentsJoinedByString:@""];
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
    
    NSArray *_contentTags;
    
    NSArray *_tagsToSkip;
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
    
    BOOL _skipping;
    
}

-(id) init {
    self= [super init];
    if (self) {
        _formatTags = @[@"br", @"hr"];
        _contentTags = @[@"p", @"a", @"blockquote", @"img", @"pre"];
        
        _tagsToSkip = @[ @"iframe", @"aside", @"footer", @"head", @"label", @"nav", @"noscript", @"script", @"select", @"style", @"textarea" @"input", @"font", @"input", @"link", @"meta" ];
        
        
        _removeIfEmpty = @[@"blockquote", @"li", @"p", @"pre", @"tbody", @"td", @"th", @"thead", @"tr"  ];
        _embeds = @[@"embed", @"object", @"iframe"];
        _goodAttributes = @[@"alt", @"href", @"src", @"title"];
        _cleanConditionally = @[@"div", @"form", @"ol", @"table", @"ul"];
        _unpackDivs = [_embeds arrayByAddingObjectsFromArray:@[@"div", @"img"]];
        _noContent = [_formatTags arrayByAddingObjectsFromArray:@[@"font", @"input", @"link", @"meta", @"span"]];
        _formatTags = @[@"br", @"hr"];
        _headerTags = @[@"h1", @"h2", @"h3", @"h4", @"h5", @"h6"];
        _newLinesAfter = [_headerTags arrayByAddingObjectsFromArray:@[@"br", @"li", @"p"]];
        
        _divToPElements = @[@"a", @"blockquote", @"dl", @"img", @"ol", @"p", @"pre", @"table", @"ul"];
        _okIfEmpty = @[@"audio", @"embed", @"iframe", @"img",@"object", @"video"];
        
        _reVideos = [NSRegularExpression regularExpressionWithPattern:@"http:\\/\\/(?:www\\.)?(?:youtube|vimeo)\\.com" options:0 error:0];
        _reNextLink = [NSRegularExpression regularExpressionWithPattern:@"[>»]|continue|next|weiter(?:[^\\|]|$)" options:0 error:0];
        _rePrevLink = [NSRegularExpression regularExpressionWithPattern:@"[<«]|earl|new|old|prev" options:0 error:0];
        _reExtraneous = [NSRegularExpression regularExpressionWithPattern:@"all|archive|comment|discuss|e-?mail|login|print|reply|share|sign|single" options:0 error:0];
        _rePages = [NSRegularExpression regularExpressionWithPattern:@"pag(?:e|ing|inat)" options:0 error:0];
        _rePageNum = [NSRegularExpression regularExpressionWithPattern:@"p[ag]{0,2}(?:e|ing|ination)?[=\\/]\\d{1,2}" options:0 error:0];
        
        _reSafe = [NSRegularExpression regularExpressionWithPattern:@"article-body|hentry|instapaper_body" options:0 error:0];
        _reFinal = [NSRegularExpression regularExpressionWithPattern:@"first|last" options:0 error:0];
        
        _rePositive = [NSRegularExpression regularExpressionWithPattern:@"article|blog|body|content|entry|main|news|pag(?:e|ination)|post|story|text" options:0 error:0];
        _reNegative = [NSRegularExpression regularExpressionWithPattern:@"com(?:bx|ment|-)|contact|foot(?:er|note)?|masthead|media|meta|outbrain|promo|related|scroll|shoutbox|sidebar|sponsor|shopping|tags|tool|widget" options:0 error:0];
        _reUnlikelyCandidates = [NSRegularExpression regularExpressionWithPattern:@"ad-break|aggregrate|auth?or|bookmark|cat|com(?:bx|ment|munity)|date|disqus|extra|foot|header|ignore|links|menu|nav|pag(?:er|ination)|popup|related|remark|rss|share|shoutbox|sidebar|similar|social|sponsor|teaserlist|time|tweet|twitter" options:0 error:0];
        _reOKMaybeItsACandidate = [NSRegularExpression regularExpressionWithPattern:@"and|article|body|column|main|shadow" options:0 error:0];
        
        
        _reWhitespace = [NSRegularExpression regularExpressionWithPattern:@"\\s+" options:0 error:0];
        
        _rePageInURL = [NSRegularExpression regularExpressionWithPattern:@"[_\\-]?p[a-zA-Z]*[_\\-]?\\d{1,2}$" options:0 error:0];
        _reBadFirst = [NSRegularExpression regularExpressionWithPattern:@"^(?:[^a-z]{0,3}|index|\\d+)$" options:0 error:0];
        _reNoLetters = [NSRegularExpression regularExpressionWithPattern:@"[^a-zA-Z]" options:0 error:0];
        _reParams = [NSRegularExpression regularExpressionWithPattern:@"\\?.*" options:0 error:0];
        _reExtension = [NSRegularExpression regularExpressionWithPattern:@"00,|\\.[a-zA-Z]+$" options:0 error:0];
        _reDigits = [NSRegularExpression regularExpressionWithPattern:@"\\d" options:0 error:0];
        _reJustDigits = [NSRegularExpression regularExpressionWithPattern:@"^\\d{1,2}$" options:0 error:0];
        _reSlashes = [NSRegularExpression regularExpressionWithPattern:@"\\/+" options:0 error:0];
        _reDomain = [NSRegularExpression regularExpressionWithPattern:@"\\/([^\\/]+)" options:0 error:0];
        
        _reProtocol = [NSRegularExpression regularExpressionWithPattern:@"^\\w+\\:" options:0 error:0];
        _reCleanPaths = [NSRegularExpression regularExpressionWithPattern:@"\\/\\.(?!\\.)|\\/[^\\/]*\\/\\.\\." options:0 error:0];
        
        _reClosing = [NSRegularExpression regularExpressionWithPattern:@"\\/?(?:#.*)?$" options:0 error:0];
        _reImgUrl = [NSRegularExpression regularExpressionWithPattern:@"\\.(gif|jpe?g|png|webp)$" options:0 error:0];
        
        
        
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
    return [AHContentParser trim:_topCandidate.innerHTML];
    //    //remove spaces in front of <br>s
    //    .replace(/(?:\s|&nbsp;?)+(?=<br\/>)/g, "")
    //    //remove <br>s in front of opening & closing <p>s
    //    .replace(/(?:<br\/>)+(?:\s|&nbsp;?)*(?=<\/?p)/g, "")
    //    //turn all double+ <br>s into <p>s
    //    .replace(/(?:<br\/>){2,}/g, "</p><p>")
    //    //trim the result
    //    .trim();
}



#pragma mark - SAX Delegate method


-(void) onOpenTagName:(NSString*)name{
    
    // Ignore a lot of tags
    if ([_tagsToSkip containsObject:name]) {
        if (_currentElement) {
            _currentElement.totalScore -= 10;
        }
        _skipping = YES;
        return;
    }
    
    _skipping = NO;
    
    if ([_formatTags containsObject:name] && _currentElement) {
        [_currentElement.children addObject:[[AHContentElement alloc] initWithTagName:name parent:_currentElement]];
    } else {
        _currentElement = [[AHContentElement alloc] initWithTagName:name parent:_currentElement];
    }
}


-(void) onAttributeName:(NSString*)name value:(NSString*) value{
    
    if (!value || _skipping) {
        return;
    }
    
    name = [name lowercaseString];
    AHContentElement *elem = _currentElement;
    
    [elem.attributes setValue:value forKey:name];
    
    //    if ([name isEqualToString:@"href"] || [name isEqualToString:@"src"]) {
    //         //fix links
    //        if ([_reProtocol firstMatchInString:value options:NSCaseInsensitiveSearch range:NSMakeRange(0, value.length)]) {
    //            [elem.attributes setValue:value forKey:name];
    //        } else {
    //            elem.attributes setValue:<#(id)#> forKey:<#(NSString *)#>
    //        }
    //    }
    
}

-(void) onText:(NSString*) text{
    
    if (_currentElement && !_skipping) {
        [_currentElement.children addObject:text];
    }
    
    
}

-(void) onCloseTag:(NSString*)tagName{
    
    if ([_noContent containsObject:tagName]) {
        return;
    }
    if ([_tagsToSkip containsObject:tagName]) {
        return;
    }
    
    AHContentElement *elem = _currentElement;
    if (elem.parent) {
        _currentElement = elem.parent;
    }
    
    [elem score];
    [elem.parent.children addObject:elem];
    if ([elem.attributes.allValues containsObject:@"articleBody"]) {
        NSLog(@"");
    }

    if ([elem.name isEqualToString:@"div"] && elem.totalScore > 25 && elem.totalScore > _topCandidate.totalScore) {
        _topCandidate = elem;
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


+(NSString*)trim:(NSString*) str {
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
