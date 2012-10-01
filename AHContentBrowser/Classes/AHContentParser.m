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
@property (nonatomic) NSInteger numOfParagraphs;
@property (nonatomic) NSInteger numOfSentences;
@property (nonatomic) NSInteger numOfLargeImages;
@property (nonatomic) CGFloat linkDensity;
@property (nonatomic) NSMutableDictionary *tagCount;
@property (nonatomic) NSInteger tagScore;
@property (nonatomic) NSInteger attributeScore;
@property (nonatomic) NSInteger totalScore;
@property (nonatomic) BOOL hasChildContainingText;
@property (nonatomic) BOOL isCandidate;
@property (nonatomic) BOOL hasLowercaseChild;

// Converting to html
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
        self.numOfCommas = 0;
        self.numOfSentences = 0;
        self.linkDensity = 0;
        self.totalScore = 0;
        self.tagCount = [NSMutableDictionary dictionary];
        self.isCandidate = NO;
    }
    return self;
}

//// add points for the tag names
//if ([_tagCounts.allKeys containsObject:elem.name]) {
//    elem.tagScore += [[_tagCounts valueForKey:elem.name] integerValue];
//}
//
//score = floor((elem.tagScore + elem.attributeScore) * (1-elem.density));



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
    NSDate *_startTime;
    AHContentParserHandler _handler;
    AHSAXParser *_saxParser;
    
    AHContentElement* _currentElement;
    AHContentElement* _topCandidate;
    NSString *_origTitle;
    NSString *_headerTitle;
    NSMutableDictionary *_scannedLinks;
    
    NSMutableArray *_contentTags;
    NSArray *_candidateTags;
    NSMutableArray *_largeImages;
 
    
    NSArray *_tagsToSkip;
    NSDictionary *_tagCounts;
    
    // This hold elements with the name "article".
    // Most urls  contain zero or one articles 
    // but some split an article up separated by ads and pics.
    NSMutableArray *_articleElementArray;
    
    NSArray *_removeIfEmpty;
    NSArray *_embeds;
    NSArray *_goodAttributes;
    NSArray *_cleanConditionally;
    NSArray  *_unpackDivs;
    NSArray *_formatTags;
    NSArray *_headerTags;
    NSArray *_newLinesAfter;
    
    NSArray *_divToPElements;
    NSArray *_okIfEmpty;
    
    NSRegularExpression *_reCommas;
    NSRegularExpression *_reAtLeastOneLowercase;
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
        _headerTags = @[@"h1", @"h2", @"h3", @"h4", @"h5", @"h6"];
        
        _contentTags = [[_formatTags arrayByAddingObjectsFromArray:@[@"html", @"article", @"section", @"body", @"div", @"p", @"li", @"ol", @"ul", @"span", @"a", @"blockquote", @"img", @"iframe", @"pre", @"a", @"td", @"em", @"i", @"strong"]] mutableCopy];
        [_contentTags addObjectsFromArray:_headerTags];
        
        _candidateTags = [NSArray arrayWithObjects:@"div", @"p", @"ul", @"span", @"article", @"section", nil];
        
        _tagsToSkip = @[ @"iframe", @"aside", @"footer", @"head", @"label", @"nav", @"noscript", @"script", @"select", @"style", @"textarea" @"input", @"font", @"input", @"link", @"meta" ];
        
        
        _tagCounts = @{@"address": [NSNumber numberWithInteger:-3], @"p": [NSNumber numberWithInteger:15], @"article": [NSNumber numberWithInteger:30], @"blockquote": [NSNumber numberWithInteger:3], @"body": [NSNumber numberWithInteger:-5], @"dd": [NSNumber numberWithInteger:-3], @"em": [NSNumber numberWithInteger:2],  @"div": [NSNumber numberWithInteger:0],  @"br": [NSNumber numberWithInteger:2], @"dl": [NSNumber numberWithInteger:-3], @"dt": [NSNumber numberWithInteger:-3], @"form": [NSNumber numberWithInteger:-3], @"h2": [NSNumber numberWithInteger:0], @"h3": [NSNumber numberWithInteger:0], @"h4": [NSNumber numberWithInteger:0],@"h5": [NSNumber numberWithInteger:0], @"h6": [NSNumber numberWithInteger:0],@"li": [NSNumber numberWithInteger:-3], @"ol": [NSNumber numberWithInteger:-3], @"pre": [NSNumber numberWithInteger:3], @"section": [NSNumber numberWithInteger:2],@"td": [NSNumber numberWithInteger:3], @"th": [NSNumber numberWithInteger:-5],@"ul": [NSNumber numberWithInteger:-3]};
        
        
        _articleElementArray = [NSMutableArray array];
        _largeImages = [NSMutableArray array];

        _reCommas = [NSRegularExpression regularExpressionWithPattern:@",[\\s\\,]*" options:0 error:0];
        _reAtLeastOneLowercase = [NSRegularExpression regularExpressionWithPattern:@"[a-z].*[A-Z]|[A-Z].*[a-z]" options:0 error:0];
        
        _reUnlikelyCandidates = [NSRegularExpression regularExpressionWithPattern:@"ad-break|aggregrate|bookmark|disqus|extra|header|ignore|links|menu|nav|pag(?:er|ination)|popup|related|remark|rss|share|tags|shoutbox|sidebar|similar|social|sponsor|teaserlist|time|tweet|twitter" options:0 error:0];
        _reOKMaybeItsACandidate = [NSRegularExpression regularExpressionWithPattern:@"and|article|body|column|main|shadow" options:0 error:0];

        
        _removeIfEmpty = @[@"blockquote", @"li", @"p", @"pre", @"tbody", @"td", @"th", @"thead", @"tr"  ];
        _embeds = @[@"embed", @"object", @"iframe"];
        _goodAttributes = @[@"alt", @"href", @"src", @"title"];
        _cleanConditionally = @[@"div", @"form", @"ol", @"table", @"ul"];
        _unpackDivs = [_embeds arrayByAddingObjectsFromArray:@[@"div", @"img"]];
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
        _startTime = [NSDate date];

        _handler = [handler copy];
        
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
            
            _saxParser = [[AHSAXParser alloc] initWithDelegate:self];
        }
    }
    return self;
}

