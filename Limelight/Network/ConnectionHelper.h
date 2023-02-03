//
//  ConnectionHelper.h
//  Moonlight macOS
//
//  Created by Felix Kratz on 22.03.18.
//  Copyright © 2018 Felix Kratz. All rights reserved.
//

#import "AppListResponse.h"
#import "TemporaryHost.h"

#ifndef ConnectionHelper_h
#define ConnectionHelper_h

@interface ConnectionHelper : NSObject

+(AppListResponse*) getAppListForHost:(TemporaryHost*)host;

@end

#endif /* ConnectionHelper_h */
