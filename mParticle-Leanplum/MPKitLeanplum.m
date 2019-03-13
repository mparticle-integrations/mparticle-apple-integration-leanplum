//
//  MPKitLeanplum.m
//
//  Copyright 2016 mParticle, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "MPKitLeanplum.h"

#if defined(__has_include) && __has_include(<Leanplum/Leanplum.h>)
#import <Leanplum/Leanplum.h>
#else
#import "Leanplum.h"
#endif

// Per Leanplum's docs - you must send email as a user attribute for email campaigns to function.
// https://support.leanplum.com/hc/en-us/articles/217075086-Setup-Email-Messaging#verify-leanplum-has-your-users'-email-addresses
static NSString * const kMPLeanplumEmailUserAttributeKey = @"email";

@implementation MPKitLeanplum

+ (NSNumber *)kitCode {
    return @98;
}

+ (void)load {
    MPKitRegister *kitRegister = [[MPKitRegister alloc] initWithName:@"Leanplum" className:@"MPKitLeanplum"];
    [MParticle registerExtension:kitRegister];
}

#pragma mark - MPKitInstanceProtocol methods

#pragma mark Kit instance and lifecycle
- (MPKitExecStatus *)didFinishLaunchingWithConfiguration:(NSDictionary *)configuration {
    MPKitExecStatus *execStatus = nil;
    
    NSString *appId = configuration[@"appId"];
    NSString *clientKey = configuration[@"clientKey"];
    NSString *userIdField = configuration[@"userIdField"];
    if (!appId || !clientKey || !userIdField) {
        execStatus = [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeRequirementsNotMet];
        return execStatus;
    }
    
    _configuration = configuration;
    
    execStatus = [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (bool)isPreferredIdentityType: (MPUserIdentity) identityType {
    NSString *userIdField = self.configuration[@"userIdField"];
    if ([userIdField isEqual:@"customerId"]) {
        return identityType == MPUserIdentityCustomerId;
    } else if ([userIdField isEqual:@"email"]) {
        return identityType == MPUserIdentityEmail;
    } else {
        return false;
    }
}

- (NSString*) generateUserId:(NSDictionary *) configuration user:(FilteredMParticleUser*)user {
    NSString *userIdField = configuration[@"userIdField"];
    if ([userIdField isEqual:@"mpid"]) {
        if (user != nil && user.userId != nil && user.userId.integerValue != 0) {
            return [user.userId stringValue];
        } else {
            return nil;
        }
    }
    
    MPUserIdentity idType = 0;
    if ([userIdField isEqual:@"customerId"]) {
        idType = MPUserIdentityCustomerId;
    } else if ([userIdField isEqual:@"email"]) {
        idType = MPUserIdentityEmail;
    } else {
        return nil;
    }
    
    return [user.userIdentities objectForKey:[NSNumber numberWithInt:idType]];
}

- (void)start {
    static dispatch_once_t kitPredicate;
    
    dispatch_once(&kitPredicate, ^{
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onUserIdentified:) name:mParticleIdentityStateChangeListenerNotification object:nil];
        if ([MParticle sharedInstance].environment == MPEnvironmentDevelopment) {
            LEANPLUM_USE_ADVERTISING_ID;
            [Leanplum setAppId:self.configuration[@"appId"] withDevelopmentKey:self.configuration[@"clientKey"]];
        }
        else {
            [Leanplum setAppId:self.configuration[@"appId"] withProductionKey:self.configuration[@"clientKey"]];
        }
        
        NSString *deviceIdType = self.configuration[@"iosDeviceId"];
        if (deviceIdType == nil) {
            deviceIdType = @"";
        }
        if ([deviceIdType isEqualToString:@"idfa"]) {
            LEANPLUM_USE_ADVERTISING_ID;
        } else if ([deviceIdType isEqualToString:@"das"]) {
            [Leanplum setDeviceId:[MParticle sharedInstance].identity.deviceApplicationStamp];
        }
        
        FilteredMParticleUser *user = [self currentUser];
        NSString *userId = [self generateUserId:self.configuration
                                           user:user];
        
        NSString *email = [user.userIdentities objectForKey:[NSNumber numberWithInt:MPUserIdentityEmail]];
        
        NSDictionary<NSString *, id> *attributes = user.userAttributes;
        if (email != nil) {
            if (attributes == nil) {
                attributes = [NSMutableDictionary dictionary];
            }
            [attributes setValue:email forKey:kMPLeanplumEmailUserAttributeKey];
        }
        if (userId && attributes) {
            [Leanplum startWithUserId:userId userAttributes:attributes];
        }
        else if (attributes) {
            [Leanplum startWithUserAttributes:attributes];
        }
        else if (userId) {
            [Leanplum startWithUserId:userId];
        }
        else {
            [Leanplum start];
        }
        
        _started = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *userInfo = @{mParticleKitInstanceKey:[[self class] kitCode]};
            
            [[NSNotificationCenter defaultCenter] postNotificationName:mParticleKitDidBecomeActiveNotification
                                                                object:nil
                                                              userInfo:userInfo];
        });
    });
}

- (id const)kitInstance {
    return nil;
}

- (MPKitAPI *)kitApi {
    if (_kitApi == nil) {
        _kitApi = [[MPKitAPI alloc] init];
    }
    
    return _kitApi;
}

