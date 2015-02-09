//
//  WordNetManager.m
//  WordNetX
//
//  Created by William Taysom on Mon Aug 25 2003.
//

#import "WordNetManager.h"
#include <string.h>
#include "binsrch.h"

#define MINSYNSET 100000000
#define MAXSYNSET 499999999
#define DIGITSINSYNSET 8
#define MAX_RELATION_LENGTH 4

const char posCoding[NUM_TYPES + 1] = {'\0', 'n', 'v', 'a', 'r'};
NSString *typeStrings[] = { @"", @"noun", @"verb", @"adj", @"adv"};

#define LINE_SIZE 4096 * 4
char lineBuffer[LINE_SIZE];

NSString *glossSymbol = @"|";
NSString *hypernymSymbol = @"@";
NSString *hyponymSymbol = @"~";
NSString *framesSymbol = @"***f";
NSString *wordsSymbol = @"***w";
NSString *relationSymbol = @"****";

#define NUM_INFLECTIONS 17

struct Inflection {
    NSString *suffix;
    NSString *ending;
} inflections[NUM_INFLECTIONS] = {
    {@"s", @""},
    {@"ses", @"s"},
    {@"xes", @"s"},
    {@"zes", @"z"},
    {@"ches", @"ch"},
    {@"shes", @"sh"},
    {@"ies", @"y"},
    {@"es", @"e"},
    {@"es", @""},
    {@"ed", @"e"},
    {@"ed", @""},
    {@"ing", @"e"},
    {@"ing", @""},
    {@"er", @""},
    {@"est", @""},
    {@"er", @"e"},
    {@"est", @"e"},
};

@implementation WordNetManager

//*** Private Functions

NSInteger getclippedline(char s[], NSInteger lim, FILE *f) {
    NSInteger c = 0, i;
    
    for (i=0; i<lim-1 && (c=fgetc(f))!=EOF && c!='\n'; ++i)
        s[i]=c;
    if (c == '\n') {
        s[i]='\0';
        ++i;
    }
    return i;
}

void findCharReplace(char find, char replace, char *line) {
    NSInteger i;
    for(i = 0; line[i] != EOF; ++i)
        if (line[i] == find)
             line[i] = replace;
}

NSInteger indexOfCharInArray(char c, char *array, NSInteger count) {
    NSInteger i;
    
    for (i = 0; i < count; ++i)
        if (array[i] == c)
            return i;
    
    return -1;
}

//*** End Private Functions 

//*** Private Methods

- (NSArray *)loadRootsOfType:(POS)type
{
    NSMutableArray *rootlist = [[NSMutableArray alloc] init];
    FILE *a;
    NSInteger synval;
    char *line;
    
    if (!(a = fopen([[dataBundle pathForResource:@"roots"
            ofType:(NSString *)typeStrings[type]] UTF8String], "r")))
        return nil;
    
    while (getclippedline(lineBuffer, LINE_SIZE, a)) {
        line = lineBuffer;
        if ((synval = strtol(line, &line, 10)))
            [rootlist addObject:[NSNumber numberWithInteger:synval + type * MINSYNSET]];
    }
    
    fclose(a);
    return rootlist;
}

- (void) loadVerbFrames
{
    FILE *a;
    NSMutableArray *vf;
    char *line;
    
    if (!(a = fopen([[dataBundle pathForResource:@"frames"
            ofType:@"vrb"] UTF8String], "r")))
        return;
    
    vf = [[NSMutableArray alloc] init];

    while (getclippedline(lineBuffer, LINE_SIZE, a)) {
        line = lineBuffer;
        
        while(*line == ' ' || isdigit(*line))
            ++line;
        
        [vf addObject:@(line)];
    }
    
    fclose(a);
    verbFrames = vf;
    [verbFrames retain];
}

- (void)loadRelationFormat
{
    FILE *a;
    NSInteger i, j;
    char *line, relation[MAX_RELATION_LENGTH + 1];
    NSString *relationString;
    
    nameOfrelation = [[NSMutableDictionary alloc] init];
    [nameOfrelation retain];
    
    relationOrdering = [[NSMutableArray alloc] init];
    [relationOrdering retain];
    
    if (!(a = fopen([[dataBundle pathForResource:@"relations"
            ofType:@"format"] UTF8String], "r")))
        return;
    
    for (i = 0; getclippedline(lineBuffer, LINE_SIZE, a); ++i) {
        line = lineBuffer;
        
        for (j = 0; !isspace(*line) && j < 4; ++line) {
            relation[j++] = *line;
        }
        relation[j] = '\0';
        relationString = @(relation);
        
        ++line; // " "
        
        [nameOfrelation setObject:@(line)
            forKey:relationString];
        [relationOrdering addObject:relationString];
    }
    
    fclose(a);
}

