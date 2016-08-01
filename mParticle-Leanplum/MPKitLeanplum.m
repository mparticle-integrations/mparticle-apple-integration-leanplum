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
#import "mParticle.h"
#import "MPKitRegister.h"
#import "MPEnums.h"
#import "MPIConstants.h"

#import "Leanplum.h"

@implementation MPKitLeanplum

+ (NSNumber *)kitCode {
    return @98;
}

+ (void)load {
    MPKitRegister *kitRegister = [[MPKitRegister alloc] initWithName:@"Leanplum" className:@"MPKitLeanplum" startImmediately:NO];
    [MParticle registerExtension:kitRegister];
}

#pragma mark - MPKitInstanceProtocol methods

#pragma mark Kit instance and lifecycle
- (nonnull instancetype)initWithConfiguration:(nonnull NSDictionary *)configuration startImmediately:(BOOL)startImmediately {
    self = [super init];
    NSString *appId = configuration[@"appId"];
    NSString *clientKey = configuration[@"clientKey"];
    NSString *userIdField = configuration[@"userIdField"];
    NSString *deviceIdField = configuration[@"iosDeviceId"];
    if (!self || !appId || !clientKey || !userIdField || !deviceIdField) {
        return nil;
    }

    _configuration = configuration;

    if (startImmediately) {
        [self start];
    }

    return self;
}

- (MPUserIdentity)preferredIdentityType {
    NSString *userIdField = self.configuration[@"userIdField"];
    if ([userIdField isEqual:@"customerId"]) {
        return MPUserIdentityCustomerId;
    }
    else {
        return MPUserIdentityEmail;
    }
}

- (void)start {
    static dispatch_once_t kitPredicate;

    dispatch_once(&kitPredicate, ^{
        BOOL isDevelopment = [MParticle sharedInstance].environment == MPEnvironmentDevelopment;
        
        if ([self.configuration[@"iosDeviceId"] isEqual:@"idfa"] ||
            ([self.configuration[@"iosDeviceId"] isEqual:@"idfvForProdAndIdfaForDev"] && isDevelopment)) {
            LEANPLUM_USE_ADVERTISING_ID;
        }

        if (isDevelopment) {
            [Leanplum setAppId:self.configuration[@"appId"] withDevelopmentKey:self.configuration[@"clientKey"]];
        }
        else {
            [Leanplum setAppId:self.configuration[@"appId"] withProductionKey:self.configuration[@"clientKey"]];
        }

        NSString *userId = nil;
        for (NSDictionary<NSString *, id> *userIdentity in self.userIdentities) {
            MPUserIdentity identityType = (MPUserIdentity)[userIdentity[kMPUserIdentityTypeKey] integerValue];
            NSString *identityString = userIdentity[kMPUserIdentityIdKey];

            if (identityType == [self preferredIdentityType]) {
                userId = identityString;
                break;
            }
        }

        NSDictionary<NSString *, id> *attributes = self.userAttributes;

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
    MPKitExecStatus *execStatus;
    if (identityType == [self preferredIdentityType]) {
        [Leanplum setUserId:identityString];
        execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLeanplum) returnCode:MPKitReturnCodeSuccess];
    }
    else {
        execStatus = [[MPKitExecStatus alloc] initWithSDKCode:@(MPKitInstanceLeanplum) returnCode:MPKitReturnCodeUnavailable];
    }

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

@end
