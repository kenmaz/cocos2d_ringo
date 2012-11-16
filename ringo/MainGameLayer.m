//
//  HelloWorldLayer.m
//  ringo
//
//  Created by 松前 健太郎 on 2012/11/14.
//  Copyright __MyCompanyName__ 2012年. All rights reserved.
//


#import "MainGameLayer.h"
#import "AppDelegate.h"
#import "Ringo.h"

#define RINGO_GRID_WIDTH 6
#define RINGO_GRID_HEIGHT 6
#define CHAR_TYPE_EMPTY 0
#define CHAR_TYPE_RINGO 1
#define CHAR_TYPE_ENEMY 2
#define RINGO_FREQUENCY_IN_SEC 1

@interface MainGameLayer ()
@property NSMutableArray* ringoGrid;
@end

@implementation MainGameLayer {
    ccTime elapsed;    
    CGRect ringos[4];
    CGRect deadRingo;
    CGRect enemies[2];
    CGRect bird;
    CGPoint touchStartPoint;
}

+(CCScene *) scene {
	CCScene *scene = [CCScene node];

    CCLayer* background = [CCLayer node];
    CCSprite* backImg = [CCSprite spriteWithFile:@"background.png"];
    CGSize size = [[CCDirector sharedDirector] winSize];
    backImg.position = ccp(size.width / 2, size.height / 2);
    [background addChild:backImg];
    [scene addChild:background];
    
	MainGameLayer *layer = [MainGameLayer node];
	[scene addChild: layer];
	
	return scene;
}

-(id)init {
	if( (self=[super init]) ) {
        
        ringos[0] = CGRectMake(0, 0, 50, 50);
        ringos[1] = CGRectMake(0, 50, 50, 50);
        ringos[2] = CGRectMake(0, 100, 50, 50);
        ringos[3] = CGRectMake(0, 100, 50, 50);
        //ringos[3] = CGRectMake(0, 150, 75, 75);
        deadRingo = CGRectMake(50, 0, 50, 50);
        
        enemies[0] = CGRectMake(50, 50, 50, 50);
        enemies[1] = CGRectMake(50, 100, 50, 50);
        bird = CGRectMake(0, 225, 75, 60);

        self.ringoGrid = [NSMutableArray array];
        
        for (int y = 0; y < RINGO_GRID_HEIGHT; y++) {
            NSMutableArray* ringoGridRow = [NSMutableArray array];
            [self.ringoGrid addObject:ringoGridRow];
            
            for (int x = 0; x < RINGO_GRID_WIDTH; x++) {
                [ringoGridRow addObject:[NSNull null]];
            }
        }
        self.isTouchEnabled = YES;
        [self scheduleUpdate];
	}
	return self;
}

- (void)dealloc {
	
}

- (void)registerWithTouchDispatcher {
    [[[CCDirector sharedDirector] touchDispatcher] addTargetedDelegate:self
                                                              priority:0
                                                       swallowsTouches:YES];
}

#pragma mark CCTargetedTouchDelegate <NSObject>

- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    touchStartPoint = [self convertTouchToNodeSpace: touch];
    return YES;
}
- (void)ccTouchMoved:(UITouch *)touch withEvent:(UIEvent *)event {
    
}
- (void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint touchEndPoint = [self convertTouchToNodeSpace: touch];
    [self ringoFlickedFrom:touchStartPoint endPoint:touchEndPoint];
}
- (void)ccTouchCancelled:(UITouch *)touch withEvent:(UIEvent *)event {
    
}

