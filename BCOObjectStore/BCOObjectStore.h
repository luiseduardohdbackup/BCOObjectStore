//
//  BCOObjectStore.h
//  BCOObjectStore
//
//  Created by Benedict Cohen on 13/10/2014.
//  Copyright (c) 2014 Benedict Cohen. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface BCOObjectStore : NSObject

-(instancetype)initWithObjects:(NSSet *)objects indexDescriptions:(NSDictionary *)indexDescriptions __attribute__((objc_designated_initializer));

@property(readonly) NSSet *objects;
-(NSSet *)objectsForKeys:(NSArray *)keys inIndexNamed:(NSString *)indexName;

@property(readonly) NSDictionary *indexDescriptions;

@end