-(void) start {
    [_saxParser end:_htmlString];
}

-(NSString*) contentHTML {
    if (_topCandidate) {
        [self cleanCandidate:_topCandidate];
        return [AHContentParser trim:_topCandidate.innerHTML];
    }
    
    //    //remove spaces in front of <br>s
    //    .replace(/(?:\s|&nbsp;?)+(?=<br\/>)/g, "")
    //    //remove <br>s in front of opening & closing <p>s
    //    .replace(/(?:<br\/>)+(?:\s|&nbsp;?)*(?=<\/?p)/g, "")
    //    //turn all double+ <br>s into <p>s
    //    .replace(/(?:<br\/>){2,}/g, "</p><p>")
    //    //trim the result
    //    .trim();
    
    return nil;
}

-(void) cleanCandidate:(AHContentElement*) candidate {
    for (AHContentElement *child in [candidate.children copy]) {
        if ([child isKindOfClass:[NSString class]]) {
            continue;
        }
        
        // if the candidate has a large number of paragraphs, then divs are likely not content
        // remove divs with little content
        if ([child.name isEqualToString:@"div"]) {
            if (child.totalScore < 20) {
                [candidate.children removeObject:child];
            } else {
                [self cleanCandidate:child];
            }
        }
    }
    
    if ([candidate.name isEqualToString:@"article"] && _articleElementArray.count > 1) {
        [_articleElementArray enumerateObjectsUsingBlock:^(AHContentElement *elem, NSUInteger idx, BOOL *stop) {
            if ([elem isNotEqualTo:candidate] && elem.children.count > 0) {
                [candidate.children addObjectsFromArray:elem.children];
            }
        }];
    }
    
}


#pragma mark - SAX delegate methods


