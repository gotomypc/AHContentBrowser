//
//  AHSAXParser.m
//  AHContentBrowser
//
//  Created by John Wright on 9/13/12.
//  Copyright (c) 2012 John Wright. All rights reserved.
//

#import "AHSAXParser.h"

// Special tags that are treated differently
#define AHSAXSpecialTagStyle 0x1
#define AHSAXSpecialTagScript 0x2
#define AHSAXSpecialTagComment 0x3
#define AHSAXSpecialTagCDATA 0x4

typedef enum{
    AHSAXParserElementTypeText=0,
    AHSAXParserElementTypeDirective=1,
    AHSAXParserElementTypeComment=2,
    AHSAXParserElementTypeScript=3,
    AHSAXParserElementTypeStyle=4,
    AHSAXParserElementTypeTag=5,
    AHSAXParserElementTypeCData=6
} AHSAXParserElementType;

@implementation AHSAXParser {
    NSMutableString *_buffer;
    NSString *_tagSep;
    NSMutableArray *_stack;
    BOOL _wroteSpecial;
    int _contentFlags;
    BOOL _done;
    BOOL _running;
    id<AHSaxParserDelegate> _delegate;
    NSRegularExpression *_reTail;
    NSRegularExpression *_reAttrib;
    NSArray *_emptyTags;
}

-(id) initWithDelegate:(id<AHSaxParserDelegate>)delegate {
    self = [super init];
    if (self) {
        [self reset];
        _buffer = [[NSMutableString alloc] init];
        _delegate = delegate;
        _reTail = [NSRegularExpression regularExpressionWithPattern:@"\\s|/|$" options:NSCaseInsensitiveSearch error:0];
        _reAttrib = [NSRegularExpression regularExpressionWithPattern:@"\\s([^\\s/]+?)(?:\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|(\\S+))|(?=\\s)|/|$)" options:NSCaseInsensitiveSearch error:0];
        _emptyTags = @[@"area", @"base", @"basefront", @"br", @"col", @"frame", @"hr", @"img", @"input", @"isindex", @"link", @"meta", @"param", @"embed"];
        
    }
    return self;
}

-(void) parseComplete:(NSString*) data {
    [self reset];
    [self end:data];
}

-(void) parseChunk:(NSString*) data {
    if (_done) {
        [self handleError:@"Attempted to parse chunk after parsing already done"];
        return;
    }
    [_buffer appendString:data];
    if (_running) {
        [self parseTags:NO];
    }
}


-(void) end:(NSString*) data {
    if (_done) {
        return;
    }
    
    if (data) {
        [self parseChunk:data];
    }
    _done = YES;
    if (_running) {
        [self finishParsing];
    }
}

-(void) finishParsing {
    //Parse the buffer to its end
    if (_buffer) {
        [self parseTags:YES];
    }
    if ([_delegate respondsToSelector:@selector(onOpenTagName:)]) {
        while(_stack.count) {
            [_delegate onOpenTagName:[_stack lastObject]];
            [_stack removeLastObject];
        }
    }
    if ([_delegate respondsToSelector:@selector(onEnd)]) {
        [_delegate onEnd];
    }
}

-(void) pause {
    if (_done) {
        _running = NO;
    }
}


-(void) resume {
    if (_running) {
        return;
    }
    _running = YES;
    [self parseTags:NO];
    if (_done) {
        [self finishParsing];
    }
}

//Resets the parser to a blank state, ready to parse a new HTML document
-(void) reset {
    _buffer = [NSMutableData data];
    _tagSep = @"";
    _stack = [NSMutableArray array];
    _wroteSpecial = NO;
    _contentFlags = 0;
    _done = NO;
    _running = YES;
    if ([_delegate respondsToSelector:@selector(onReset)]) {
        [_delegate performSelector:@selector(onReset)];
    }
}

//Extracts the base tag name from the data value of an element