- (void)toData:(NSMutableDictionary *)data addObject:(id)object 
    withRelation:(id)relation
{
    if ([relation isEqualToString:glossSymbol]) {
        [data setObject:object forKey:relation];
        return;
    }
    if (![data objectForKey:relation])
        [data setObject:[[NSMutableArray alloc] init] forKey: relation];
    [[data objectForKey:relation] addObject:object];
}

- (NSArray *)loadSynsetsForWord:(NSString *)word
{
    NSInteger i, j, synset = 0;
    NSMutableArray *synsets;
    char *line, query[BUFSIZ];
    
    [[word lowercaseString] getCString:query];
    findCharReplace(' ', '_', query);
    
    synsets = [[NSMutableArray alloc] init];
    for (i=1; i <= NUM_TYPES; ++i) {
        if (!(line = bin_search(query, indexFiles[i])))
            continue;

        line += strlen(query);
        for (;; ++line) {
            if (isdigit(*line)) {
                for (j=1; j < DIGITSINSYNSET; ++j)
                    if (!isdigit(line[j]))
                        break;
                if (j == DIGITSINSYNSET)
                    break;
            }
        }
        
        for(; isdigit(*line); ++line) {
            synset = strtol(line, &line, 10);
            synset += i * MINSYNSET;
            [synsets addObject:[NSNumber numberWithInteger:synset]];
        }
    }
    
    [indexDict setObject:synsets forKey:word];
    return synsets;
}

- (NSDictionary *) loadDataForSynset:(NSNumber *)synset
{
    NSMutableDictionary *data;
    NSString *relationString;
    NSMutableArray *relationsArray, *finalRelationsArray; 
    POS synpos = [synset intValue] / MINSYNSET;
    NSInteger synval = [synset integerValue] % MINSYNSET;
    NSInteger i, j, totalwords, totalrelations, totalframes,
        relsynval, relsynpos, frame, wordIndex;
    char *line, word[BUFSIZ], relation[MAX_RELATION_LENGTH + 1];
    
    data = [[NSMutableDictionary alloc] init];
    
    if (fseek(dataFiles[synpos],synval,SEEK_SET))
        return data;
    
    getclippedline(lineBuffer, LINE_SIZE, dataFiles[synpos]);
    line = lineBuffer;
    
    if (synval != strtol(line, &line, 10))	// matches invalid synsets
        return data;
    
    line += 6; // " %2d %c "
    totalwords = strtol(line, &line, 16);
    ++line;
    
    for (i = 0; i < totalwords; ++i) {
        for (j = 0;!isspace(*line);++line) {
            word[j++] = *line;
        }
        word[j] = '\0';
        
        findCharReplace('_', ' ', word);
        
        if (synpos == adj) {
            findCharReplace('(', '\0', word);
        }
        
        [self toData:data addObject:@(word)
            withRelation:wordsSymbol];
        
        line += 3; // " %1x "
    }
    
    totalrelations = strtol(line, &line, 10);
    ++line;
    
    relationsArray = [[NSMutableArray alloc] init];
    for (i = 0; i < totalrelations; ++i) {
        for (j = 0; !isspace(*line) && j < 4; ++line) {
            relation[j++] = *line;
        }
        relation[j] = '\0';
        relationString = @(relation);
        [relationsArray addObject:relationString];

        line += 1; // " "
        relsynval = strtol(line, &line, 10);
        ++line;
        relsynpos = indexOfCharInArray(*line, (char *) posCoding, NUM_TYPES + 1);
        
        line += 4; // "%c %2d"
        
        wordIndex = strtol(line, &line, 16);
        
        if (wordIndex) {
            [self toData:data
                addObject:[NSArray arrayWithObjects:
                    [NSNumber numberWithInteger:(relsynpos * MINSYNSET + relsynval)],
                    [NSNumber numberWithInteger:wordIndex], nil]
                withRelation:relationString];
        } else {
            [self toData:data
                addObject:[NSNumber numberWithInteger:(relsynpos * MINSYNSET + relsynval)]
                withRelation:relationString];
        }
        
        ++line; // " "
    }
        
    if (synpos == verb) {
        totalframes = strtol(line, &line, 10);
        ++line; // " "
        [relationsArray addObject:framesSymbol];
        for (i = 0; i < totalframes; ++i) {
            line += 2; // "+ "
            
            frame = strtol(line, &line, 10);
            
            [self toData:data
                addObject:[verbFrames objectAtIndex: frame]
                withRelation:framesSymbol];
                            
            line += 4; // " %2d "
        }
    }

    [relationsArray addObject:wordsSymbol];
    finalRelationsArray = [[NSMutableArray alloc] init];
    for (i = 0; i < [relationOrdering count]; ++i) {
        relationString = [relationOrdering objectAtIndex:i];
        if ([relationsArray containsObject:relationString])
            [finalRelationsArray addObject:relationString];
    }

    [data setObject:finalRelationsArray forKey:relationSymbol];

    if (*line == '|') {
        line += 2; // "| "
        strcpy(word, line);
        word[0] = toupper(word[0]);
        
        [self toData:data
                addObject:[typeStrings[synpos] stringByAppendingString:
                    [@": " stringByAppendingString:
                        @(word)]]
                withRelation:glossSymbol];
    }
        
    return data;
}

