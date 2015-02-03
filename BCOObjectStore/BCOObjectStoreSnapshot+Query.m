//
//  BCOObjectStoreSnapshot+Query.m
//  BCOObjectStore
//
//  Created by Benedict Cohen on 23/01/2015.
//
//

#import "BCOObjectStoreSnapshot+Query.h"
#import "BCOColumn.h"
#import "BCOQuery.h"
#import "BCOObjectStorageContainer.h"
#import "BCOIndekz.h"
#import "BCOQueryResultGroup.h"



@implementation BCOObjectStoreSnapshot (Query)

-(NSArray *)executeQuery:(NSString *)queryString subsitutionVariable:(NSDictionary *)subsitutionVariable objectStorage:(BCOObjectStorageContainer *)storage indekz:(BCOIndekz *)indekz
{
    //Create the query
    BCOQuery *query = [BCOQuery queryFromString:queryString substitutionVariables:subsitutionVariable];

    //Match the objects (WHERE)
    NSSet *matchedRecords = [self evaluateWHEREClauseExpression:query.rootWhereExpression storage:storage indekz:indekz searchSpace:nil];

    //Convert the records to objects
    NSMutableArray *objects = [NSMutableArray new];
    for (BCOStorageRecord *record in matchedRecords) {
        id object = [storage objectForStorageRecord:record];
        [objects addObject:object];
    }

    //Create the SELECT block
    NSString *key = query.selectField;
    NSArray *(^selectBlock)(NSArray *) = (key == nil) ? NULL : ^(NSArray *objects){
        NSMutableArray *results = [NSMutableArray new];
        for (id object in objects) {
            id result = [object valueForKey:key];
            NSParameterAssert(result);
            [results addObject:result];
        }
        return results;
    };

    //Create ORDERed GROUPs
    return [BCOQueryResultGroup queryResultsWithObjects:objects groupByField:query.groupBy sortDescriptors:query.sortDescriptors selectBlock:selectBlock];
}



#pragma mark - Object fetching
-(NSSet *)evaluateWHEREClauseExpression:(BCOWhereClauseExpression *)expression storage:(BCOObjectStorageContainer *)storage indekz:(BCOIndekz *)indekz searchSpace:(NSSet *)searchSpace
{
    switch (expression.operator) {

        case BCOQueryOperatorAND: {
            NSSet *leftSet = [self evaluateWHEREClauseExpression:expression.leftOperand storage:storage indekz:indekz searchSpace:searchSpace];

            //Optimizations
            BOOL isRightBranchRedundant = (leftSet.count == 0);
            if (isRightBranchRedundant)return [NSSet set];
            //TODO: What other optimizations are there?

            //Not that we're restricting the search space to leftSet. Only predicate uses this but that is potential very useful as predicates would otherwise have to scan ALL objects.
            NSSet *rightSet = [self evaluateWHEREClauseExpression:expression.rightOperand storage:storage indekz:indekz searchSpace:leftSet];
            NSMutableSet *intersectSet = [leftSet mutableCopy];
            [intersectSet intersectSet:rightSet];
            return intersectSet;
        }

        case BCOQueryOperatorOR: {
            NSSet *leftSet = [self evaluateWHEREClauseExpression:expression.leftOperand storage:storage indekz:indekz searchSpace:searchSpace];
            NSSet *rightSet = [self evaluateWHEREClauseExpression:expression.rightOperand storage:storage indekz:indekz searchSpace:searchSpace];
            NSMutableSet *unionSet = [leftSet mutableCopy];
            [unionSet unionSet:rightSet];
            return unionSet;
        }

        case BCOQueryOperatorEqualTo: {
            return [indekz recordsInColumn:expression.leftOperand forValue:expression.rightOperand];
        }

        case BCOQueryOperatorNotEqualTo: {
            return [indekz recordsInColumn:expression.leftOperand forValuesNotEqualToValue:expression.rightOperand];
        }

        case BCOQueryOperatorIn: {
            return [indekz recordsInColumn:expression.leftOperand forValuesInSet:expression.rightOperand];
        }

        case BCOQueryOperatorNotIn: {
            return [indekz recordsInColumn:expression.leftOperand forValuesNotInSet:expression.rightOperand];
        }

        case BCOQueryOperatorLessThan: {
            return [indekz recordsInColumn:expression.leftOperand lessThanValue:expression.rightOperand];
        }

        case BCOQueryOperatorLessThanOrEqualTo: {
            return [indekz recordsInColumn:expression.leftOperand lessThanOrEqualToValue:expression.rightOperand];
        }

        case BCOQueryOperatorGreaterThan: {
            return [indekz recordsInColumn:expression.leftOperand greaterThanValue:expression.rightOperand];
        }

        case BCOQueryOperatorGreaterThanOrEqualTo: {
            return [indekz recordsInColumn:expression.leftOperand greaterThanOrEqualToValue:expression.rightOperand];
        }

        case BCOQueryOperatorPredicate: {
            NSPredicate *predicate = expression.leftOperand;
            NSMutableSet *filteredRecords = [NSMutableSet new];
            id recordsToSearch = searchSpace ?: storage.allStorageRecords;
            for (id record in recordsToSearch) {
                id object = [storage objectForStorageRecord:record];
                BOOL didMatch = [predicate evaluateWithObject:object];
                if (didMatch) [filteredRecords addObject:record];
            }
            return filteredRecords;
        }

        case BCOQueryOperatorInvalid: {
            //This should never happen. If it does it indicates a bug in the parsing.
            [NSException raise:NSInvalidArgumentException format:@"Invalid operator."];
            break;
        }
    }

    return nil;
}

@end