-(NSString*) parseTagName:(NSString*) data {
    NSTextCheckingResult *res = [_reTail firstMatchInString:data options:NSCaseInsensitiveSearch range:NSMakeRange(0, data.length)];
    
    if (res) {
        NSString *match = [data substringWithRange:NSMakeRange(0,res.range.location)];
        if (!self.useLowerCaseTags) {
            return match;
        }
        return [match lowercaseString];
    }
    return nil;
}

-(void) parseTags:(BOOL)force {
    NSInteger current = 0;
    NSInteger opening = [_buffer rangeOfString:@"<"].location;
    NSInteger closing = [_buffer rangeOfString:@">"].location;
    NSInteger next;
    NSString *rawData;
    NSString *elementData;
    NSString *lastTagSep;
    
    if (force) {
        opening = NSIntegerMax;
    }
    
    while (opening != closing && _running) {
        lastTagSep = _tagSep;
        
        if ((opening != -1 && opening < closing) || closing == -1) {
            next = opening;
            _tagSep = @"<";
            opening = [_buffer rangeOfString:@"<" options:0 range:NSMakeRange(next+1, _buffer.length-next-1)].location;
            
        } else {
            next = closing;
            _tagSep = @">";
            closing = [_buffer rangeOfString:@">" options:0 range:NSMakeRange(next+1, _buffer.length-next-1)].location;
        }
        // the next chunk of data to parse
        rawData = [_buffer substringWithRange:NSMakeRange(current, MAX(next-current, 0))];
        
           
        // set elements for next run
        current =  next + 1;
        
        if (_contentFlags >= AHSAXSpecialTagCDATA) {
            // we are inside a CData section
            [self writeCDATA:rawData];
        } else if (_contentFlags >= AHSAXSpecialTagComment) {
            // We are in a comment tag
            [self writeComment:rawData];
        } else if ([lastTagSep isEqualToString:@"<"]) {
            elementData = [self trimLeft:rawData];
            if ([[elementData substringToIndex:1] isEqualToString:@"/"]) {
                elementData = [self parseTagName:[elementData substringFromIndex:1]];
                if (_contentFlags != 0) {
                    // if it's a closing tag, remove the flag
                    if (_contentFlags && [self tagValue:elementData]) {
                        //remove the flag
                        _contentFlags ^= [self tagValue:elementData];
                    } else {
                        [self writeSpecial:rawData lastTagSep:lastTagSep];
                        continue;
                    }
                    
                }
                [self processCloseTag:elementData];
            } else if ([[elementData substringToIndex:1] isEqualToString:@"!"]) {
                if (elementData.length > 7 && [[elementData substringWithRange:NSMakeRange(1, 7)] isEqualToString:@"[CDATA["]) {
                    _contentFlags |= AHSAXSpecialTagCDATA;
                    if ([_delegate respondsToSelector:@selector(onCDATAStart)]) {
                        [_delegate onCDATAStart];
                    }
                    [self writeCDATA:[elementData substringFromIndex:8]];
                } else if (_contentFlags != 0) {
                    [self writeSpecial:rawData lastTagSep:lastTagSep];
                }  else if ([[elementData substringWithRange:NSMakeRange(1, 2)] isEqualToString:@"--"]) {
                    // This tag is a  comment
                    _contentFlags |= AHSAXSpecialTagComment;
                    [self writeComment:[elementData substringFromIndex:3]];
                } else if ([_delegate respondsToSelector:@selector(onProcessingInstruction:elementData:)]) {
                    [_delegate performSelector:@selector(onProcessingInstruction:elementData:) withObject:[NSString stringWithFormat:@"?%@", [self parseTagName:[elementData substringFromIndex:1]]] withObject:elementData];
                }
                
            } else if (_contentFlags !=0 ) {
                [self writeSpecial:rawData lastTagSep:lastTagSep];
            } else if ([[elementData substringToIndex:1] isEqualToString:@"?"]) {
                if ([_delegate respondsToSelector:@selector(onProcessingInstruction:elementData:)]) {
                    [_delegate performSelector:@selector(onProcessingInstruction:elementData:) withObject:[NSString stringWithFormat:@"?%@", [self parseTagName:[elementData substringFromIndex:1]]] withObject:elementData];
                }
            } else {
                [self processOpenTag:elementData];
            }
        } else {
            if (_contentFlags != 0) {
                [self writeSpecial:rawData lastTagSep:@">"];
                
            } else if (![rawData isEqualToString:@""] && [_delegate respondsToSelector:@selector(onText:)]) {
                if ([_tagSep isEqualToString:@">"]) {
                    // it is the second > in a row
                    rawData = [rawData stringByAppendingString:@">"];
                }
                if ([_delegate respondsToSelector:@selector(onText:)]) {
                    [_delegate onText:rawData];
                }
            }
        }
        
    }
    _buffer = [[_buffer substringFromIndex:current] mutableCopy];
    
}


