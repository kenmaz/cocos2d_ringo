//
//  IntroLayer.h
//  ringo
//
//  Created by 松前 健太郎 on 2012/11/14.
//  Copyright __MyCompanyName__ 2012年. All rights reserved.
//


// When you import this file, you import all the cocos2d classes
#import "cocos2d.h"

typedef enum {
    GameModeNone = 0,
    GameModeEasy = 1,
    GameModeNormal = 2,
    GameModeHard = 3,
    GameModeCount = 4,
} GameMode;

// HelloWorldLayer
@interface IntroLayer : CCLayer
{
}

// returns a CCScene that contains the HelloWorldLayer as the only child
+(CCScene *) scene;

@end
