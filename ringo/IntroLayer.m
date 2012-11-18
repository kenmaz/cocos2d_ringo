//
//  IntroLayer.m
//  ringo
//
//  Created by 松前 健太郎 on 2012/11/14.
//  Copyright __MyCompanyName__ 2012年. All rights reserved.
//


// Import the interfaces
#import "IntroLayer.h"
#import "MainGameLayer.h"


#pragma mark - IntroLayer

// HelloWorldLayer implementation
@implementation IntroLayer

// Helper class method that creates a Scene with the HelloWorldLayer as the only child.
+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
    // background layer
    CCLayer* background = [CCLayer node];
    CCSprite* backImg = [CCSprite spriteWithFile:@"background.png"];
    CGSize size = [[CCDirector sharedDirector] winSize];
    backImg.position = ccp(size.width / 2, size.height / 2);
    [background addChild:backImg];
    [scene addChild:background];

	// 'layer' is an autorelease object.
	IntroLayer *layer = [IntroLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

-(id) init
{
	if ((self = [super init])) {
		CGSize size = [[CCDirector sharedDirector] winSize];

		//title
		CCLabelTTF *label = [CCLabelTTF labelWithString:@"Ringo Hunting" fontName:@"Marker Felt" fontSize:55];
		label.position =  ccp( size.width /2 , size.height/2 + 150);
		[self addChild: label];
		
		//eady,normal,hard buttons
		[CCMenuItemFont setFontSize:32];
		
		CCMenuItem *easyMenu = [CCMenuItemFont
                                itemWithString:@"Easy"
                                block:^(id sender) {
                                    [self transitionGameScence:GameModeEasy];
                                }];
		CCMenuItem *normalMenu = [CCMenuItemFont
                                  itemWithString:@"Normal"
                                  block:^(id sender) {
                                      [self transitionGameScence:GameModeNormal];
                                  }];
		CCMenuItem *hardMenu = [CCMenuItemFont
                                itemWithString:@"Hard"
                                block:^(id sender) {
                                    [self transitionGameScence:GameModeHard];
                                }];
		
		CCMenu *menu = [CCMenu menuWithItems:easyMenu, normalMenu, hardMenu, nil];
        [menu alignItemsVerticallyWithPadding:20];
		[menu setPosition:ccp( size.width/2, size.height/2)];
		
		// Add the menu to the layer
		[self addChild:menu];
        
	}
	return self;
}

-(void) transitionGameScence:(GameMode)gameMode {
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:1.0 scene:[MainGameLayer sceneWithGameMode:gameMode] withColor:ccBLACK]];
}
@end
