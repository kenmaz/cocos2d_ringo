//
//  HelloWorldLayer.m
//  ringo
//
//  Created by 松前 健太郎 on 2012/11/14.
//  Copyright __MyCompanyName__ 2012年. All rights reserved.
//


#import "MainGameLayer.h"
#import "IntroLayer.h"
#import "AppDelegate.h"
#import "Ringo.h"
#import "Enemy.h"
#import "Bird.h"
#import "BlocksAlertView.h"

#define RINGO_GRID_WIDTH 6
#define RINGO_GRID_HEIGHT 6
#define CHAR_TYPE_EMPTY 0
#define CHAR_TYPE_RINGO 1
#define CHAR_TYPE_ENEMY 2

#define ELEMENT_FREQUENCY_IN_SEC 1
#define BIRD_FLY_WAITTIME_IN_SEC 3
#define BIRD_FLY_SPEED_IN_SEC 1

#define RINGO_SPAWN_RATIO   7
#define ENEMY_SPAWN_RATIO   3

#define Z_IDX_BACKGROUND    0
#define Z_IDX_RINGO         1
#define Z_IDX_BIRD          2
#define Z_IDX_KAGO_FRONT    3
#define Z_IDX_SCORE         5

#define KAGO_EDGE_LEFT_X    64
#define KAGO_EDGE_RIGHT_X   232

@interface MainGameLayer ()
@property NSMutableArray* ringoGrid;
@property NSMutableArray* movingElements;
@property NSMutableArray* flyingBirds;
@property CCSprite* kago;
@property CCLabelTTF* scoreLabel;
@end

@implementation MainGameLayer {
    ccTime spawnElementElapsed;
    CGRect ringos[4];
    CGRect deadRingo;
    CGRect enemies[2];
    CGRect _bird;
    CGPoint touchStartPoint;
    int _score;
    BOOL _gameover;
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
        
        ringos[0] = CGRectMake(0, 0, 50, 50);
        ringos[1] = CGRectMake(0, 50, 50, 50);
        ringos[2] = CGRectMake(0, 100, 50, 50);
        ringos[3] = CGRectMake(0, 100, 50, 50);
        //ringos[3] = CGRectMake(0, 150, 75, 75);
        deadRingo = CGRectMake(50, 0, 50, 50);
        
        enemies[0] = CGRectMake(50, 50, 50, 50);
        enemies[1] = CGRectMake(50, 100, 50, 50);
        _bird = CGRectMake(0, 225, 75, 60);

        srandom(time(NULL));
        
        self.isTouchEnabled = YES;
        
        [self resetGame];
        
        [self scheduleUpdate];
	}
	return self;
}

- (void)resetGame {
    
    //木に生えているelementをビューから破棄して、nullオブジェクトで埋める
    for (NSArray* row in self.ringoGrid) {
        for (id element in row) {
            if (element != [NSNull null]) {
                [self removeChild:element cleanup:YES];
            }
        }
    }
    self.ringoGrid = [NSMutableArray array];
    for (int y = 0; y < RINGO_GRID_HEIGHT; y++) {
        NSMutableArray* ringoGridRow = [NSMutableArray array];
        [self.ringoGrid addObject:ringoGridRow];
        
        for (int x = 0; x < RINGO_GRID_WIDTH; x++) {
            [ringoGridRow addObject:[NSNull null]];
        }
    }

    //動いているelementをビューから破棄してmoveingElement初期化
    for (CCSprite* element in self.movingElements) {
        [self removeChild:element cleanup:YES];
    }
    self.movingElements = [NSMutableArray array];
    
    //飛んでいるトリをビューから消してコレクション初期化
    for (Bird* bird in self.flyingBirds) {
        [self removeChild:bird cleanup:YES];
    }
    self.flyingBirds = [NSMutableArray array];
    
    //スコアリセット
    _score = 0;
    [self updateScoreLabel];
    
    //ゲームオーバーフラグリセット
    _gameover = NO;
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
    [self elementFlickedFrom:touchStartPoint endPoint:touchEndPoint];
}
- (void)ccTouchCancelled:(UITouch *)touch withEvent:(UIEvent *)event {
    
}

#pragma mark main loop

- (void)update:(ccTime)delta {
    if (_gameover) {
        return;
    }
    [self spawnElement:delta];
    [self checkMovingElementsPosition:delta];
    [self checkFlyingBirds:delta];
}

- (void)checkFlyingBirds:(ccTime)delta {
    for (Bird* bird in self.flyingBirds) {
        Ringo* removedRingo = [self removeRingoFromGridAt:bird.position];
        if (removedRingo) {
            [self showGetLabelAt:removedRingo.position];
            [self removeChild:removedRingo cleanup:YES];
        }
    }
}

