//
//  BlocksAlertView.m
//  elmo
//
//  Created by 松前　健太郎 on 12/09/24.
//
//

#import "BlocksAlertView.h"

@implementation BlocksAlertView

- (id)initWithTitle:(NSString *)title message:(NSString *)message cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... {
    return [super initWithTitle:title message:message delegate:self cancelButtonTitle:cancelButtonTitle otherButtonTitles:otherButtonTitles, nil];
}

- (void)showWithCompletionBlock:(void (^)(NSInteger buttonIndex))block {
    self.completionBlock = block;
    [super show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    self.completionBlock(buttonIndex);
}

@end
