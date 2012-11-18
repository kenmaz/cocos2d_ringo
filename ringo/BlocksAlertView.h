//
//  BlocksAlertView.h
//  elmo
//
//  Created by 松前　健太郎 on 12/09/24.
//
//

#import <UIKit/UIKit.h>

@interface BlocksAlertView : UIAlertView <UIAlertViewDelegate>

@property (nonatomic, copy) void (^completionBlock)(NSInteger buttonIndex);

- (id)initWithTitle:(NSString *)title message:(NSString *)message cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;
- (void)showWithCompletionBlock:(void (^)(NSInteger buttonIndex))block;

@end
