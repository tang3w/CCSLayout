// CCSLayout.m
//
// Copyright (c) 2014 Tianyong Tang
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
// KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE
// AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

#import "CCSLayout.h"
#import "CCSLayoutParser.h"
#import "CCNode_Private.h"

#import <objc/runtime.h>

#define CCS_STREQ(a, b) (strcmp(a, b) == 0)

@class CCSLayoutRule;

typedef CGFloat(^CCSFloatBlock)(CCNode *);
typedef CGFloat(^CCSCoordBlock)(CCSLayoutRule *);

typedef NS_ENUM(NSInteger, CCSLayoutDir) {
    CCSLayoutDirv = 1,
    CCSLayoutDirh
};

static const void *CCSLayoutKey = &CCSLayoutKey;

static NSMutableSet *swizzledLayoutClasses = nil;

static NSString *CCSLayoutCycleExceptionName = @"CCSLayoutCycleException";
static NSString *CCSLayoutCycleExceptionDesc = @"Layout can not be solved because of cycle";

static NSString *CCSLayoutSyntaxExceptionName = @"CCSLayoutSyntaxException";
static NSString *CCSLayoutSyntaxExceptionDesc = @"Layout rule has a syntax error";


@interface CCSCoord : NSObject

+ (instancetype)nilCoord;

+ (instancetype)coordWithFloat:(CGFloat)value;
+ (instancetype)coordWithPercentage:(CGFloat)percentage;
+ (instancetype)coordWithPercentage:(CGFloat)percentage dir:(CCSLayoutDir)dir;
+ (instancetype)coordWithBlock:(CCSCoordBlock)block;

@property (nonatomic, copy) CCSCoordBlock block;

- (instancetype)add:(CCSCoord *)other;
- (instancetype)sub:(CCSCoord *)other;
- (instancetype)mul:(CCSCoord *)other;
- (instancetype)div:(CCSCoord *)other;

- (BOOL)valid;

@end


@interface CCSCoords : NSObject

+ (instancetype)coordsOfNode:(CCNode *)node;

@end


@interface CCSLayoutRule : NSObject

+ (instancetype)layoutRuleWithNode:(CCNode *)node
    name:(NSString *)name
    coord:(CCSCoord *)coord
    dir:(CCSLayoutDir)dir;

@property (nonatomic, weak) CCNode *node;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) CCSCoord *coord;
@property (nonatomic, assign) CCSLayoutDir dir;

- (CGFloat)floatValue;

- (BOOL)valid;

@end


@interface CCSLayoutRuleHub : NSObject

@property (nonatomic, readonly) NSMutableArray *vRules;
@property (nonatomic, readonly) NSMutableArray *hRules;

- (void)vAddRule:(CCSLayoutRule *)rule;
- (void)hAddRule:(CCSLayoutRule *)rule;

@end


@interface CCSLayout ()

@property (nonatomic, weak) CCNode *node;

@property (nonatomic, strong) CCSLayoutRuleHub *ruleHub;
@property (nonatomic, strong) NSMutableDictionary *ruleMap;

@property (nonatomic, strong) CCSLayoutRule *wRule;
@property (nonatomic, strong) CCSLayoutRule *hRule;

@property (nonatomic, strong) CCSCoord *w;
@property (nonatomic, strong) CCSCoord *h;

@property (nonatomic, strong) CCSCoord *minw;
@property (nonatomic, strong) CCSCoord *maxw;

@property (nonatomic, strong) CCSCoord *minh;
@property (nonatomic, strong) CCSCoord *maxh;

@property (nonatomic, strong) CCSCoord *tt;
@property (nonatomic, strong) CCSCoord *tb;

@property (nonatomic, strong) CCSCoord *ll;
@property (nonatomic, strong) CCSCoord *lr;

@property (nonatomic, strong) CCSCoord *bb;
@property (nonatomic, strong) CCSCoord *bt;

@property (nonatomic, strong) CCSCoord *rr;
@property (nonatomic, strong) CCSCoord *rl;

@property (nonatomic, strong) CCSCoord *ct;
@property (nonatomic, strong) CCSCoord *cl;
@property (nonatomic, strong) CCSCoord *cb;
@property (nonatomic, strong) CCSCoord *cr;

@property (nonatomic, assign) CGRect frame;

- (instancetype)initWithNode:(CCNode *)node;

- (void)startLayout;

@end


@interface CCSLayoutRulesSolver : NSObject

@property (nonatomic, weak) CCNode *node;

- (CGRect)solveTt:(NSArray *)rules;
- (CGRect)solveTtCt:(NSArray *)rules;
- (CGRect)solveTtBt:(NSArray *)rules;

- (CGRect)solveLl:(NSArray *)rules;
- (CGRect)solveLlCl:(NSArray *)rules;
- (CGRect)solveLlRl:(NSArray *)rules;

- (CGRect)solveBt:(NSArray *)rules;
- (CGRect)solveBtCt:(NSArray *)rules;
- (CGRect)solveBtTt:(NSArray *)rules;

- (CGRect)solveRl:(NSArray *)rules;
- (CGRect)solveRlCl:(NSArray *)rules;
- (CGRect)solveRlLl:(NSArray *)rules;

- (CGRect)solveCt:(NSArray *)rules;
- (CGRect)solveCtTt:(NSArray *)rules;
- (CGRect)solveCtBt:(NSArray *)rules;

