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

#define Z_IDX_BACKGROUND    0
#define Z_IDX_RINGO         1
#define Z_IDX_KAGO_FRONT    2
#define Z_IDX_SCORE         5

#define KAGO_EDGE_LEFT_X    64
#define KAGO_EDGE_RIGHT_X   232

@interface MainGameLayer ()
@property NSMutableArray* ringoGrid;
@property NSMutableArray* movingRingos;
@property CCSprite* kago;
@property CCLabelTTF* scoreLabel;
@end

@implementation MainGameLayer {
    ccTime spawnRingoElapsed;
    CGRect ringos[4];
    CGRect deadRingo;
    CGRect enemies[2];
    CGRect bird;
    CGPoint touchStartPoint;
    int _score;
}

+(CCScene *) scene {
	CCScene *scene = [CCScene node];

    MainGameLayer *layer = [MainGameLayer node];
	[scene addChild: layer];

	return scene;
}

-(id)init {
	if( (self=[super init]) ) {
        
        CCSprite* backImg = [CCSprite spriteWithFile:@"background.png"];
        CGSize size = [[CCDirector sharedDirector] winSize];
        backImg.position = ccp(size.width / 2, size.height / 2);
        [self addChild:backImg z:Z_IDX_BACKGROUND];

        self.kago = [CCSprite spriteWithFile:@"kago_front.png"];
        self.kago.position = ccp(backImg.position.x, self.kago.contentSize.height / 2);
        [self addChild:self.kago z:Z_IDX_KAGO_FRONT];
        
		self.scoreLabel = [CCLabelTTF labelWithString:@"0" fontName:@"Marker Felt" fontSize:30];
		self.scoreLabel.position =  ccp( size.width /2 , 20);
		[self addChild: self.scoreLabel z:Z_IDX_SCORE];
        
        _score = 0;
        [self updateScoreLabel];
        
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
        self.movingRingos = [NSMutableArray array];
        
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

//フリック操作の開始終了座標をもとにリンゴを投げる
- (void)ringoFlickedFrom:(CGPoint)startPoint endPoint:(CGPoint)endPoint {
    Ringo* targetRingo = [self removeRingoAt:startPoint];
    if (targetRingo) {
        
        //移動中リンゴリストに追加
        [self.movingRingos addObject:targetRingo];
        
        //タッチの始点・終点から一次方程式を解く
        float a = (startPoint.y - endPoint.y) / (startPoint.x - endPoint.x);
        float b = endPoint.y - (a * endPoint.x);
        float x, y;

        //方程式の線と、上下左右の端が交差する点をそれぞれ割り出し
        CGSize size = [[CCDirector sharedDirector] winSize];
        float topEdgePos = size.height - 50 + targetRingo.contentSize.height;
        float bottomEdgePos = -1 * targetRingo.contentSize.height;
        float rightEdgePos = size.width + targetRingo.contentSize.width;
        float leftEdgePos = -1 * targetRingo.contentSize.width;

        x = leftEdgePos;
        CGPoint leftPt = CGPointMake(x, (a * x + b));
        x = rightEdgePos;
        CGPoint rightPt = CGPointMake(x, (a * x + b));
        y = bottomEdgePos;
        CGPoint bottomPt = CGPointMake(((y - b) / a), y);
        y = topEdgePos;
        CGPoint topPt = CGPointMake(((y - b) / a), y);
        
        //方向から目的地を決定 (CGRectContainsPointは境界値を範囲外と判定するので+1余裕をもたせる)
        CGRect winFrame = CGRectMake(leftEdgePos,
                                     bottomEdgePos,
                                     size.width + (targetRingo.contentSize.width * 2) + 1,
                                     size.height + (targetRingo.contentSize.height * 2) + 1);
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
                NSLog(@"右上, %d",CGRectContainsPoint(winFrame, rightPt));
                dist = CGRectContainsPoint(winFrame, rightPt) ? rightPt : topPt;
            }
        }
        CCLOG(@"\n start:%@ \n end:%@. \n a = %f \n b = %f \n left=%@, \n right=%@, \n top=%@, \n bottom=%@ \n frame=%@ => \n dist=%@",
              NSStringFromCGPoint(startPoint),
              NSStringFromCGPoint(endPoint),
              a,
              b,
              NSStringFromCGPoint(leftPt),
              NSStringFromCGPoint(rightPt),
              NSStringFromCGPoint(topPt),
              NSStringFromCGPoint(bottomPt),
              NSStringFromCGRect(winFrame),
              NSStringFromCGPoint(dist)
              );
        
        //リンゴを移動
        CCMoveTo* moveTo = [CCMoveTo actionWithDuration:0.5f position:dist];
        CCCallBlock* finishBlock = [CCCallBlock actionWithBlock:^ {
            [self.movingRingos removeObject:targetRingo];
            [self removeChild:targetRingo cleanup:YES];
        }];
        CCSequence* seq = [CCSequence actions:moveTo, finishBlock, nil];
        [targetRingo runAction:seq];
    }
}

