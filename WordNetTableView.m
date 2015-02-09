//
//  WordNetTableView.h
//  WordNetX
//
//  Created by William Taysom on Thur Sept 4 2003.
//

#import "WordNetTableView.h"

@implementation WordNetTableView

- (BOOL)needsPanelToBecomeKey
{
    return YES;
}

- (void)copy:(id)sender
{
    NSPasteboard* pboard=[NSPasteboard generalPasteboard];
    NSString *str;
    
    if ([self selectedRow] >= 0)
        str = [(id <NSTableViewDataSource>)[self delegate] tableView:self
            objectValueForTableColumn:[[self tableColumns] objectAtIndex:0]
            row:[self selectedRow]];
    else
        str = @"";
            
    [pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType,nil] owner:self];
    [pboard setString:str forType:NSStringPboardType];
}


@end
