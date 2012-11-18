//
//  HelloWorldLayer.h
//  ringo
//
//  Created by 松前 健太郎 on 2012/11/14.
//  Copyright __MyCompanyName__ 2012年. All rights reserved.
//

#import "cocos2d.h"
#import "IntroLayer.h"

// HelloWorldLayer
@interface MainGameLayer : CCLayer <UIAlertViewDelegate>
{
}

// returns a CCScene that contains the HelloWorldLayer as the only child
+(CCScene *) sceneWithGameMode:(GameMode)gameMode;

@end