//タップした場所にりんごが入ればgridから削除して返す。なければnilを返す
- (Ringo*)removeRingoAt:(CGPoint)point {
    for (NSMutableArray* row in self.ringoGrid) {
        for (int idx = 0; idx < [row count]; idx++) {
            id item = [row objectAtIndex:idx];
            if (item != [NSNull null]) {
                Ringo* ringo = (Ringo*)item;
                float h = ringo.contentSize.height;
                float w = ringo.contentSize.width;
                float x = ringo.position.x - w/2;
                float y = ringo.position.y - h/2;
                CGRect rect = CGRectMake(x, y, w, h);
                if (CGRectContainsPoint(rect, point)) {
                    [row replaceObjectAtIndex:idx withObject:[NSNull null]];
                    return ringo;
                }
            }
        }
    }
    return nil;
}

#pragma mark main loop

- (void)update:(ccTime)delta {
    [self spawnRingo:delta];
    [self checkMovingRingosPosition:delta];
    
}

- (void)checkMovingRingosPosition:(ccTime)delta {
    float kagoY = self.kago.contentSize.height;
    for (Ringo* ringo in self.movingRingos) {
        if (ringo.position.y < kagoY) {
            float x = ringo.position.x;
            if (KAGO_EDGE_LEFT_X < x && x < KAGO_EDGE_RIGHT_X) {
                CCLOG(@"Get Ringo! %@", ringo);

                _score++;
                [self updateScoreLabel];
                
                [self showGetLabelAt:ringo.position];

                [self.movingRingos removeObject:ringo];
                [self removeChild:ringo cleanup:YES];
                
            }
        }
    }
}

- (void)showGetLabelAt:(CGPoint)position {
    CCLabelTTF* getLabel = [CCLabelTTF labelWithString:@"Get!" fontName:@"Marker Felt" fontSize:20];
    getLabel.color = ccRED;
    getLabel.position = position;
    [self addChild:getLabel z:Z_IDX_SCORE];
    
    CCMoveTo* flowAction = [CCMoveTo actionWithDuration:1.0 position:ccp(position.x, position.y + 50)];
    CCFadeOut* fadeout = [CCFadeOut actionWithDuration:1.0];
    CCSpawn* flowAndFadeout = [CCSpawn actions:flowAction, fadeout, nil];
    CCCallBlock* removeBlock = [CCCallBlock actionWithBlock:^{
        [self removeChild:getLabel cleanup:YES];
    }];
    CCSequence* seq = [CCSequence actions:flowAndFadeout, removeBlock, nil];
    [getLabel runAction:seq];
}

//一定周期毎にリンゴを産み出す
- (void)spawnRingo:(ccTime)delta {
    spawnRingoElapsed += delta;
    if (spawnRingoElapsed > RINGO_FREQUENCY_IN_SEC) {
        spawnRingoElapsed = 0;
        
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
                
                [row replaceObjectAtIndex:idxX withObject:ringo];
                
                CGSize screenSize = [[CCDirector sharedDirector] winSize];
                int gridWidth = screenSize.width / RINGO_GRID_WIDTH;
                int gridHeight = (screenSize.height - 250) / RINGO_GRID_HEIGHT;
                
                int x = idxX * gridWidth + gridWidth / 2;
                int y = idxY * gridHeight + 200 + gridHeight / 2;
                //CCLOG(@"x=%d, y=%d (try=%d)", idxX, idxY, tryCount);
                ringo.position = ccp(x, y);
                
                [self addChild:ringo z:Z_IDX_RINGO];
                
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

- (void)updateScoreLabel {
    self.scoreLabel.string = [[NSNumber numberWithInt:_score] stringValue];
}

@end