//*** End Private Methods

+ (NSString *)posString:(POS)p
{
    if (p == noun) return @"noun";
    if (p == verb) return @"verb";
    if (p == adj) return @"adjective";
    if (p == adv) return @"adverb";
    return @"";
}

- (id)initWithBundle:(NSBundle *)bundle
{
    NSInteger i;
    FILE *a;
    
    if (self = [super init]) {
        dataBundle = bundle;
        [dataBundle retain];
        
        indexDict = [[NSMutableDictionary alloc] init];
        [indexDict retain];
        
        dataDict = [[NSMutableDictionary alloc] init];
        [dataDict retain];
        
        nounRoots = [self loadRootsOfType:noun];
        [nounRoots retain];
        verbRoots = [self loadRootsOfType:verb];
        [verbRoots retain];
        
        [self loadVerbFrames];
        [self loadRelationFormat];

        
        for (i = 1; i <= NUM_TYPES; ++i) {
            if (!(a = fopen([[dataBundle pathForResource:@"index"
                    ofType:(NSString *)typeStrings[i]] UTF8String], "r")))
                return nil;
            indexFiles[i] = a;
        }
        
        for (i = 1; i <= NUM_TYPES; ++i) {
            if (!(a = fopen([[dataBundle pathForResource:@"data"
                    ofType:(NSString *)typeStrings[i]] UTF8String], "r")))
                return nil;
            dataFiles[i] = a;
        }
        
        for (i = 1; i <= NUM_TYPES; ++i) {
            if (!(a = fopen([[dataBundle pathForResource:(NSString *)typeStrings[i]
                    ofType:@"exc"] UTF8String], "r")))
                return nil;
            excFiles[i] = a;
        }
        
        [indexDict setObject:[[NSArray alloc] init] forKey:@""];
    }
    return self;
}

- (void)dealloc
{
    NSInteger i;
    
    [dataBundle release];
    [indexDict release];
    [dataDict release];
    [nounRoots release];
    [verbRoots release];
    [verbFrames release];
    
    for (i = 1; i <= NUM_TYPES; ++i)
        fclose(indexFiles[i]);
        
    for (i = 1; i <= NUM_TYPES; ++i)
        fclose(dataFiles[i]);
        
    for (i = 1; i <= NUM_TYPES; ++i)
        fclose(excFiles[i]);
    
    [super dealloc];
}

- (BOOL)validSynset:(NSNumber *)synset
{
    NSInteger synpos;
    char *synsetString;
    
    if ([synset integerValue] < MINSYNSET || [synset integerValue] > MAXSYNSET)
        return NO;
        
    synpos = [synset integerValue] / MINSYNSET;
    synsetString = ( char *) [[[synset stringValue] substringFromIndex: 1] UTF8String];
    
    if (bin_search(synsetString, indexFiles[synpos]))
        return YES;
    return NO;
}

- (NSArray *)synsetsForWord:(NSString *)word
{
    NSArray *synsets;
    
    if ((synsets = [indexDict objectForKey:word]))
        return synsets;
    return [self loadSynsetsForWord:word];
}

