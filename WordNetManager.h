//
//  WordNetManager.h
//  WordNetX
//
//  Created by William Taysom on Mon Aug 25 2003.
//

#import <Foundation/Foundation.h>

#define NUM_TYPES 4

typedef enum {noun = 1, verb, adj, adv} POS;

@interface WordNetManager : NSObject {
    NSBundle *dataBundle;
    NSMutableDictionary *indexDict, *dataDict,
        *nameOfrelation;
    NSMutableArray *relationOrdering;
    NSArray *nounRoots, *verbRoots, *verbFrames;
    FILE *indexFiles[NUM_TYPES + 1];
    FILE *dataFiles[NUM_TYPES + 1];
    FILE *excFiles[NUM_TYPES + 1];
}
+ (NSString *)posString:(POS)p;

- (id)initWithBundle:(NSBundle *)bundle;
- (void)dealloc;
- (BOOL)validSynset:(NSNumber *)synset;

- (NSArray *)wordsForSynset:(NSNumber *)synset;
- (NSArray *)synsetsForWord:(NSString *)word;
- (NSArray *)synsetsForInflectedWord:(NSString *)word;

- (NSString *)avatarForSynset:(NSNumber *)synset;
- (NSString *)avatarForSynset:(NSNumber *)synset excepting:(NSString *)word;
- (NSString *)avatarForSynset:(NSNumber *)synset atIndex:(int)index;

/* returns nil if relation does not hold for any values,
           array of NSNumbers for synset relations,
           array of two element NSArrays for lexical relations
            (first element is a synset
             and second is an the sense number of a word for the synset),
           array of NSStrings for verb frames,
           NSString for glosses*/
- (id)dataForSynset:(NSNumber *)synset withRelation:(NSString *)relation;

- (NSArray *)wordsForSynset:(NSNumber *)synset;
- (NSString *)glossForSynset:(NSNumber *)synset;
- (NSArray *)verbFramesForSynset:(NSNumber *)synset;
- (NSNumber *)hypernymForSynset:(NSNumber *)synset;
- (NSArray *)hyponymsForSynset:(NSNumber *)synset;
- (NSArray *)relationsForSynset:(NSNumber *)synset;
- (NSArray *)ancestryForSynset:(NSNumber *)synset;
- (POS)posForSynset:(NSNumber *)synset;

- (NSArray *)allHypernymRoots;
- (NSArray *)hypernymNounRoots;
- (NSArray *)hypernymVerbRoots;

- (NSArray *)allRelations;
- (NSArray *)verbFrames;
- (NSString *)nameOfrelation:(NSString *)relation;
- (BOOL)isRelation:(id)testObject;
@end