-(void) writeCDATA:(NSString*) data {
    if ([_tagSep isEqualToString:@">"] && [[data substringFromIndex:data.length-2] isEqualToString:@"]]"]) {
        // CDATA ends
        if (data.length != 2 && [_delegate respondsToSelector:@selector(onText:)] ) {
            [_delegate onText:[data substringToIndex:data.length-2]];
        }
        _contentFlags ^= AHSAXSpecialTagCDATA;
        if ([_delegate respondsToSelector:@selector(onCDATAEnd)]) {
            [_delegate performSelector:@selector(onCDATAEnd)];
        }
    } else if ([_delegate respondsToSelector:@selector(onText:)]) {
        [_delegate onText:[data stringByAppendingString:_tagSep]];
    }
}


-(void) writeComment:(NSString*) rawData {
    if (rawData && rawData.length > 2 && [_tagSep isEqualToString:@">"] && [[rawData substringFromIndex:rawData.length-2] isEqualToString:@"--"]) {
        // comment ends
        // remove the written flag (also remove the comment flag)
        _contentFlags ^= AHSAXSpecialTagComment;
        _wroteSpecial = NO;
        if ([_delegate respondsToSelector:@selector(onComment:)]) {
            [_delegate performSelector:@selector(onComment:) withObject:[rawData substringToIndex:rawData.length-2]];
        }
        if ([_delegate respondsToSelector:@selector(onCommentEnd)]) {
            [_delegate performSelector:@selector(onCommentEnd) ];
        }
    } else if ([_delegate respondsToSelector:@selector(onComment:)]) {
        [_delegate performSelector:@selector(onComment:) withObject:[rawData stringByAppendingString:_tagSep]];
    }
    
}

-(void) writeSpecial:(NSString*) rawData lastTagSep:(NSString*) lastTagSep {
    // if the previous element is text, append the last tag sep to element
    if (_wroteSpecial) {
        if ([_delegate respondsToSelector:@selector(onText:)]) {
            [_delegate performSelector:@selector(onText:) withObject:[lastTagSep stringByAppendingString:rawData]];
        }
        
    } else {
        //The previous element was not text
        _wroteSpecial = YES;
        if (![rawData isEqualToString:@""] && [_delegate respondsToSelector:@selector(onText:)]) {
            [_delegate onText:rawData];
        }
    }
}

-(void) processCloseTag:(NSString*) name {
    if (_stack && (![_emptyTags containsObject:name] || self.shouldParseAsXML)) {
        NSInteger pos = [self lastIndexOfString:name inArray:_stack];
        if (pos != -1) {
            if ([_delegate respondsToSelector:@selector(onCloseTag:)]) {
                pos = _stack.count - pos;
                while (pos--) {
                    [_delegate onCloseTag:[_stack lastObject]];
                    [_stack removeLastObject];
                }
            } else {
                [_stack removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(pos, _stack.count)]];
            }
        }
    }	else if([name isEqualToString:@"br"] && !self.shouldParseAsXML){
        //many browsers (eg. Safari, Chrome) convert </br> to <br>
        [self processOpenTag:[name stringByAppendingString:@"/"]];
	}
}