- (void)checkMovingElementsPosition:(ccTime)delta {
    float kagoY = self.kago.contentSize.height;
    for (CCSprite* element in self.movingElements) {
        if (element.position.y < kagoY) {
            float x = element.position.x;
            if (KAGO_EDGE_LEFT_X < x && x < KAGO_EDGE_RIGHT_X) {
                if ([element isKindOfClass:[Ringo class]]) {
                    CCLOG(@"Get Ringo! %@", element);
                    _score++;
                    [self updateScoreLabel];
                    [self showGetLabelAt:element.position];
                    [self.movingElements removeObject:element];
                    [self removeChild:element cleanup:YES];
                } else {
                    CCLOG(@"Gameover (get enemy :%@)", element);
                    [self showGameoverDialog];
                    _gameover = YES;
                    return;
                }
            }
        }
    }
}

#pragma mark GameLogics

//フリック操作の開始終了座標をもとにelementを投げる
- (void)elementFlickedFrom:(CGPoint)startPoint endPoint:(CGPoint)endPoint {
    CCSprite* targetElement = [self removeElementFromGridAt:startPoint];
    if (targetElement) {
        
        //移動中elementリストに追加
        [self.movingElements addObject:targetElement];
        
        //タッチの始点・終点から一次方程式を解く
        float a = (startPoint.y - endPoint.y) / (startPoint.x - endPoint.x);
        float b = endPoint.y - (a * endPoint.x);
        float x, y;
        
        //方程式の線と、上下左右の端が交差する点をそれぞれ割り出し
        CGSize size = [[CCDirector sharedDirector] winSize];
        float topEdgePos = size.height - 50 + targetElement.contentSize.height;
        float bottomEdgePos = -1 * targetElement.contentSize.height;
        float rightEdgePos = size.width + targetElement.contentSize.width;
        float leftEdgePos = -1 * targetElement.contentSize.width;
        
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
                                     size.width + (targetElement.contentSize.width * 2) + 1,
                                     size.height + (targetElement.contentSize.height * 2) + 1);
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
        
        //elementを移動
        CCMoveTo* moveTo = [CCMoveTo actionWithDuration:0.5f position:dist];
        CCCallBlock* finishBlock = [CCCallBlock actionWithBlock:^ {
            [self.movingElements removeObject:targetElement];
            [self removeChild:targetElement cleanup:YES];
        }];
        CCSequence* seq = [CCSequence actions:moveTo, finishBlock, nil];
        [targetElement runAction:seq];
    }
}

//タップした場所にelementがいればgridから削除して返す。なければnilを返す
- (CCSprite*)removeElementFromGridAt:(CGPoint)point {
    return [self removeElementFromGridAt:point onlyRingo:NO];
}

//タップした場所にRingoがいればgridから削除して返す。なければnilを返す
- (Ringo*)removeRingoFromGridAt:(CGPoint)point {
    return (Ringo*)[self removeElementFromGridAt:point onlyRingo:YES];
}

//タップした場所にelementがいればgridから削除して返す。なければnilを返す
- (CCSprite*)removeElementFromGridAt:(CGPoint)point onlyRingo:(BOOL)onlyRingo {
    
    for (NSMutableArray* row in self.ringoGrid) {
        
        for (int idx = 0; idx < [row count]; idx++) {
            id element = [row objectAtIndex:idx];
            
            if (element != [NSNull null]) {
                //リンゴだけ消す場合は型チェック
                if (onlyRingo && [element isKindOfClass:[Ringo class]] == NO) {
                    continue;
                }
                CCSprite* sprite = (CCSprite*)element;
                float h = sprite.contentSize.height;
                float w = sprite.contentSize.width;
                float x = sprite.position.x - w/2;
                float y = sprite.position.y - h/2;
                CGRect rect = CGRectMake(x, y, w, h);
                if (CGRectContainsPoint(rect, point)) {
                    [row replaceObjectAtIndex:idx withObject:[NSNull null]];
                    return sprite;
                }
            }
        }
    }
    return nil;
}

