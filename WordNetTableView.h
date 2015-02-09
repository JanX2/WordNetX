//
//  WordNetTableView.h
//  WordNetX
//
//  Created by William Taysom on Thur Sept 4 2003.
//

#import <Cocoa/Cocoa.h>

@interface WordNetTableView : NSTableView {
    BOOL holdFirstResponder;
}
- (BOOL)needsPanelToBecomeKey;
- (void)copy:(id)sender;
@end