- (void)ringoFlickedFrom:(CGPoint)startPoint endPoint:(CGPoint)endPoint {
    Ringo* targetRingo = [self findRingoAt:startPoint];
    if (targetRingo) {
        //方向を確定
        float topEdgePos = 568;
        float rightEdgePos = 320;

        float a = (endPoint.y - startPoint.x) / (endPoint.x - startPoint.x);
        float b = endPoint.y - (a * endPoint.x);
        float x, y;
        
        float deltaX = endPoint.x - startPoint.x;
        float deltaY = endPoint.y - startPoint.y;
        if (deltaX < 0) {
            if (deltaY < 0) {
                NSLog(@"左下");
                if (endPoint.y < endPoint.x) {
                    y = 0;
                    x = (y - b) / a;
                } else {
                    x = 0;
                    y = a * x + b;
                }
            } else {
                NSLog(@"左上");
                if (topEdgePos - endPoint.y < endPoint.x) {
                    y = topEdgePos;
                    x = (y - b) / a;
                } else {
                    x = 0;
                    y = a * x + b;
                }
            }
        } else {
            if (deltaY < 0) {
                NSLog(@"右下");
                if (endPoint.y < rightEdgePos - endPoint.x) {
                    y = 0;
                    x = (y - b) / a;
                } else {
                    x = rightEdgePos;
                    y = a * x + b;
                }
            } else {
                NSLog(@"右上");
                if (topEdgePos - endPoint.y < rightEdgePos - endPoint.x) {
                    y = topEdgePos;
                    x = (y - b) / a;
                } else {
                    x = rightEdgePos;
                    y = a * x + b;
                }
            }
        }
        if (x > rightEdgePos) x = rightEdgePos;
        if (y > topEdgePos) y = topEdgePos;
        
        CGPoint dist = CGPointMake(x, y);
        CCLOG(@"start(%d,%d) end(%d,%d) dist(%d,%d)", (int)startPoint.x, (int)startPoint.y, (int)endPoint.x, (int)endPoint.y, (int)dist.x, (int)dist.y);
        CCMoveTo* moveTo = [CCMoveTo actionWithDuration:0.5f position:dist];
        [targetRingo runAction:moveTo];
    }
}

//タップした場所にいるりんごを取得
- (Ringo*)findRingoAt:(CGPoint)point {
    for (NSArray* row in self.ringoGrid) {
        for (id item in row) {
            if (item != [NSNull null]) {
                Ringo* ringo = (Ringo*)item;
                float h = ringo.contentSize.height;
                float w = ringo.contentSize.width;
                float x = ringo.position.x - w/2;
                float y = ringo.position.y - h/2;
                CGRect rect = CGRectMake(x, y, w, h);
                if (CGRectContainsPoint(rect, point)) {
                    return ringo;
                }
            }
        }
    }
    return nil;
}

#pragma mark main loop

- (void)update:(ccTime)delta {
    elapsed += delta;
    if (elapsed > RINGO_FREQUENCY_IN_SEC) {
        elapsed = 0;
        
        //場所をランダムで確定し、りんご配置
        int retryMax = 10;
        int tryCount = 0;
        
        while (tryCount < retryMax) {
            
            int idxX = CCRANDOM_0_1() * RINGO_GRID_WIDTH;
            int idxY = CCRANDOM_0_1() * RINGO_GRID_HEIGHT;
            
            NSMutableArray* row = [self.ringoGrid objectAtIndex:idxY];
            if ([row objectAtIndex:idxX] == [NSNull null]) {
                
                //4種類のリンゴからランダム選出
                int ringoType = CCRANDOM_0_1() * 4;
                CGRect ringoRect = ringos[ringoType];
                CCSprite* ringo = [self characterSpriteWithRect:ringoRect];

                [row insertObject:ringo atIndex:idxX];
                
                CGSize screenSize = [[CCDirector sharedDirector] winSize];
                int gridWidth = screenSize.width / RINGO_GRID_WIDTH;
                int gridHeight = (screenSize.height - 250) / RINGO_GRID_HEIGHT;

                int x = idxX * gridWidth + gridWidth / 2;
                int y = idxY * gridHeight + 200 + gridHeight / 2;
                CCLOG(@"x=%d, y=%d (try=%d)", idxX, idxY, tryCount);
                ringo.position = ccp(x, y);
                
                [self addChild:ringo];

                break;
            }
            tryCount++;
        }
    }
}

- (CCSprite*)characterSpriteWithRect:(CGRect)rect {
    CCSprite* sprite = [CCSprite spriteWithFile:@"characters.png" rect:rect];
    return sprite;
}


@end