- (void)showGameoverDialog {
    NSString* message = @"";
    BlocksAlertView* alert = [[BlocksAlertView alloc] initWithTitle:@"Game Over"
                                                            message:message
                                                  cancelButtonTitle:@"Back To Title"
                                                  otherButtonTitles:@"Retry", nil];
    [alert showWithCompletionBlock:^(NSInteger index) {
        switch (index) {
            case 0:
                [[CCDirector sharedDirector] replaceScene:
                 [CCTransitionFade transitionWithDuration:1.0
                                                    scene:[IntroLayer scene] withColor:ccBLACK]];
                break;
            case 1:
            default:
                [self resetGame];
        }
    }];
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

//一定周期毎にリンゴor害虫を産み出す
- (void)spawnElement:(ccTime)delta {
    spawnElementElapsed += delta;
    if (spawnElementElapsed > ELEMENT_FREQUENCY_IN_SEC) {
        spawnElementElapsed = 0;
        
        //空いている場所を検索
        CGPoint emptyIndex = [self findEmptyGridIndexAtRandom];
        if (emptyIndex.x == -1 || emptyIndex.y == -1) {
            //空きなし
            return;
        }
        int idxX = emptyIndex.x;
        int idxY = emptyIndex.y;
        
        NSMutableArray* row = [self.ringoGrid objectAtIndex:idxY];
        
        CCSprite* element;
        if (CCRANDOM_0_1() * (RINGO_SPAWN_RATIO + ENEMY_SPAWN_RATIO) > RINGO_SPAWN_RATIO) {
            //2種類の的からランダム選出
            int type = CCRANDOM_0_1() * 2;
            element = [Enemy spriteWithFile:@"characters.png" rect:enemies[type]];
            
        } else {
            //4種類のリンゴからランダム選出
            int ringoType = CCRANDOM_0_1() * 4;
            element = [Ringo spriteWithFile:@"characters.png" rect:ringos[ringoType]];
            
            CCDelayTime* delayTimeAction = [CCDelayTime actionWithDuration:BIRD_FLY_WAITTIME_IN_SEC];
            CCCallBlock* birdAction = [CCCallBlock actionWithBlock:^{
                NSLog(@"bird!!!");
                [self flyBirdTo:(Ringo*)element];
            }];
            [element runAction:[CCSequence actions:delayTimeAction, birdAction, nil]];
        }
        
        [row replaceObjectAtIndex:idxX withObject:element];
        
        CGSize screenSize = [[CCDirector sharedDirector] winSize];
        int gridWidth = screenSize.width / RINGO_GRID_WIDTH;
        int gridHeight = (screenSize.height - 250) / RINGO_GRID_HEIGHT;
        
        int x = idxX * gridWidth + gridWidth / 2;
        int y = idxY * gridHeight + 200 + gridHeight / 2;
        //CCLOG(@"x=%d, y=%d (try=%d)", idxX, idxY, tryCount);
        element.position = ccp(x, y);
        
        [self addChild:element z:Z_IDX_RINGO];
    }
}

- (void)flyBirdTo:(Ringo*)ringo {
    Bird* bird = [Bird spriteWithFile:@"characters.png" rect:_bird];
    [self addChild:bird z:Z_IDX_BIRD];
    [self.flyingBirds addObject:bird];
    
    CGSize size = [[CCDirector sharedDirector] winSize];
    CGPoint startPos = ccp(size.width + bird.contentSize.width / 2, ringo.position.y);
    CGPoint endPos = ccp(-1 * bird.contentSize.width / 2, ringo.position.y);
    bird.position = startPos;
    
    CCMoveTo* moveTo = [CCMoveTo actionWithDuration:BIRD_FLY_SPEED_IN_SEC position:endPos];
    CCCallBlock* finish = [CCCallBlock actionWithBlock:^{
        [self removeChild:bird cleanup:YES];
        [self.flyingBirds removeObject:bird];
    }];
    CCSequence* seq = [CCSequence actions:moveTo, finish, nil];
    [bird runAction:seq];
}

- (CGPoint)findEmptyGridIndexAtRandom {
    int retryMax = 10;
    int tryCount = 0;
    
    while (tryCount < retryMax) {
        
        int idxX = CCRANDOM_0_1() * RINGO_GRID_WIDTH;
        int idxY = CCRANDOM_0_1() * RINGO_GRID_HEIGHT;
        
        NSMutableArray* row = [self.ringoGrid objectAtIndex:idxY];
        if ([row objectAtIndex:idxX] == [NSNull null]) {
            return CGPointMake(idxX, idxY);
        }
        tryCount++;
    }
    return CGPointMake(-1, -1);
}

- (CCSprite*)characterSpriteWithRect:(CGRect)rect {
    CCSprite* sprite = [CCSprite spriteWithFile:@"characters.png" rect:rect];
    return sprite;
}

- (void)updateScoreLabel {
    self.scoreLabel.string = [[NSNumber numberWithInt:_score] stringValue];
}

@end