-(void) onOpenTagName:(NSString*)name{
    
   
    if (![_contentTags containsObject:name] ) {
        if (_currentElement) {
            _currentElement.totalScore -= 2;
        }
    }
    
    _currentElement = [[AHContentElement alloc] initWithTagName:name parent:_currentElement];
}


-(void) onAttributeName:(NSString*)name value:(NSString*) value{
    
    if (!value || !_currentElement) {
        return;
    }

    name = [name lowercaseString];
    AHContentElement *elem = _currentElement;
    
    
    if ([name isEqualToString:@"class"] || [name isEqualToString:@"id"]) {
        [elem.elementData appendString:value];
    }
    
    if ([_currentElement.name isEqualToString:@"img"]) {
        if ([name isEqualToString:@"width"]) {
            NSInteger width = [value integerValue];
            if (width >= 300) {
                [_largeImages addObject:_currentElement];
                _currentElement.parent.numOfLargeImages +=1;
            }
    
        }
    }
    
    if ([_goodAttributes containsObject:name]) {
        [elem.attributes setValue:value forKey:name];
    }
}

-(void) onText:(NSString*) text{
    if (_currentElement) {
        [_currentElement.children addObject:text];
    }
    
}

-(void) onCloseTag:(NSString*)tagName{
    
    AHContentElement *elem = _currentElement;
    _currentElement = elem.parent;

    if ([elem.elementData rangeOfString:@"articleText"].location != NSNotFound) {
        NSLog(@"");
    }
    
    if (![_contentTags containsObject:tagName] || ![_contentTags containsObject:elem.name]) {
        return;
    }
    
    
    // remove empty tags
    if (elem.children.count == 1
        && [elem.children[0] isKindOfClass:[NSString class]]) {
        NSString *txt = [AHContentParser trim:elem.children[0]];
        if (!txt.length || [txt isEqualToString:@"&nbsp;"] ) {
            return;
        }
    }

    // Strip elements with unlikely class or ids like "comments"
//    NSTextCheckingResult *res = [_reUnlikelyCandidates firstMatchInString:elem.elementData options:NSCaseInsensitiveSearch range:NSMakeRange(0, elem.elementData.length)];
//    if (res) {
//        NSString *match = [elem.elementData substringWithRange:res.range];
//    }
    if (elem.elementData && [_reUnlikelyCandidates numberOfMatchesInString:elem.elementData options:NSCaseInsensitiveSearch range:NSMakeRange(0, elem.elementData.length)] && ![_reOKMaybeItsACandidate numberOfMatchesInString:elem.elementData options:NSCaseInsensitiveSearch range:NSMakeRange(0, elem.elementData.length)]) {
        return;
    }

    NSRange r = [elem.elementData rangeOfString:@"sims-data"];
    if (r.length > 0) {
        NSLog(@"");
    }
    
    // Start scoring...
    for (NSUInteger i=0; i < elem.children.count; i++) {
        AHContentElement *child = elem.children[i];
        if ([child isKindOfClass:[NSString class]]) {
            NSString *childString = (NSString*) child;
            childString = [[childString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@""];
            childString = [AHContentParser trim:childString];
            if (childString.length < 1) {
                continue;
            }
            elem.hasChildContainingText = YES;
            elem.textLength += childString.length;
            
            elem.numOfCommas += [_reCommas numberOfMatchesInString:childString options:0 range:NSMakeRange(0, childString.length)];
            
            
            // See if this text has lowercase
            if ([_reAtLeastOneLowercase numberOfMatchesInString:childString options:0 range:NSMakeRange(0, childString.length)]) {
                elem.hasLowercaseChild = YES;
            }
            
        } else {
            
            // Only aggregrate text and link length for elements that have direct text descendants themselves
            if (elem.hasChildContainingText) {
                if ([child.name isEqualToString:@"a"]) {
                    elem.linkLength += child.textLength + child.linkLength;
                } else {
                    elem.textLength += child.textLength;
                    elem.linkLength += child.linkLength;
                }
                elem.numOfCommas += child.numOfCommas;
                elem.numOfSentences += child.numOfSentences;
            }
            
            // Score the child tag
            NSNumber *tagScore = [_tagCounts valueForKey:child.name];
            if (tagScore) {
                elem.totalScore += [tagScore integerValue];
            }
            
            // Score up for children that score well
            if (child.totalScore > 20) {
                elem.totalScore +=5;
            }

            // Keep track of the number of paragraphs, used later
            if ([child.name isEqualToString:@"p"]) {
                elem.numOfParagraphs +=1;
            }
            
            elem.hasLowercaseChild = child.hasLowercaseChild;
      
        
        }
    }
    
    
    
    
    
    // Score up longer text
    if (elem.textLength > 1000) {
        elem.totalScore += 20;
    } else if (elem.textLength > 200) {
        elem.totalScore += 10;
    } else if (elem.textLength > 10) {
        elem.totalScore += 5;
    }
    
    // Score divs down with little text, paragraphs and other tags can have little text
    if (elem.textLength < 100 && [elem.name isEqualTo:@"div"]) {
        elem.totalScore -= 20;
    }
    
    
    // Score up text by number of commas
    elem.totalScore += roundf(elem.numOfCommas/2);
    
    //Score down if there is no child with a lowercase char
    if (!elem.hasLowercaseChild) {
        elem.totalScore -= 20;
    }
    
    // Score up elements with low linkDensitys
    if (elem.linkLength != 0) {
        elem.linkDensity = (float) elem.linkLength / (float)(elem.textLength + elem.linkLength);
        if (elem.linkDensity < 0.2) {
            elem.totalScore+= 5;
        }
        if (elem.linkDensity < 0.1) {
            elem.totalScore += 5;
        }
        if (elem.linkDensity > 0.4) {
            elem.totalScore -= 5;
        }
    } else if (elem.textLength > 10) {
        elem.totalScore += 5;
    }
    
    // Score up for number of largeImages
    if (elem.numOfLargeImages > 0) {
        elem.totalScore += 40;
    }
    
    // Some article are spread across multiple article tags
    // We keep track of them here
    if ([elem.name isEqualToString:@"article"] && elem.totalScore >= 50) {
        [_articleElementArray addObject:elem];
    }
        
    // Add the elem to it's parent
    [elem.parent.children addObject:elem];
    
    // Check if the elem is the new topCandidate!
    if ([_candidateTags containsObject:elem.name] && elem.totalScore > 50
        && elem.totalScore > _topCandidate.totalScore) {
        _topCandidate = elem;
        self.foundContent = YES;
        NSLog(@"Top candidate is %@ %@ with a score of %ld", elem.name, elem.attributes, elem.totalScore);
    } 
    
}


-(void) onError{
    
}

-(void) onEnd{
    if (_handler) {
        _handler(self);
    }
    NSLog(@"Time to parse content: %f", [[NSDate date] timeIntervalSinceDate:_startTime] );
}


#pragma mark - Super Awesome NSString methods


+(NSString*)trim:(NSString*) str {
    return [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}



- (NSString *)removeUnwantedTags:(NSString *)html {
    NSRegularExpression *unwantedTagsRe = [NSRegularExpression regularExpressionWithPattern:@"<head|<script|<style" options:NSCaseInsensitiveSearch error:0];
    
    while (YES) {
        NSRange searchRange = NSMakeRange(0, html.length);
        NSTextCheckingResult *res = [unwantedTagsRe firstMatchInString:html options:NSCaseInsensitiveSearch range:searchRange];
        if (!res) {
            break;
        }
        NSRange start = res.range;
        NSString *tag = [html substringWithRange:NSMakeRange(start.location+1, start.length-1)];
        NSInteger end = [html rangeOfString:[NSString stringWithFormat:@"</%@>", tag] options:NSCaseInsensitiveSearch range:NSMakeRange(start.location, html.length- start.location)].location + tag.length + 3;
        html = [NSString stringWithFormat:@"%@%@", [html substringToIndex:start.location], [html substringFromIndex:end]];        
    }
    return html;
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