-(NSInteger) lastIndexOfString:(NSString*)string inArray:(NSArray*) array {
    for (NSInteger i = array.count-1; i>=0;i--) {
        if ([array[i] isEqualToString:string]) {
            return i;
        }
    }
    return -1;
}

-(void) parseAttributesFromData:(NSString*) data lowerCaseNames:(BOOL) useLowerCaseNames {
    
    NSArray *results = [_reAttrib matchesInString:data options:0 range:NSMakeRange(0, data.length)];
    for (NSTextCheckingResult *res in results) {
        if (res.numberOfRanges <= 1) {
            continue;
        }
        NSString *attributeName = [data substringWithRange:[res rangeAtIndex:1]];
        if (useLowerCaseNames) {
            attributeName = [attributeName lowercaseString];
        }
        NSString *attribVal;
        for (NSUInteger i=2; i < res.numberOfRanges; i++) {
            NSRange nextRange = [res rangeAtIndex:i];
            if (nextRange.location + nextRange.length< data.length) {
                attribVal = attribVal ? attribVal : [data substringWithRange:[res rangeAtIndex:i]];
                if (attribVal) {
                    break;
                }
            }
        }
        attribVal = attribVal ? attribVal : @"";
        [_delegate onAttributeName:attributeName value:attribVal];
    }
    
}


-(void) processOpenTag:(NSString*) data {
    NSString *name = [self parseTagName:data];
    int type = AHSAXParserElementTypeTag;
    if (self.shouldParseAsXML);
    else if ([name isEqualToString:@"script"]) type = AHSAXParserElementTypeScript;
    else if ([name isEqualToString:@"style"]) type = AHSAXParserElementTypeStyle;
    
    if ([_delegate respondsToSelector:@selector(onOpenTagName:)]) {
        [_delegate onOpenTagName:name];
    }
    //todo add onOpenTag delegate call
    
    if ([_delegate respondsToSelector:@selector(onAttributeName:value:)]) {
        [self parseAttributesFromData:data lowerCaseNames:self.useLowerCaseAttributeNames];
    }
    
    if ([_delegate respondsToSelector:@selector(onOpenTagEnd)]) {
        [_delegate onOpenTagEnd];
    }
    
    if ([[data substringToIndex:data.length-1] isEqualToString:@"/"] || ([_emptyTags containsObject:name] && !self.shouldParseAsXML)) {
        if ([_delegate respondsToSelector:@selector(onCloseTag:)]) {
            [_delegate onCloseTag:name];
        }
    } else {
        if (type != AHSAXParserElementTypeTag) {
            _contentFlags |= [self specialTagLookup:type];
            _wroteSpecial = false;
        }
        [_stack addObject:name];
    }
}

-(void) handleError:(NSString*) error {
    if ([_delegate respondsToSelector:@selector(onError:)]) {
        [_delegate performSelector:@selector(onError) withObject:error];
    }
}

-(int) specialTagLookup:(AHSAXParserElementType) type {
    switch (type) {
        case AHSAXParserElementTypeStyle:
            return AHSAXSpecialTagStyle;
            break;
        case AHSAXParserElementTypeScript:
            return AHSAXSpecialTagScript;
            break;
        case AHSAXParserElementTypeComment:
            return AHSAXSpecialTagComment;
            break;
        case AHSAXParserElementTypeCData:
            return AHSAXSpecialTagCDATA;
            break;
        default:
            break;
    }
    return 0;
}

-(int) tagValue:(NSString*) tag {
    if ([tag isEqualToString:@"style"]) {
        return 1;
    }
    return 2;
}

# pragma mark - String utils

-(NSString*)trimLeft:(NSString*) str {
    NSInteger i = 0;
    
    while ((i < [str length])
           && [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[str characterAtIndex:i]]) {
        i++;
    }
    return [str substringFromIndex:i];
}



@end
