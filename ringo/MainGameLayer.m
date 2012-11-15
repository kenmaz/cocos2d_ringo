//
//  HelloWorldLayer.m
//  ringo
//
//  Created by 松前 健太郎 on 2012/11/14.
//  Copyright __MyCompanyName__ 2012年. All rights reserved.
//


// Import the interfaces
#import "MainGameLayer.h"

// Needed to obtain the Navigation Controller
#import "AppDelegate.h"

#pragma mark - HelloWorldLayer

// HelloWorldLayer implementation
@implementation MainGameLayer

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

    CCSprite* ringo1 = [self characterSpriteWithX:0 y:0 width:50 height:50];
    ringo1.position = ccp(size.width / 2, size.height / 2 - 50);
    [scene addChild:ringo1];

    CCSprite* ringo2 = [self characterSpriteWithX:0 y:50 width:50 height:50];
    ringo2.position = ccp(size.width / 2, size.height / 2 + 50);
    [scene addChild:ringo2];

    CCSprite* ringo3 = [self characterSpriteWithX:0 y:100 width:50 height:50];
    ringo3.position = ccp(size.width / 2 - 50, size.height / 2);
    [scene addChild:ringo3];
    {
        CCSprite* ringo4 = [self characterSpriteWithX:0 y:150 width:75 height:75];
        ringo4.position = ccp(size.width / 2 - 150, size.height / 2);
        [scene addChild:ringo4];
    }
    {
        CCSprite* ringo4 = [self characterSpriteWithX:0 y:225 width:75 height:60];
        ringo4.position = ccp(size.width / 2 + 50, size.height / 2);
        [scene addChild:ringo4];
    }
    {
        CCSprite* sprite = [self characterSpriteWithX:50 y:0 width:50 height:50];
        sprite.position = ccp(size.width / 2 + 100, size.height / 2);
        [scene addChild:sprite];
        
    }
    {
        CCSprite* sprite = [self characterSpriteWithX:50 y:50 width:50 height:50];
        sprite.position = ccp(size.width / 2, size.height / 2 + 100);
        [scene addChild:sprite];
        
    }
    {
        CCSprite* sprite = [self characterSpriteWithX:50 y:100 width:50 height:50];
        sprite.position = ccp(size.width / 2 + 100, size.height / 2 - 100);
        [scene addChild:sprite];
        
    }
    
	// 'layer' is an autorelease object.
	MainGameLayer *layer = [MainGameLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

+ (CCSprite*)characterSpriteWithX:(float)x y:(float)y width:(float)width height:(float)height {
    CCSprite* sprite = [CCSprite spriteWithFile:@"characters.png" rect:CGRectMake(x, y, width, height)];
    CGSize size = [[CCDirector sharedDirector] winSize];
    sprite.position = ccp(size.width / 2, size.height / 2);
    return sprite;
}

// on "init" you need to initialize your instance
-(id) init
{
	if( (self=[super init]) ) {

	}
	return self;
}

// on "dealloc" you need to release all your retained objects
- (void) dealloc
{
	// in case you have something to dealloc, do it in this method
	// in this particular example nothing needs to be released.
	// cocos2d will automatically release all the children (Label)
	
	// don't forget to call "super dealloc"
	[super dealloc];
}

#pragma mark GameKit delegate

-(void) achievementViewControllerDidFinish:(GKAchievementViewController *)viewController
{
	AppController *app = (AppController*) [[UIApplication sharedApplication] delegate];
	[[app navController] dismissModalViewControllerAnimated:YES];
}

-(void) leaderboardViewControllerDidFinish:(GKLeaderboardViewController *)viewController
{
	AppController *app = (AppController*) [[UIApplication sharedApplication] delegate];
	[[app navController] dismissModalViewControllerAnimated:YES];
}
@end
