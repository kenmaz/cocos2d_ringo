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
#import "Enemy.h"
#import "Bird.h"
#import "BlocksAlertView.h"

#define RINGO_GRID_WIDTH 6
#define RINGO_GRID_HEIGHT 6
#define CHAR_TYPE_EMPTY 0
#define CHAR_TYPE_RINGO 1
#define CHAR_TYPE_ENEMY 2

#define Z_IDX_BACKGROUND    0
#define Z_IDX_RINGO         1
#define Z_IDX_BIRD          2
#define Z_IDX_KAGO_FRONT    3
#define Z_IDX_SCORE         5

#define KAGO_EDGE_LEFT_X    64
#define KAGO_EDGE_RIGHT_X   232

//game params
#define ELEMENT_SPAWN_FREQUENCY_IN_SEC_AS_EASY 0.75
#define ELEMENT_SPAWN_FREQUENCY_IN_SEC_AS_NORMAL 0.625
#define ELEMENT_SPAWN_FREQUENCY_IN_SEC_AS_HARD 0.5

#define BIRD_FLY_WAITTIME_IN_SEC 2
#define BIRD_FLY_SPEED_IN_SEC 1
#define WARM_WAIT_IN_SEC 3

#define RINGO_SPAWN_RATIO   6
#define ENEMY_SPAWN_RATIO   4

#define MAX_MISS_COUNT      5

@interface MainGameLayer ()
@property NSMutableArray* ringoGrid;
@property NSMutableArray* movingElements;
@property NSMutableArray* flyingBirds;
@property CCSprite* kago;
@property CCLabelTTF* scoreLabel;
@property CCLabelTTF* missLabel;
@property GameMode gameMode;
@end

@implementation MainGameLayer {
    ccTime spawnElementElapsed;
    CGRect ringos[4];
    CGRect deadRingo;
    CGRect enemies[2];
    CGRect _bird;
    CGPoint touchStartPoint;
    float _elementSpawnFrequencyInSec;
    int _score;
    int _missCount;
    BOOL _gameover;
}

#pragma mark cocos2d lifecycle

+(CCScene *) sceneWithGameMode:(GameMode)gameMode {
	CCScene *scene = [CCScene node];

    MainGameLayer *layer = [MainGameLayer node];
    layer.gameMode = gameMode;
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
        
		self.scoreLabel = [CCLabelTTF labelWithString:@"" fontName:@"Marker Felt" fontSize:30];
        self.scoreLabel.color = ccGREEN;
		self.scoreLabel.position =  ccp( size.width /2 - 50 , 20);
		[self addChild: self.scoreLabel z:Z_IDX_SCORE];

        self.missLabel = [CCLabelTTF labelWithString:@"" fontName:@"Marker Felt" fontSize:30];
        self.missLabel.color = ccYELLOW;
		self.missLabel.position =  ccp( size.width /2 + 50 , 20);
		[self addChild: self.missLabel z:Z_IDX_SCORE];

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
- (void)onEnter {
    if (self.gameMode == GameModeEasy) {
        _elementSpawnFrequencyInSec = ELEMENT_SPAWN_FREQUENCY_IN_SEC_AS_EASY;
    }
    else if (self.gameMode == GameModeHard) {
        _elementSpawnFrequencyInSec = ELEMENT_SPAWN_FREQUENCY_IN_SEC_AS_HARD;
    }
    else {
        _elementSpawnFrequencyInSec = ELEMENT_SPAWN_FREQUENCY_IN_SEC_AS_NORMAL;
    }
    [super onEnter];
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
            [self incrementMissCount];
            [self showMissLabelAt:removedRingo.position];
            [self removeChild:removedRingo cleanup:YES];
        }
    }
}

- (void)checkMovingElementsPosition:(ccTime)delta {
    float kagoY = self.kago.contentSize.height;
    
    NSMutableArray* removingElements = [NSMutableArray array];
    
    for (CCSprite* element in self.movingElements) {
        
        //バスケットに入ったelementを確認
        if (element.position.y < kagoY) {
            float x = element.position.x;
            if (KAGO_EDGE_LEFT_X < x && x < KAGO_EDGE_RIGHT_X) {
                if ([element isKindOfClass:[Ringo class]]) {
                    CCLOG(@"Get Ringo! %@", element);
                    _score++;
                    [self updateScoreLabel];
                    [self showGetLabelAt:element.position];
                    [self removeChild:element cleanup:YES];
                    [removingElements addObject:element];
                } else {
                    CCLOG(@"Miss! (get enemy :%@)", element);
                    [self incrementMissCount];
                    [self showMissLabelAt:element.position];
                }
                [removingElements addObject:element];
            }
        }
    }
    [self.movingElements removeObjectsInArray:removingElements];
}