- (CGRect)solveCl:(NSArray *)rules;
- (CGRect)solveClLl:(NSArray *)rules;
- (CGRect)solveClRl:(NSArray *)rules;

@end


@implementation CCSLayoutRule

+ (instancetype)layoutRuleWithNode:(CCNode *)node
    name:(NSString *)name
    coord:(CCSCoord *)coord
    dir:(CCSLayoutDir)dir
{
    CCSLayoutRule *rule = [[CCSLayoutRule alloc] init];

    rule.node = node;
    rule.name = name;
    rule.coord = coord;
    rule.dir = dir;

    return rule;
}

- (CGFloat)floatValue {
    return self.coord.block(self);
}

- (BOOL)valid {
    return [self.coord valid];
}

@end


@implementation CCSLayoutRuleHub

@synthesize vRules = _vRules;
@synthesize hRules = _hRules;

- (NSMutableArray *)vRules {
    return _vRules ?: (_vRules = [[NSMutableArray alloc] init]);
}

- (NSMutableArray *)hRules {
    return _hRules ?: (_hRules = [[NSMutableArray alloc] init]);
}

- (void)addRule:(CCSLayoutRule *)rule toRules:(NSMutableArray *)rules {
    [rules filterUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.name != %@", rule.name]];

    if ([rules count] > 1) [rules removeObjectAtIndex:0];

    if ([rule valid]) [rules addObject:rule];
}

- (void)vAddRule:(CCSLayoutRule *)rule {
    [self addRule:rule toRules:self.vRules];
}

- (void)hAddRule:(CCSLayoutRule *)rule {
    [self addRule:rule toRules:self.hRules];
}

@end


#define CCS_FRAME_WIDTH  (frame.size.width)
#define CCS_FRAME_HEIGHT (frame.size.height)

#define CCS_SUPERVIEW_WIDTH  (node.parent.bounds.size.width)
#define CCS_SUPERVIEW_HEIGHT (node.parent.bounds.size.height)

#define CCSLAYOUT_FRAME(node) \
    ([objc_getAssociatedObject(node, CCSLayoutKey) frame])

#define CCSLAYOUT_SOLVE_SINGLE_H(var, left)    \
do {                                           \
    CCSLayoutRule *rule = rules[0];            \
    CGFloat var = [[rule coord] block](rule);  \
    CCNode *node = _node;                      \
    CGRect frame = CCSLAYOUT_FRAME(node);      \
    frame.origin.x = (left);                   \
    return frame;                              \
} while (0)

#define CCSLAYOUT_SOLVE_SINGLE_V(var, top)     \
do {                                           \
    CCSLayoutRule *rule = rules[0];            \
    CGFloat var = [[rule coord] block](rule);  \
    CCNode *node = _node;                      \
    CGRect frame = CCSLAYOUT_FRAME(node);      \
    frame.origin.y = (top);                    \
    return frame;                              \
} while (0)

#define CCSLAYOUT_SOLVE_DOUBLE_H(var1, var2, width_, left)  \
do {                                                        \
    CCSLayoutRule *rule0 = rules[0];                        \
    CCSLayoutRule *rule1 = rules[1];                        \
    CGFloat var1 = [[rule0 coord] block](rule0);            \
    CGFloat var2 = [[rule1 coord] block](rule1);            \
    CCNode *node = _node;                                   \
    CGRect frame = CCSLAYOUT_FRAME(node);                   \
    frame.size.width = [self calcWidth:(width_)];           \
    frame.origin.x = (left);                                \
    return frame;                                           \
} while (0)

#define CCSLAYOUT_SOLVE_DOUBLE_V(var1, var2, height_, top)  \
do {                                                        \
    CCSLayoutRule *rule0 = rules[0];                        \
    CCSLayoutRule *rule1 = rules[1];                        \
    CGFloat var1 = [[rule0 coord] block](rule0);            \
    CGFloat var2 = [[rule1 coord] block](rule1);            \
    CCNode *node = _node;                                   \
    CGRect frame = CCSLAYOUT_FRAME(node);                   \
    frame.size.height = [self calcHeight:(height_)];        \
    frame.origin.y = (top);                                 \
    return frame;                                           \
} while (0)

#define CCS_MM_RAW_VALUE(layout, var)               \
({                                                  \
    CCSLayoutRule *rule = layout.ruleMap[@(#var)];  \
                                                    \
    [rule valid] ? [rule floatValue] : NAN;         \
})

#define CCS_VALID_DIM(value) (!isnan(value) && (value) >= 0)


@implementation CCSLayoutRulesSolver

- (CGFloat)calcWidth:(CGFloat)width {
    CCSLayout *layout = objc_getAssociatedObject(_node, CCSLayoutKey);

    CGFloat minw = CCS_MM_RAW_VALUE(layout, minw);

    if (CCS_VALID_DIM(minw) && width < minw) {
        width = minw;
    }

    CGFloat maxw = CCS_MM_RAW_VALUE(layout, maxw);

    if (CCS_VALID_DIM(maxw) && width > maxw) {
        width = maxw;
    }

    return MAX(width, 0);
}

- (CGFloat)calcHeight:(CGFloat)height {
    CCSLayout *layout = objc_getAssociatedObject(_node, CCSLayoutKey);

    CGFloat minh = CCS_MM_RAW_VALUE(layout, minh);

    if (CCS_VALID_DIM(minh) && height < minh) {
        height = minh;
    }

    CGFloat maxh = CCS_MM_RAW_VALUE(layout, maxh);

    if (CCS_VALID_DIM(maxh) && height > maxh) {
        height = maxh;
    }

    return MAX(height, 0);
}

- (CGRect)solveTt:(NSArray *)rules {
    CCSLAYOUT_SOLVE_SINGLE_V(top, top);
}

- (CGRect)solveTtCt:(NSArray *)rules {
    CCSLAYOUT_SOLVE_DOUBLE_V(top, axisY, (axisY - top) * 2, axisY - CCS_FRAME_HEIGHT / 2);
}

- (CGRect)solveTtBt:(NSArray *)rules {
    CCSLAYOUT_SOLVE_DOUBLE_V(top, bottom, bottom - top, bottom - CCS_FRAME_HEIGHT);
}

- (CGRect)solveLl:(NSArray *)rules {
    CCSLAYOUT_SOLVE_SINGLE_H(left, left);
}

- (CGRect)solveLlCl:(NSArray *)rules {
    CCSLAYOUT_SOLVE_DOUBLE_H(left, axisX, (axisX - left) * 2, axisX - CCS_FRAME_WIDTH / 2);
}

- (CGRect)solveLlRl:(NSArray *)rules {
    CCSLAYOUT_SOLVE_DOUBLE_H(left, right, right - left, right - CCS_FRAME_WIDTH);
}

- (CGRect)solveBt:(NSArray *)rules {
    CCSLAYOUT_SOLVE_SINGLE_V(bottom, bottom - CCS_FRAME_HEIGHT);
}

- (CGRect)solveBtCt:(NSArray *)rules {
    CCSLAYOUT_SOLVE_DOUBLE_V(bottom, axisY, (bottom - axisY) * 2, axisY - CCS_FRAME_HEIGHT / 2);
}

- (CGRect)solveBtTt:(NSArray *)rules {
    CCSLAYOUT_SOLVE_DOUBLE_V(bottom, top, bottom - top, top);
}

- (CGRect)solveRl:(NSArray *)rules {
    CCSLAYOUT_SOLVE_SINGLE_H(right, right - CCS_FRAME_WIDTH);
}

- (CGRect)solveRlCl:(NSArray *)rules {
    CCSLAYOUT_SOLVE_DOUBLE_H(right, axisX, (right - axisX) * 2, axisX - CCS_FRAME_WIDTH / 2);
}

- (CGRect)solveRlLl:(NSArray *)rules {
    CCSLAYOUT_SOLVE_DOUBLE_H(right, left, right - left, left);
}

- (CGRect)solveCt:(NSArray *)rules {
    CCSLAYOUT_SOLVE_SINGLE_V(axisY, axisY - CCS_FRAME_HEIGHT / 2);
}

- (CGRect)solveCtTt:(NSArray *)rules {
    CCSLAYOUT_SOLVE_DOUBLE_V(axisY, top, (axisY - top) * 2, top);
}

- (CGRect)solveCtBt:(NSArray *)rules {
    CCSLAYOUT_SOLVE_DOUBLE_V(axisY, bottom, (bottom - axisY) * 2, bottom - CCS_FRAME_HEIGHT);
}

- (CGRect)solveCl:(NSArray *)rules {
    CCSLAYOUT_SOLVE_SINGLE_H(axisX, axisX - CCS_FRAME_WIDTH / 2);
}

- (CGRect)solveClLl:(NSArray *)rules {
    CCSLAYOUT_SOLVE_DOUBLE_H(axisX, left, (axisX - left) * 2, left);
}

- (CGRect)solveClRl:(NSArray *)rules {
    CCSLAYOUT_SOLVE_DOUBLE_H(axisX, right, (right - axisX) * 2, right - CCS_FRAME_WIDTH);
}

@end


#define CCSCOORD_MAKE(expr)                        \
({                                                 \
    __weak CCNode *__node = _node;                 \
                                                   \
    CCSCoord *coord = [[CCSCoord alloc] init];     \
                                                   \
    coord.block = ^CGFloat(CCSLayoutRule *rule) {  \
        CCNode *node = __node;                     \
                                                   \
        return (expr);                             \
    };                                             \
                                                   \
    coord;                                         \
})

#define CCSCOORD_OR_NIL(c_) ({ CCSCoord *c = (c_); [c valid] ? c : nil; })

#define CCSLAYOUT_ADD_RULE(var, dir_)        \
do {                                         \
    _##var = CCSCOORD_OR_NIL(var);           \
                                             \
    CCSLayoutRule *rule =                    \
    [CCSLayoutRule layoutRuleWithNode:_node  \
        name:@(#var)                         \
        coord:_##var                         \
        dir:CCSLayoutDir##dir_];             \
                                             \
    [self.ruleHub dir_##AddRule:rule];       \
} while (0)

#define CCSLAYOUT_ADD_TRANS_RULE(var, dst, exp)   \
do {                                              \
    CCSCoord *c = _##var = CCSCOORD_OR_NIL(var);  \
    self.dst = c ? CCSCOORD_MAKE((exp)) : nil;    \
} while (0)

#define CCSLAYOUT_ADD_BOUND_RULE(var, dir_)  \
do {                                         \
    _##var = CCSCOORD_OR_NIL(var);           \
    NSString *name = @(#var);                \
                                             \
    CCSLayoutRule *rule =                    \
    [CCSLayoutRule layoutRuleWithNode:_node  \
        name:name                            \
        coord:_##var                         \
        dir:CCSLayoutDir##dir_];             \
                                             \
    self.ruleMap[name] = rule;               \
} while (0)

NS_INLINE
void ccs_swizzle_set_parent(CCNode *node) {
    Class class = [node class];

    SEL name = @selector(setParent:);

    IMP origImp = class_getMethodImplementation(class, name);
    IMP overImp = imp_implementationWithBlock(^(CCNode *node, CCNode *parent) {
        ((void(*)(id, SEL, id))(origImp))(node, name, parent);

        CCSLayout *layout = objc_getAssociatedObject(node, CCSLayoutKey);

        if (layout) [layout startLayout];
    });

    class_replaceMethod(class, name, overImp, "v@:@");
}

NS_INLINE
void ccs_swizzle_content_size_changed(CCNode *node) {
    Class class = [node class];

    SEL name = @selector(contentSizeChanged);

    IMP origImp = class_getMethodImplementation(class, name);
    IMP overImp = imp_implementationWithBlock(^(CCNode *node) {
        ((void(*)(id, SEL))(origImp))(node, name);

        CCSLayout *layout = objc_getAssociatedObject(node, CCSLayoutKey);

        if (layout) [layout startLayout];
    });

    class_replaceMethod(class, name, overImp, "v@:");
}

NS_INLINE
void ccs_initialize_layout_if_needed(CCNode *node) {
    Class class = [node class];

    if ([swizzledLayoutClasses containsObject:class]) return;

    ccs_swizzle_set_parent(node);
    ccs_swizzle_content_size_changed(node);

    [swizzledLayoutClasses addObject:class];
}


@protocol CCSLayoutArguments <NSObject>

- (CGFloat)floatValue;
- (CCSFloatBlock)floatBlockValue;
- (id)objectValue;

@end


@interface CCSLayoutVaList : NSObject <CCSLayoutArguments>

- (instancetype)initWithVaList:(va_list)valist;

@end


@implementation CCSLayoutVaList {
    va_list _valist;
}

- (instancetype)initWithVaList:(va_list)valist {
    self = [super init];

    if (self) {
        va_copy(_valist, valist);
    }

    return self;
}

- (CGFloat)floatValue {
    return va_arg(_valist, double);
}

- (CCSFloatBlock)floatBlockValue {
    return va_arg(_valist, CCSFloatBlock);
}

- (id)objectValue {
    return va_arg(_valist, id);
}

- (void)dealloc {
    va_end(_valist);
}

@end


@interface CCSLayoutArrayArguments : NSObject <CCSLayoutArguments>

- (instancetype)initWithArray:(NSArray *)array;

@end


@implementation CCSLayoutArrayArguments {
    NSMutableArray *_array;
}

- (instancetype)initWithArray:(NSArray *)array {
    self = [super init];

    if (self) {
        _array = [array mutableCopy];
    }

    return self;
}

- (id)shiftArgument {
    id argument = [_array firstObject];

    [_array removeObjectAtIndex:0];

    return argument;
}

- (CGFloat)floatValue {
    return (CGFloat)[[self shiftArgument] doubleValue];
}

- (CCSFloatBlock)floatBlockValue {
    return [self shiftArgument];
}

- (id)objectValue {
    return [self shiftArgument];
}

@end


@interface CCNode (CCSLayoutGeometry)

@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) CGRect bounds;

@end


@implementation CCNode (CCSLayoutGeometry)

- (CGRect)frame {
    return (CGRect){self.positionInPoints, self.bounds.size};
}

- (void)setFrame:(CGRect)frame {
    self.positionInPoints = frame.origin;
    self.contentSizeInPoints = frame.size;
}

- (CGRect)bounds {
    return [self boundingBox];
}

- (void)setBounds:(CGRect)bounds {
    self.contentSizeInPoints = bounds.size;
}

@end


#define CCS_STRING(coord) \
    [NSString stringWithCString:(coord) encoding:NSASCIIStringEncoding]


@implementation CCSLayout

+ (void)initialize {
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        swizzledLayoutClasses = [[NSMutableSet alloc] init];
    });
}

+ (instancetype)layoutOfNode:(CCNode *)node {
    if (![node isKindOfClass:[CCNode class]]) return nil;

    CCSLayout *layout = objc_getAssociatedObject(node, CCSLayoutKey);

    if (!layout) {
        layout = [[CCSLayout alloc] initWithNode:node];

        objc_setAssociatedObject(node, CCSLayoutKey, layout, OBJC_ASSOCIATION_RETAIN);

        ccs_initialize_layout_if_needed(node);
    }

    return layout;
}

- (instancetype)initWithNode:(CCNode *)node {
    self = [super init];

    if (self) {
        _node = node;
        _node.anchorPoint = CGPointMake(0, 0);
    }

    return self;
}

- (void)addRule:(NSString *)format, ... {
    va_list argv;
    va_start(argv, format);

    [self addRule:format args:argv];

    va_end(argv);
}

- (void)addRule:(NSString *)format args:(va_list)args {
    CCSLayoutVaList *valist = [[CCSLayoutVaList alloc] initWithVaList:args];

    [self addRule:format _args:valist];
}

- (void)addRule:(NSString *)format arguments:(NSArray *)arguments {
    CCSLayoutArrayArguments *array = [[CCSLayoutArrayArguments alloc] initWithArray:arguments];

    [self addRule:format _args:array];
}

- (void)addRule:(NSString *)format _args:(id<CCSLayoutArguments>)args {
    NSArray *subRules = [format componentsSeparatedByString:@","];

    for (NSString *subRule in subRules) {
        CCSLAYOUT_AST *ast = NULL;

        char *expr = (char *)[subRule cStringUsingEncoding:NSASCIIStringEncoding];

        int result = ccslayout_parse_rule(expr, &ast);

        switch (result) {
        case 0: {
            NSMutableSet *keeper = [NSMutableSet set];

            [self parseAst:ast parent:NULL args:args keeper:keeper];

            ccslayout_destroy_ast(ast);
        }
            break;

        case 1: {
            [NSException raise:CCSLayoutSyntaxExceptionName format:@"%@", CCSLayoutSyntaxExceptionDesc];
        }
            break;

        default:
            return;
        }
    }

    [self startLayout];
}

#define CCSCOORD_FOR_NAME(name_) ({  \
    [self valueForKey:name_] ?: ({   \
        CCSCoord *coord = [CCSCoord coordWithFloat:0];  \
        [keeper addObject:coord];    \
        coord;                       \
    });                              \
})

- (void)parseAst:(CCSLAYOUT_AST *)ast parent:(CCSLAYOUT_AST *)parent args:(id<CCSLayoutArguments>)args keeper:(NSMutableSet *)keeper {
    if (ast == NULL) return;

    [self parseAst:ast->l parent:ast args:args keeper:keeper];
    [self parseAst:ast->r parent:ast args:args keeper:keeper];

    switch (ast->node_type) {
    case CCSLAYOUT_TOKEN_ATTR: {
        if (parent) {
            if (parent->node_type == '=' &&
                parent->l == ast) break;

            CCSCoord *coord = CCSCOORD_FOR_NAME(CCS_STRING(ast->value.coord));

            ast->data = (__bridge void *)(coord);
        } else {
            [self setValue:[CCSCoord coordWithFloat:0] forKey:CCS_STRING(ast->value.coord)];
        }
    }
        break;

    case CCSLAYOUT_TOKEN_NUMBER: {
        CCSCoord *coord = [CCSCoord coordWithFloat:ast->value.number];

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;

    case CCSLAYOUT_TOKEN_PERCENTAGE:
    case CCSLAYOUT_TOKEN_PERCENTAGE_H:
    case CCSLAYOUT_TOKEN_PERCENTAGE_V: {
        CCSLayoutDir dir = 0;

        switch (ast->node_type) {
        case CCSLAYOUT_TOKEN_PERCENTAGE_H: dir = CCSLayoutDirh; break;
        case CCSLAYOUT_TOKEN_PERCENTAGE_V: dir = CCSLayoutDirv; break;
        }

        CCSCoord *coord = [CCSCoord coordWithPercentage:ast->value.percentage dir:dir];

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;

    case CCSLAYOUT_TOKEN_COORD: {
        CCSCoord *coord = nil;
        char *spec = ast->value.coord;

        switch (spec[0]) {
        case '^': {
            CCSFloatBlock block = [args floatBlockValue];

            coord = [CCSCoord coordWithBlock:^CGFloat(CCSLayoutRule *rule) {
                return block(rule.node);
            }];
        }
            break;

        case '@': {
            id<CCSCGFloatProtocol> value = [args objectValue];

            coord = [CCSCoord coordWithBlock:^CGFloat(CCSLayoutRule *rule) {
                return [value ccs_CGFloatValue];
            }];
        }
            break;

        default: {
            switch (spec[0]) {
            case 'f':
                coord = [CCSCoord coordWithFloat:[args floatValue]];
                break;

            default: {
                CCSCoords *coords = [CCSCoords coordsOfNode:[args objectValue]];
                coord = [coords valueForKey:CCS_STRING(spec)];
            }
                break;
            }
        }
            break;
        }

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;

    case CCSLAYOUT_TOKEN_COORD_PERCENTAGE:
    case CCSLAYOUT_TOKEN_COORD_PERCENTAGE_H:
    case CCSLAYOUT_TOKEN_COORD_PERCENTAGE_V: {
        CCSCoord *coord = nil;
        char *spec = ast->value.coord;

        CCSLayoutDir dir = 0;

        switch (ast->node_type) {
        case CCSLAYOUT_TOKEN_COORD_PERCENTAGE_H: dir = CCSLayoutDirh; break;
        case CCSLAYOUT_TOKEN_COORD_PERCENTAGE_V: dir = CCSLayoutDirv; break;
        }

        switch (spec[0]) {
        case '^':{
            CCSFloatBlock block = [args floatBlockValue];

            coord = [CCSCoord coordWithBlock:^CGFloat(CCSLayoutRule *rule) {
                CGFloat percentage = block(rule.node);
                CCSCoord *coord = [CCSCoord coordWithPercentage:percentage dir:dir];

                return coord.block(rule);
            }];
        }
            break;

        case '@': {
            id<CCSCGFloatProtocol> object = [args objectValue];

            coord = [CCSCoord coordWithBlock:^CGFloat(CCSLayoutRule *rule) {
                CGFloat percentage = [object ccs_CGFloatValue];
                CCSCoord *coord = [CCSCoord coordWithPercentage:percentage dir:dir];

                return coord.block(rule);
            }];
        }
            break;

        default:
            coord = [CCSCoord coordWithPercentage:[args floatValue] dir:dir];
            break;
        }

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;

    case CCSLAYOUT_TOKEN_NIL: {
        ast->data = (__bridge void *)([CCSCoord nilCoord]);
    }
        break;

    case '+': {
        CCSCoord *coord1 = (__bridge CCSCoord *)(ast->l->data);
        CCSCoord *coord2 = (__bridge CCSCoord *)(ast->r->data);

        CCSCoord *coord = [coord1 add:coord2];

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;

    case '-': {
        CCSCoord *coord1 = (__bridge CCSCoord *)(ast->l->data);
        CCSCoord *coord2 = (__bridge CCSCoord *)(ast->r->data);

        CCSCoord *coord = [coord1 sub:coord2];

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;

    case '*': {
        CCSCoord *coord1 = (__bridge CCSCoord *)(ast->l->data);
        CCSCoord *coord2 = (__bridge CCSCoord *)(ast->r->data);

        CCSCoord *coord = [coord1 mul:coord2];

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;

    case '/': {
        CCSCoord *coord1 = (__bridge CCSCoord *)(ast->l->data);
        CCSCoord *coord2 = (__bridge CCSCoord *)(ast->r->data);

        CCSCoord *coord = [coord1 div:coord2];

        ast->data = (__bridge void *)(coord);

        [keeper addObject:coord];
    }
        break;

    case '=': {
        CCSCoord *coord = (__bridge CCSCoord *)(ast->r->data);

        [self setValue:coord forKey:CCS_STRING(ast->l->value.coord)];

        ast->data = (__bridge void *)(coord);
    }
        break;

    case CCSLAYOUT_TOKEN_ADD_ASSIGN:
    case CCSLAYOUT_TOKEN_SUB_ASSIGN:
    case CCSLAYOUT_TOKEN_MUL_ASSIGN:
    case CCSLAYOUT_TOKEN_DIV_ASSIGN: {
        NSString *name = CCS_STRING(ast->l->value.coord);

        CCSCoord *lval  = CCSCOORD_FOR_NAME(name);
        CCSCoord *rval = (__bridge CCSCoord *)(ast->r->data);

        SEL sel = NULL;

        switch (ast->node_type) {
        case CCSLAYOUT_TOKEN_ADD_ASSIGN: sel = @selector(add:); break;
        case CCSLAYOUT_TOKEN_SUB_ASSIGN: sel = @selector(sub:); break;
        case CCSLAYOUT_TOKEN_MUL_ASSIGN: sel = @selector(mul:); break;
        case CCSLAYOUT_TOKEN_DIV_ASSIGN: sel = @selector(div:); break;
        }

        IMP imp = [lval methodForSelector:sel];

        CCSCoord *coord = ((id(*)(id, SEL, id))(imp))(lval, sel, rval);

        [self setValue:coord forKey:name];

        ast->data = (__bridge void *)(coord);
    }
        break;

    default:
        break;
    }
}

- (void)setValue:(id)value forKey:(NSString *)key {
    @try {
        [super setValue:value forKey:key];
    } @catch (NSException *exception) {
        fprintf(stderr, "CCSLayout: Invalid constraint \"%s\", ignored.\n", [key UTF8String]);
    }
}

- (void)solveRules:(NSArray *)rules {
    CCSLayoutRulesSolver *solver = [[CCSLayoutRulesSolver alloc] init];

    solver.node = _node;

    NSMutableString *selStr = [NSMutableString stringWithString:@"solve"];

    for (CCSLayoutRule *rule in rules) {
        [selStr appendString:[rule.name capitalizedString]];
    }

    [selStr appendString:@":"];

    SEL sel = NSSelectorFromString(selStr);
    CGRect (*imp)(id, SEL, NSArray *) = (void *)[solver methodForSelector:sel];

    _frame = imp(solver, sel, rules);

    [self checkBounds];
}

- (void)checkBounds {
    CGSize size = _frame.size;

    CGFloat minw = CCS_MM_RAW_VALUE(self, minw);

    if (CCS_VALID_DIM(minw) && size.width < minw) {
        size.width = minw;
    }

    CGFloat maxw = CCS_MM_RAW_VALUE(self, maxw);

    if (CCS_VALID_DIM(maxw) && size.width > maxw) {
        size.width = maxw;
    }

    CGFloat minh = CCS_MM_RAW_VALUE(self, minh);

    if (CCS_VALID_DIM(minh) && size.height < minh) {
        size.height = minh;
    }

    CGFloat maxh = CCS_MM_RAW_VALUE(self, maxh);

    if (CCS_VALID_DIM(maxh) && size.height > maxh) {
        size.height = maxh;
    }

    _frame.size = size;
}

- (void)startLayout {
    _frame = _node.frame;

    [self checkBounds];

    NSUInteger hRuleCount = [_ruleHub.hRules count];
    NSUInteger vRuleCount = [_ruleHub.vRules count];

    if (self.wRule && hRuleCount < 2) {
        _frame.size.width = [self.wRule floatValue];
    }

    if (self.hRule && vRuleCount < 2) {
        _frame.size.height = [self.hRule floatValue];
    }

    if (hRuleCount > 0) {
        [self solveRules:_ruleHub.hRules];
    }

    if (vRuleCount > 0) {
        [self solveRules:_ruleHub.vRules];
    }

    [self checkBounds];

    if (!CGRectEqualToRect(_frame, _node.frame)) {
        _node.frame = _frame;
    }

    [self layoutChildren];
}

- (void)layoutChildren {
    for (CCNode *child in self.node.children) {
        CCSLayout *layout = objc_getAssociatedObject(child, CCSLayoutKey);

        if (layout) {
            [layout startLayout];
        }
    }
}

- (void)setW:(CCSCoord *)w {
    _w = w;
    self.wRule = [CCSLayoutRule layoutRuleWithNode:_node name:nil coord:w dir:CCSLayoutDirh];
}

- (void)setH:(CCSCoord *)h {
    _h = h;
    self.hRule = [CCSLayoutRule layoutRuleWithNode:_node name:nil coord:h dir:CCSLayoutDirv];
}

- (void)setMinw:(CCSCoord *)minw {
    CCSLAYOUT_ADD_BOUND_RULE(minw, h);
}

- (void)setMaxw:(CCSCoord *)maxw {
    CCSLAYOUT_ADD_BOUND_RULE(maxw, h);
}

- (void)setMinh:(CCSCoord *)minh {
    CCSLAYOUT_ADD_BOUND_RULE(minh, v);
}

- (void)setMaxh:(CCSCoord *)maxh {
    CCSLAYOUT_ADD_BOUND_RULE(maxh, v);
}

- (void)setTt:(CCSCoord *)tt {
    CCSLAYOUT_ADD_RULE(tt, v);
}

- (void)setTb:(CCSCoord *)tb {
    CCSLAYOUT_ADD_TRANS_RULE(tb, tt, CCS_SUPERVIEW_HEIGHT - tb.block(rule));
}

- (void)setLl:(CCSCoord *)ll {
    CCSLAYOUT_ADD_RULE(ll, h);
}

- (void)setLr:(CCSCoord *)lr {
    CCSLAYOUT_ADD_TRANS_RULE(lr, ll, CCS_SUPERVIEW_WIDTH - lr.block(rule));
}

- (void)setBb:(CCSCoord *)bb {
    CCSLAYOUT_ADD_TRANS_RULE(bb, bt, CCS_SUPERVIEW_HEIGHT - bb.block(rule));
}

- (void)setBt:(CCSCoord *)bt {
    CCSLAYOUT_ADD_RULE(bt, v);
}

- (void)setRr:(CCSCoord *)rr {
    CCSLAYOUT_ADD_TRANS_RULE(rr, rl, CCS_SUPERVIEW_WIDTH - rr.block(rule));
}

- (void)setRl:(CCSCoord *)rl {
    CCSLAYOUT_ADD_RULE(rl, h);
}

- (void)setCt:(CCSCoord *)ct {
    CCSLAYOUT_ADD_RULE(ct, v);
}

- (void)setCl:(CCSCoord *)cl {
    CCSLAYOUT_ADD_RULE(cl, h);
}

- (void)setCb:(CCSCoord *)cb {
    CCSLAYOUT_ADD_TRANS_RULE(cb, ct, CCS_SUPERVIEW_HEIGHT - cb.block(rule));
}

- (void)setCr:(CCSCoord *)cr {
    CCSLAYOUT_ADD_TRANS_RULE(cr, cl, CCS_SUPERVIEW_WIDTH - cr.block(rule));
}

- (CCSLayoutRuleHub *)ruleHub {
    return (_ruleHub ?: (_ruleHub = [[CCSLayoutRuleHub alloc] init]));
}

- (NSMutableDictionary *)ruleMap {
    return (_ruleMap ?: (_ruleMap = [[NSMutableDictionary alloc] init]));
}

@end


#define CCSCOORD_CALC(expr)                              \
do {                                                     \
    if ([self valid] && [other valid]) {                 \
        CCSCoord *coord = [[CCSCoord alloc] init];       \
                                                         \
        coord.block = ^CGFloat(CCSLayoutRule *rule) {    \
            return (expr);                               \
        };                                               \
                                                         \
        return coord;                                    \
    } else if ([self valid] && ![other valid]) {         \
        return self;                                     \
    } else if (![self valid] && [other valid]) {         \
        return other;                                    \
    } else {                                             \
        return self;                                     \
    }                                                    \
} while (0)


@implementation CCSCoord

+ (instancetype)nilCoord {
    static CCSCoord *nilCoord = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        nilCoord = [[CCSCoord alloc] init];
    });

    return nilCoord;
}

+ (instancetype)coordWithFloat:(CGFloat)value {
    CCSCoord *coord = [[CCSCoord alloc] init];

    coord.block = ^CGFloat(CCSLayoutRule *rule) {
        return value;
    };

    return coord;
}

+ (instancetype)coordWithPercentage:(CGFloat)percentage {
    return [self coordWithPercentage:percentage dir:0];
}

+ (instancetype)coordWithPercentage:(CGFloat)percentage dir:(CCSLayoutDir)dir_ {
    CCSCoord *coord = [[CCSCoord alloc] init];

    percentage /= 100.0;

    coord.block = ^CGFloat(CCSLayoutRule *rule) {
        CCNode *node = rule.node;

        CCSLayoutDir dir = dir_ ? dir_ : rule.dir;
        CGFloat size = (dir == CCSLayoutDirv ? CCS_SUPERVIEW_HEIGHT : CCS_SUPERVIEW_WIDTH);

        return size * percentage;
    };

    return coord;
}

+ (instancetype)coordWithBlock:(CCSCoordBlock)block {
    CCSCoord *coord = [[CCSCoord alloc] init];

    coord.block = block;

    return coord;
}

- (instancetype)add:(CCSCoord *)other {
    CCSCOORD_CALC(self.block(rule) + other.block(rule));
}

- (instancetype)sub:(CCSCoord *)other {
    CCSCOORD_CALC(self.block(rule) - other.block(rule));
}

- (instancetype)mul:(CCSCoord *)other {
    CCSCOORD_CALC(self.block(rule) * other.block(rule));
}

- (instancetype)div:(CCSCoord *)other {
    CCSCOORD_CALC(self.block(rule) / other.block(rule));
}

- (BOOL)valid {
    return self != [CCSCoord nilCoord] && self.block;
}

@end


@interface CCSCoords ()

@property (nonatomic, weak) CCNode *node;

@property (nonatomic, strong) CCSCoord *w;
@property (nonatomic, strong) CCSCoord *h;

@property (nonatomic, strong) CCSCoord *tt;
@property (nonatomic, strong) CCSCoord *tb;

@property (nonatomic, strong) CCSCoord *ll;
@property (nonatomic, strong) CCSCoord *lr;

@property (nonatomic, strong) CCSCoord *bb;
@property (nonatomic, strong) CCSCoord *bt;

@property (nonatomic, strong) CCSCoord *rr;
@property (nonatomic, strong) CCSCoord *rl;

@property (nonatomic, strong) CCSCoord *ct;
@property (nonatomic, strong) CCSCoord *cl;
@property (nonatomic, strong) CCSCoord *cb;
@property (nonatomic, strong) CCSCoord *cr;

- (instancetype)initWithNode:(CCNode *)node;

@end


#define CCS_VIEW_TOP    (node.frame.origin.y)
#define CCS_VIEW_LEFT   (node.frame.origin.x)
#define CCS_VIEW_WIDTH  (node.bounds.size.width)
#define CCS_VIEW_HEIGHT (node.bounds.size.height)

#define LAZY_LOAD_COORD(ivar, expr) \
    (ivar ?: (ivar = CCSCOORD_MAKE(expr)))


@implementation CCSCoords

+ (instancetype)coordsOfNode:(CCNode *)node {
    static const void *coordsKey = &coordsKey;

    if (![node isKindOfClass:[CCNode class]]) {
        return nil;
    }

    CCSCoords *coords = objc_getAssociatedObject(node, coordsKey);

    if (!coords) {
        coords = [[CCSCoords alloc] initWithNode:node];

        objc_setAssociatedObject(node, coordsKey, coords, OBJC_ASSOCIATION_RETAIN);
    }

    return coords;
}

- (instancetype)initWithNode:(CCNode *)node {
    self = [super init];

    if (self) {
        _node = node;
    }

    return self;
}

- (CCSCoord *)tt {
    return LAZY_LOAD_COORD(_tt, CCS_VIEW_TOP);
}

- (CCSCoord *)tb {
    return LAZY_LOAD_COORD(_tb, CCS_SUPERVIEW_HEIGHT - CCS_VIEW_TOP);
}

- (CCSCoord *)ll {
    return LAZY_LOAD_COORD(_ll, CCS_VIEW_LEFT);
}

- (CCSCoord *)lr {
    return LAZY_LOAD_COORD(_lr, CCS_SUPERVIEW_WIDTH - CCS_VIEW_LEFT);
}

- (CCSCoord *)bb {
    return LAZY_LOAD_COORD(_bb, CCS_SUPERVIEW_HEIGHT - CCS_VIEW_TOP - CCS_VIEW_HEIGHT);
}

- (CCSCoord *)bt {
    return LAZY_LOAD_COORD(_bt, CCS_VIEW_TOP + CCS_VIEW_HEIGHT);
}

- (CCSCoord *)rr {
    return LAZY_LOAD_COORD(_rr, CCS_SUPERVIEW_WIDTH - CCS_VIEW_LEFT - CCS_VIEW_WIDTH);
}

- (CCSCoord *)rl {
    return LAZY_LOAD_COORD(_rl, CCS_VIEW_LEFT + CCS_VIEW_WIDTH);
}

- (CCSCoord *)ct {
    return LAZY_LOAD_COORD(_ct, CCS_VIEW_TOP + CCS_VIEW_HEIGHT / 2);
}

- (CCSCoord *)cl {
    return LAZY_LOAD_COORD(_cl, CCS_VIEW_LEFT + CCS_VIEW_WIDTH / 2);
}

- (CCSCoord *)cb {
    return LAZY_LOAD_COORD(_cb, CCS_SUPERVIEW_HEIGHT - CCS_VIEW_TOP - CCS_VIEW_HEIGHT / 2);
}

- (CCSCoord *)cr {
    return LAZY_LOAD_COORD(_cr, CCS_SUPERVIEW_WIDTH - CCS_VIEW_LEFT - CCS_VIEW_WIDTH / 2);
}

- (CCSCoord *)w {
    return LAZY_LOAD_COORD(_w, CCS_VIEW_WIDTH);
}

- (CCSCoord *)h {
    return LAZY_LOAD_COORD(_h, CCS_VIEW_HEIGHT);
}

@end


@implementation CCNode (CCSLayout)

- (CCSLayout *)ccslayout {
    return [CCSLayout layoutOfNode:self];
}

@end