- (NSArray *)synsetsForInflectedWord:(NSString *)word
{
    NSString *base, *wordlower;
    NSMutableSet *synsets = [[NSMutableSet alloc] init];
    NSInteger i, j;
    char *line, query[BUFSIZ];
    
    [synsets addObjectsFromArray:[self synsetsForWord:word]];
        
    wordlower = [word lowercaseString];
    [wordlower getCString:query];
    findCharReplace(' ', '_', query);
    
    for (i = 1; i <= NUM_TYPES; ++i) {
        if ((line = bin_search(query, excFiles[i]))) {
            line += [word length] + 1; // " "
            
            for (j = 0; *line != '\n'; ++line)
                query[j++] = *line;
            query[j] = '\0';
            
            [synsets addObjectsFromArray:
                [self synsetsForWord:@(query)]];
        }
    }
    
    for (i = 0; i < NUM_INFLECTIONS; ++i) {
        if ([wordlower hasSuffix:inflections[i].suffix]) {
            base = [[wordlower substringToIndex:
                ([wordlower length]-[inflections[i].suffix length])] 
                    stringByAppendingString:inflections[i].ending];
           [synsets addObjectsFromArray:[self synsetsForWord:base]];
        }
    }
    
    return [[synsets allObjects] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSString *)avatarForSynset:(NSNumber *)synset
{
    return [self avatarForSynset:synset excepting:@""];
}

- (NSString *)avatarForSynset:(NSNumber *)synset excepting:(NSString *)word
{
    NSString *avatar;
    NSArray *list;
        
    list = [self wordsForSynset:synset];
    avatar = [list objectAtIndex:0];
    
    if ([[avatar lowercaseString] isEqualToString:[word lowercaseString]])
        if ([list count] > 1)
            avatar = [list objectAtIndex:1];
        
    return avatar;
}

- (NSString *)avatarForSynset:(NSNumber *)synset atIndex:(NSInteger)index
{
    NSArray *list = [self wordsForSynset:synset];
    
    if ([list count] > index)
        return [list objectAtIndex:index];
    else
        return [list objectAtIndex:0];
}

- (id)dataForSynset:(NSNumber *)synset withRelation:(id)relation
{
    NSDictionary *data;
    
    if ((data = [dataDict objectForKey:synset]))
        return [data objectForKey:relation];
    return [[self loadDataForSynset:synset] objectForKey:relation];
}

- (NSArray *)wordsForSynset:(NSNumber *)synset
{
    return [self dataForSynset:synset withRelation:wordsSymbol];
}

- (NSString *)glossForSynset:(NSNumber *)synset
{
    return [self dataForSynset:synset withRelation:glossSymbol];
}

- (NSArray *)verbFramesForSynset:(NSNumber *)synset
{
    return [self dataForSynset:synset withRelation:framesSymbol];
}

- (NSNumber *)hypernymForSynset:(NSNumber *)synset
{
    NSArray *hypernyms = [self dataForSynset:synset withRelation:hypernymSymbol];
    if ([hypernyms count])
        return [hypernyms objectAtIndex:0];
    return nil;
}

- (NSArray *)hyponymsForSynset:(NSNumber *)synset
{
    return [self dataForSynset:synset withRelation:hyponymSymbol];
}

- (NSArray *)relationsForSynset:(NSNumber *)synset
{
    return [self dataForSynset:synset withRelation:relationSymbol];
}

- (NSArray *)ancestryForSynset:(NSNumber *)synset
{
    NSMutableArray *ancestry = [[NSMutableArray alloc] init];
    
    if (!synset)
        return ancestry;
        
    do {
        [ancestry addObject:synset];
    } while ((synset = [self hypernymForSynset:synset]));
    return ancestry;
}

- (POS)posForSynset:(NSNumber *)synset
{
    return [synset intValue] / MINSYNSET;
}

- (NSArray *)allHypernymRoots
{
    NSMutableArray *all;

    all = [[NSMutableArray alloc] initWithArray:nounRoots];
    [all addObjectsFromArray:verbRoots];
    
    return all;
}

- (NSArray *)hypernymNounRoots
{
    return nounRoots;
}

- (NSArray *)hypernymVerbRoots
{
    return verbRoots;
}

- (NSArray *)allRelations
{
    return relationOrdering;
}


- (NSArray *)verbFrames
{
    return verbFrames;
}

- (NSString *)nameOfrelation:(NSString *)relation
{
    return [nameOfrelation objectForKey:relation];
}

- (BOOL)isRelation:(id)testObject
{
    return [relationOrdering containsObject:testObject];
}
@end
