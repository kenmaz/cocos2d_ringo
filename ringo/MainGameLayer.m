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
    //CCLOG(@"touch start: %d,%d", (int)touchStartPoint.x, (int)touchStartPoint.y);
    return YES;
}
- (void)ccTouchMoved:(UITouch *)touch withEvent:(UIEvent *)event {
    
}
- (void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint touchEndPoint = [self convertTouchToNodeSpace: touch];
    //CCLOG(@"touch end: %d,%d", (int)touchEndPoint.x, (int)touchEndPoint.y);
    [self ringoFlickedFrom:touchStartPoint endPoint:touchEndPoint];
}
- (void)ccTouchCancelled:(UITouch *)touch withEvent:(UIEvent *)event {
    
}

- (void)ringoFlickedFrom:(CGPoint)startPoint endPoint:(CGPoint)endPoint {
    Ringo* targetRingo = [self findRingoAt:startPoint];
    if (targetRingo) {

        //タッチの始点・終点から一次方程式を解く
        float a = (startPoint.y - endPoint.y) / (startPoint.x - endPoint.x);
        float b = endPoint.y - (a * endPoint.x);
        float x, y;

        //方程式の線と、上下左右の端が交差する点をそれぞれ割り出し
        CGSize size = [[CCDirector sharedDirector] winSize];
        float topEdgePos = size.height - 50;
        float rightEdgePos = size.width;

        x = 0;
        CGPoint leftPt = CGPointMake(x, (a * x + b));
        x = rightEdgePos;
        CGPoint rightPt = CGPointMake(x, (a * x + b));
        y = 0;
        CGPoint bottomPt = CGPointMake(((y - b) / a), y);
        y = topEdgePos;
        CGPoint topPt = CGPointMake(((y - b) / a), y);
        
        //方向から目的地を決定
        CGRect winFrame = CGRectMake(0, 0, size.width + 1, size.height + 1); //ぴったりの時もtrueを返すために+1
        CGPoint dist;
        
        float deltaX = endPoint.x - startPoint.x;
        float deltaY = endPoint.y - startPoint.y;
        if (deltaX < 0) {
            if (deltaY < 0) {
                NSLog(@"左下");
                dist = CGRectContainsPoint(winFrame, leftPt) ? leftPt : bottomPt;
            } else {
                NSLog(@"左上");
                dist = CGRectContainsPoint(winFrame, leftPt) ? leftPt : topPt;
            }
        } else {
            if (deltaY < 0) {
                NSLog(@"右下");
                dist = CGRectContainsPoint(winFrame, rightPt) ? rightPt : bottomPt;
            } else {
                NSLog(@"右上");
                dist = CGRectContainsPoint(winFrame, rightPt) ? rightPt : topPt;
            }
        }
        CCLOG(@"\n start:%@ \n end:%@. \n a = %f \n b = %f \n left=%@, \n right=%@, \n top=%@, \n bottom=%@ => \n dist=%@",
              NSStringFromCGPoint(startPoint),
              NSStringFromCGPoint(endPoint),
              a,
              b,
              NSStringFromCGPoint(leftPt),
              NSStringFromCGPoint(rightPt),
              NSStringFromCGPoint(topPt),
              NSStringFromCGPoint(bottomPt),
              NSStringFromCGPoint(dist)
              );
        
        //リンゴを移動
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
                //CCLOG(@"x=%d, y=%d (try=%d)", idxX, idxY, tryCount);
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