#pragma mark GameLogics

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
    
    //ミス回数リセット
    _missCount = 0;
    [self updateMissCountLabel];
    
    //ゲームオーバーフラグリセット
    _gameover = NO;
}

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
        float topEdgePos = size.height;
        float bottomEdgePos = 0;
        float rightEdgePos = size.width;
        float leftEdgePos = 0;
        
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
                                     size.width + 1,
                                     size.height + 1);
        CGPoint dist;
        
        float deltaX = endPoint.x - startPoint.x;
        float deltaY = endPoint.y - startPoint.y;
        if (deltaX < 0) {
            if (deltaY < 0) {
                CCLOG(@"左下");
                dist = CGRectContainsPoint(winFrame, leftPt) ? leftPt : bottomPt;
            } else {
                CCLOG(@"左上");
                dist = CGRectContainsPoint(winFrame, leftPt) ? leftPt : topPt;
            }
        } else {
            if (deltaY < 0) {
                CCLOG(@"右下");
                dist = CGRectContainsPoint(winFrame, rightPt) ? rightPt : bottomPt;
            } else {
                CCLOG(@"右上, %d",CGRectContainsPoint(winFrame, rightPt));
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
            //リンゴを枠外に飛ばした場合はmiss++
            if ([targetElement isKindOfClass:[Ringo class]]) {
                [self incrementMissCount];
                [self showMissLabelAt:targetElement.position];
            }
            //枠外に飛んだelementを削除
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
                float h = sprite.contentSize.height * 1.2; //ちょっと大きめに
                float w = sprite.contentSize.width * 1.2; //ちょっと大きめに
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

//一定周期毎にリンゴor害虫を産み出す
#warning 生み出すときにいい感じのエフェクト
- (void)spawnElement:(ccTime)delta {
    spawnElementElapsed += delta;
    if (spawnElementElapsed > _elementSpawnFrequencyInSec) {
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
            
            //ムシを放置しておくとカゴに勝手に入ってきてミス
            CCDelayTime* delay = [CCDelayTime actionWithDuration:WARM_WAIT_IN_SEC];
            CCCallBlock* block = [CCCallBlock actionWithBlock:^{
                [self fallToBasket:(Enemy*)element];
            }];
            [element runAction:[CCSequence actions:delay, block, nil]];
            
        } else {
            //4種類のリンゴからランダム選出
            int ringoType = CCRANDOM_0_1() * 4;
            element = [Ringo spriteWithFile:@"characters.png" rect:ringos[ringoType]];
            
            //リンゴを放置しておくとトリが食いに来る
            CCDelayTime* delayTimeAction = [CCDelayTime actionWithDuration:BIRD_FLY_WAITTIME_IN_SEC];
            CCCallBlock* birdAction = [CCCallBlock actionWithBlock:^{
                CCLOG(@"bird!!!");
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

- (void)incrementMissCount {
    _missCount++;
    [self updateMissCountLabel];
    
    if (_missCount >= MAX_MISS_COUNT) {
        [self gameover];
    }
}

- (void)gameover {
    if (_gameover == NO) {
        [self showGameoverDialog];
        _gameover = YES;
    }
}

//warmがしばらく震えて、バスケットに向かって移動（=>ゲームオーバー）
- (void)fallToBasket:(Enemy*)warm {
    CGPoint orgPos = warm.position;

    [warm runAction:[CCSequence actions:
                     [CCRepeat actionWithAction:
                      [CCSequence actions:
                       [CCMoveTo actionWithDuration:0.1 position:ccp(orgPos.x + 5, orgPos.y)],
                       [CCMoveTo actionWithDuration:0.1 position:ccp(orgPos.x - 5, orgPos.y)],
                       nil
                       ] times:5],
                     [CCMoveTo actionWithDuration:0.5 position:self.kago.position],
                     nil]
     ];
    [self.movingElements addObject:warm];
}

#pragma mark show UI efect/response

- (void)showGameoverDialog {
    NSString* message = self.scoreLabel.string;
    
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
    [self showPopupLabelAt:position label:@"Get!!!" color:ccGREEN];
}

- (void)showMissLabelAt:(CGPoint)position {
#warning 欄外リンゴはみ出し時に調整
    [self showPopupLabelAt:position label:@"Miss!!!" color:ccYELLOW];
}

- (void)showPopupLabelAt:(CGPoint)position label:(NSString*)label color:(ccColor3B)color {
    CCLabelTTF* getLabel = [CCLabelTTF labelWithString:label fontName:@"Marker Felt" fontSize:28];
    getLabel.color = color;
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

- (void)updateScoreLabel {
    self.scoreLabel.string = [NSString stringWithFormat:@"Score:%d", _score];
}

- (void)updateMissCountLabel {
    if (_missCount >= MAX_MISS_COUNT) {
        self.missLabel.color = ccRED;
    }
    self.missLabel.string = [NSString stringWithFormat:@"Miss:%d", _missCount];
}



@end