- (MPKitExecStatus *)onUserIdentified:(NSNotification*) notification {
    FilteredMParticleUser *user = [self currentUser];
    NSString *userId = [self generateUserId:self.configuration user:user];
    if (userId != nil) {
        [Leanplum setUserId:userId];
        [Leanplum forceContentUpdate];
        return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeSuccess];
    } else {
        return [[MPKitExecStatus alloc] initWithSDKCode:[[self class] kitCode] returnCode:MPKitReturnCodeFail];
    }
}


#pragma mark Application
- (MPKitExecStatus *)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo {
    [Leanplum handleActionWithIdentifier:identifier forRemoteNotification:userInfo completionHandler:^{
    }];
    
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLeanplum) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

#pragma mark User attributes and identities
- (MPKitExecStatus *)setUserAttribute:(NSString *)key value:(NSString *)value {
    NSDictionary *attributes = @{key: value};
    [Leanplum setUserAttributes:attributes];
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLeanplum) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)removeUserAttribute:(NSString *)key {
    [Leanplum startWithUserAttributes:@{key: [NSNull null]}];
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLeanplum) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)setUserIdentity:(NSString *)identityString identityType:(MPUserIdentity)identityType {
    if (identityType == MPUserIdentityEmail) {
        [self setUserAttribute:kMPLeanplumEmailUserAttributeKey value:identityString];
    }
    MPKitExecStatus *execStatus;
    if ([self isPreferredIdentityType:identityType]) {
        [Leanplum setUserId:identityString];
        execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLeanplum) returnCode:MPKitReturnCodeSuccess];
    }
    else {
        execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLeanplum) returnCode:MPKitReturnCodeUnavailable];
    }
    
    return execStatus;
}

#pragma mark e-Commerce
- (MPKitExecStatus *)logCommerceEvent:(MPCommerceEvent *)commerceEvent {
    
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLeanplum) returnCode:MPKitReturnCodeSuccess forwardCount:0];
    
    if (commerceEvent.type == MPEventTypePurchase) {
        NSMutableDictionary *baseProductAttributes = [[NSMutableDictionary alloc] init];
        NSDictionary *transactionAttributes = [commerceEvent.transactionAttributes beautifiedDictionaryRepresentation];
        
        if (transactionAttributes) {
            [baseProductAttributes addEntriesFromDictionary:transactionAttributes];
        }
        
        NSDictionary *commerceEventAttributes = [commerceEvent beautifiedAttributes];
        NSArray *keys = @[kMPExpCECheckoutOptions, kMPExpCECheckoutStep, kMPExpCEProductListName, kMPExpCEProductListSource];
        
        for (NSString *key in keys) {
            if (commerceEventAttributes[key]) {
                baseProductAttributes[key] = commerceEventAttributes[key];
            }
        }
        
        NSArray *products = commerceEvent.products;
        NSMutableDictionary *properties;
        
        for (MPProduct *product in products) {
            // Add relevant attributes from the commerce event
            properties = [[NSMutableDictionary alloc] init];
            if (baseProductAttributes.count > 0) {
                [properties addEntriesFromDictionary:baseProductAttributes];
            }
            
            // Add attributes from the product itself
            NSDictionary *productDictionary = [product beautifiedDictionaryRepresentation];
            if (productDictionary) {
                [properties addEntriesFromDictionary:productDictionary];
            }
            
            // Strips key/values already being passed, plus key/values initialized to default values
            keys = @[kMPProductAffiliation, kMPExpProductCategory, kMPExpProductName];
            [properties removeObjectsForKeys:keys];
            
            double value = [product.price doubleValue] * [product.quantity doubleValue];
            
            [Leanplum track:LP_PURCHASE_EVENT withValue:value andInfo:product.name andParameters:properties];
            [execStatus incrementForwardCount];
        }
    } else {
        NSArray *expandedInstructions = [commerceEvent expandedInstructions];
        
        for (MPCommerceEventInstruction *commerceEventInstruction in expandedInstructions) {
            [self logEvent:commerceEventInstruction.event];
            [execStatus incrementForwardCount];
        }
    }
    
    return execStatus;
}

- (MPKitExecStatus *)logLTVIncrease:(double)increaseAmount event:(MPEvent *)event {
    [Leanplum track:event.name withValue:increaseAmount andParameters:event.info];
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLeanplum) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (MPKitExecStatus *)receivedUserNotification:(NSDictionary *)userInfo {
    [Leanplum handleActionWithIdentifier:nil forRemoteNotification:userInfo completionHandler:^{
    }];
    
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLeanplum) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

#pragma mark Events

- (MPKitExecStatus *)logEvent:(MPEvent *)event {
    [Leanplum track:event.name withParameters:event.info];
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLeanplum) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}

- (nonnull MPKitExecStatus *)logScreen:(nonnull MPEvent *)event {
    [Leanplum advanceTo:event.name withParameters:event.info];
    MPKitExecStatus *execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLeanplum) returnCode:MPKitReturnCodeSuccess];
    return execStatus;
}


#pragma helper methods

- (FilteredMParticleUser *)currentUser {
    return [[self kitApi] getCurrentUserWithKit:self];
}

@end
