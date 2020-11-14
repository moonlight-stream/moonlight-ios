//  MainFrameViewController.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/17/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

@import ImageIO;

#import "MainFrameViewController.h"
#import "CryptoManager.h"
#import "HttpManager.h"
#import "Connection.h"
#import "StreamManager.h"
#import "Utils.h"
#import "UIComputerView.h"
#import "UIAppView.h"
#import "DataManager.h"
#import "TemporarySettings.h"
#import "WakeOnLanManager.h"
#import "AppListResponse.h"
#import "ServerInfoResponse.h"
#import "StreamFrameViewController.h"
#import "LoadingFrameViewController.h"
#import "ComputerScrollView.h"
#import "TemporaryApp.h"
#import "IdManager.h"
#import "ConnectionHelper.h"

#if !TARGET_OS_TV
#import "SettingsViewController.h"
#else
#import <sys/utsname.h>
#endif

#import <VideoToolbox/VideoToolbox.h>

#include <Limelight.h>

@implementation MainFrameViewController {
    NSOperationQueue* _opQueue;
    TemporaryHost* _selectedHost;
    BOOL _showHiddenApps;
    NSString* _uniqueId;
    NSData* _clientCert;
    DiscoveryManager* _discMan;
    AppAssetManager* _appManager;
    StreamConfiguration* _streamConfig;
    UIAlertController* _pairAlert;
    LoadingFrameViewController* _loadingFrame;
    UIScrollView* hostScrollView;
    FrontViewPosition currentPosition;
    NSArray* _sortedAppList;
    NSCache* _boxArtCache;
    bool _background;
#if TARGET_OS_TV
    UITapGestureRecognizer* _menuRecognizer;
#endif
}
static NSMutableSet* hostList;

- (void)startPairing:(NSString *)PIN {
    // Needs to be synchronous to ensure the alert is shown before any potential
    // failure callback could be invoked.
    dispatch_sync(dispatch_get_main_queue(), ^{
        self->_pairAlert = [UIAlertController alertControllerWithTitle:@"Pairing"
                                                               message:[NSString stringWithFormat:@"Enter the following PIN on the host machine: %@", PIN]
                                                        preferredStyle:UIAlertControllerStyleAlert];
        [self->_pairAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action) {
            self->_pairAlert = nil;
            [self->_discMan startDiscovery];
            [self hideLoadingFrame: ^{
                [self showHostSelectionView];
            }];
        }]];
        [[self activeViewController] presentViewController:self->_pairAlert animated:YES completion:nil];
    });
}

- (void)displayPairingFailureDialog:(NSString *)message {
    UIAlertController* failedDialog = [UIAlertController alertControllerWithTitle:@"Pairing Failed"
                                                                          message:message
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    [Utils addHelpOptionToDialog:failedDialog];
    [failedDialog addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    
    [_discMan startDiscovery];
    
    [self hideLoadingFrame: ^{
        [self showHostSelectionView];
        [[self activeViewController] presentViewController:failedDialog animated:YES completion:nil];
    }];
}

- (void)pairFailed:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_pairAlert != nil) {
            [self->_pairAlert dismissViewControllerAnimated:YES completion:^{
                [self displayPairingFailureDialog:message];
            }];
            self->_pairAlert = nil;
        }
    });
}

- (void)pairSuccessful:(NSData*)serverCert {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Store the cert from pairing with the host
        self->_selectedHost.serverCert = serverCert;
        
        [self->_pairAlert dismissViewControllerAnimated:YES completion:nil];
        self->_pairAlert = nil;
        
        [self->_discMan startDiscovery];
        [self alreadyPaired];
    });
}

- (void)disableUpButton {
#if !TARGET_OS_TV
    [self->_upButton setTitle:nil];
#endif
}

- (void)enableUpButton {
#if !TARGET_OS_TV
    [self->_upButton setTitle:@"Select New Host"];
#endif
}

- (void)updateTitle {
    if (_selectedHost != nil) {
        self.title = _selectedHost.name;
    }
    else if ([hostList count] == 0) {
        self.title = @"Searching for PCs on your network...";
    }
    else {
        self.title = @"Select Host";
    }
}

- (void)alreadyPaired {
    BOOL usingCachedAppList = false;
    
    // Capture the host here because it can change once we
    // leave the main thread
    TemporaryHost* host = _selectedHost;
    if (host == nil) {
        [self hideLoadingFrame: nil];
        return;
    }
    
    if ([host.appList count] > 0) {
        usingCachedAppList = true;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (host != self->_selectedHost) {
                [self hideLoadingFrame: nil];
                return;
            }
            
            [self updateAppsForHost:host];
            [self hideLoadingFrame: nil];
        });
    }
    Log(LOG_I, @"Using cached app list: %d", usingCachedAppList);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Exempt this host from discovery while handling the applist query
        [self->_discMan pauseDiscoveryForHost:host];
        
        AppListResponse* appListResp = [ConnectionHelper getAppListForHostWithHostIP:host.activeAddress serverCert:host.serverCert uniqueID:self->_uniqueId];
        
        [self->_discMan resumeDiscoveryForHost:host];

        if (![appListResp isStatusOk] || [appListResp getAppList] == nil) {
            Log(LOG_W, @"Failed to get applist: %@", appListResp.statusMessage);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (host != self->_selectedHost) {
                    [self hideLoadingFrame: nil];
                    return;
                }
                
                UIAlertController* applistAlert = [UIAlertController alertControllerWithTitle:@"Connection Interrupted"
                                                                                      message:appListResp.statusMessage
                                                                               preferredStyle:UIAlertControllerStyleAlert];
                [Utils addHelpOptionToDialog:applistAlert];
                [applistAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self hideLoadingFrame: ^{
                    [self showHostSelectionView];
                    [[self activeViewController] presentViewController:applistAlert animated:YES completion:nil];
                }];
                host.state = StateOffline;
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateApplist:[appListResp getAppList] forHost:host];

                if (host != self->_selectedHost) {
                    [self hideLoadingFrame: nil];
                    return;
                }
                
                [self updateAppsForHost:host];
                [self->_appManager stopRetrieving];
                [self->_appManager retrieveAssetsFromHost:host];
                [self hideLoadingFrame: nil];
            });
        }
    });
}

- (void) updateAppEntry:(TemporaryApp*)app forHost:(TemporaryHost*)host {
    DataManager* database = [[DataManager alloc] init];
    NSMutableSet* newHostAppList = [NSMutableSet setWithSet:host.appList];

    for (TemporaryApp* savedApp in newHostAppList) {
        if ([app.id isEqualToString:savedApp.id]) {
            savedApp.name = app.name;
            savedApp.hdrSupported = app.hdrSupported;
            savedApp.hidden = app.hidden;
            
            host.appList = newHostAppList;

            [database updateAppsForExistingHost:host];
            return;
        }
    }
}
    
- (void) updateApplist:(NSSet*) newList forHost:(TemporaryHost*)host {
    DataManager* database = [[DataManager alloc] init];
    NSMutableSet* newHostAppList = [NSMutableSet setWithSet:host.appList];
    
    for (TemporaryApp* app in newList) {
        BOOL appAlreadyInList = NO;
        for (TemporaryApp* savedApp in newHostAppList) {
            if ([app.id isEqualToString:savedApp.id]) {
                savedApp.name = app.name;
                savedApp.hdrSupported = app.hdrSupported;
                // Don't propagate hidden, because we want the local data to prevail
                appAlreadyInList = YES;
                break;
            }
        }
        if (!appAlreadyInList) {
            app.host = host;
            [newHostAppList addObject:app];
        }
    }
    
    BOOL appWasRemoved;
    do {
        appWasRemoved = NO;
        
        for (TemporaryApp* app in newHostAppList) {
            appWasRemoved = YES;
            for (TemporaryApp* mergedApp in newList) {
                if ([mergedApp.id isEqualToString:app.id]) {
                    appWasRemoved = NO;
                    break;
                }
            }
            if (appWasRemoved) {
                // Removing the app mutates the list we're iterating (which isn't legal).
                // We need to jump out of this loop and restart enumeration.
                
                [newHostAppList removeObject:app];
                
                // It's important to remove the app record from the database
                // since we'll have a constraint violation now that appList
                // doesn't have this app in it.
                [database removeApp:app];
                
                break;
            }
        }
        
        // Keep looping until the list is no longer being mutated
    } while (appWasRemoved);
    
    host.appList = newHostAppList;

    [database updateAppsForExistingHost:host];
    
    // This host may be eligible for a shortcut now that the app list
    // has been populated
    [self updateHostShortcuts];
}

- (void)showHostSelectionView {
#if TARGET_OS_TV
    // Remove the menu button intercept to allow the app to exit
    // when at the host selection view.
    [self.navigationController.view removeGestureRecognizer:_menuRecognizer];
#endif
    
    [_appManager stopRetrieving];
    _showHiddenApps = NO;
    _selectedHost = nil;
    _sortedAppList = nil;
    
    [self updateTitle];
    [self disableUpButton];
    
    [self.collectionView reloadData];
    [self.view addSubview:hostScrollView];
}

- (void) receivedAssetForApp:(TemporaryApp*)app {
    // Update the box art cache now so we don't have to do it
    // on the main thread
    [self updateBoxArtCacheForApp:app];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
    });
}

- (void)displayDnsFailedDialog {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Network Error"
                                                                   message:@"Failed to resolve host."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [Utils addHelpOptionToDialog:alert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [[self activeViewController] presentViewController:alert animated:YES completion:nil];
}

- (void) hostClicked:(TemporaryHost *)host view:(UIView *)view {
    // Treat clicks on offline hosts to be long clicks
    // This shows the context menu with wake, delete, etc. rather
    // than just hanging for a while and failing as we would in this
    // code path.
    if (host.state != StateOnline && view != nil) {
        [self hostLongClicked:host view:view];
        return;
    }
    
    Log(LOG_D, @"Clicked host: %@", host.name);
    _selectedHost = host;
    [self updateTitle];
    [self enableUpButton];
    [self disableNavigation];
    
#if TARGET_OS_TV
    // Intercept the menu key to go back to the host page
    [self.navigationController.view addGestureRecognizer:_menuRecognizer];
#endif
    
    // If we are online, paired, and have a cached app list, skip straight
    // to the app grid without a loading frame. This is the fast path that users
    // should hit most. Check for a valid view because we don't want to hit the fast
    // path after coming back from streaming, since we need to fetch serverinfo too
    // so that our active game data is correct.
    if (host.state == StateOnline && host.pairState == PairStatePaired && host.appList.count > 0 && view != nil) {
        [self alreadyPaired];
        return;
    }
    
    [self showLoadingFrame: ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Wait for the PC's status to be known
            while (host.state == StateUnknown) {
                sleep(1);
            }
            
            // Don't bother polling if the server is already offline
            if (host.state == StateOffline) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideLoadingFrame:^{
                        [self showHostSelectionView];
                    }];
                });
                return;
            }
            
            HttpManager* hMan = [[HttpManager alloc] initWithHost:host.activeAddress uniqueId:self->_uniqueId serverCert:host.serverCert];
            ServerInfoResponse* serverInfoResp = [[ServerInfoResponse alloc] init];
            
            // Exempt this host from discovery while handling the serverinfo request
            [self->_discMan pauseDiscoveryForHost:host];
            [hMan executeRequestSynchronously:[HttpRequest requestForResponse:serverInfoResp withUrlRequest:[hMan newServerInfoRequest:false]
                                                                fallbackError:401 fallbackRequest:[hMan newHttpServerInfoRequest]]];
            [self->_discMan resumeDiscoveryForHost:host];
            
            if (![serverInfoResp isStatusOk]) {
                Log(LOG_W, @"Failed to get server info: %@", serverInfoResp.statusMessage);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (host != self->_selectedHost) {
                        [self hideLoadingFrame:nil];
                        return;
                    }
                    
                    UIAlertController* applistAlert = [UIAlertController alertControllerWithTitle:@"Connection Failed"
                                                                            message:serverInfoResp.statusMessage
                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                    [Utils addHelpOptionToDialog:applistAlert];
                    [applistAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    
                    // Only display an alert if this was the result of a real
                    // user action, not just passively entering the foreground again
                    [self hideLoadingFrame: ^{
                        [self showHostSelectionView];
                        if (view != nil) {
                            [[self activeViewController] presentViewController:applistAlert animated:YES completion:nil];
                        }
                    }];
                    
                    host.state = StateOffline;
                });
            } else {
                // Update the host object with this data
                [serverInfoResp populateHost:host];
                if (host.pairState == PairStatePaired) {
                    Log(LOG_I, @"Already Paired");
                    [self alreadyPaired];
                }
                // Only pair when this was the result of explicit user action
                else if (view != nil) {
                    Log(LOG_I, @"Trying to pair");
                    // Polling the server while pairing causes the server to screw up
                    [self->_discMan stopDiscoveryBlocking];
                    PairManager* pMan = [[PairManager alloc] initWithManager:hMan clientCert:self->_clientCert callback:self];
                    [self->_opQueue addOperation:pMan];
                }
                else {
                    // Not user action, so just return to host screen
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideLoadingFrame:^{
                            [self showHostSelectionView];
                        }];
                    });
                }
            }
        });
    }];
}

- (UIViewController*) activeViewController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;

    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }

    return topController;
}

- (void)hostLongClicked:(TemporaryHost *)host view:(UIView *)view {
    Log(LOG_D, @"Long clicked host: %@", host.name);
    NSString* message;
    
    switch (host.state) {
        case StateOffline:
            message = @"Offline";
            break;
            
        case StateOnline:
            if (host.pairState == PairStatePaired) {
                message = @"Online - Paired";
            }
            else {
                message = @"Online - Not Paired";
            }
            break;
        
        case StateUnknown:
            message = @"Connecting";
            break;
            
        default:
            break;
    }
    
    UIAlertController* longClickAlert = [UIAlertController alertControllerWithTitle:host.name message:message preferredStyle:UIAlertControllerStyleActionSheet];
    if (host.state != StateOnline) {
        [longClickAlert addAction:[UIAlertAction actionWithTitle:@"Wake PC" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            UIAlertController* wolAlert = [UIAlertController alertControllerWithTitle:@"Wake-On-LAN" message:@"" preferredStyle:UIAlertControllerStyleAlert];
            [wolAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            if (host.mac == nil || [host.mac isEqualToString:@"00:00:00:00:00:00"]) {
                wolAlert.message = @"Host MAC unknown, unable to send WOL Packet";
            } else {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [WakeOnLanManager wakeHost:host];
                });
                wolAlert.message = @"Successfully sent wake-up request. It may take a few moments for the PC to wake. If it never wakes up, ensure it's properly configured for Wake-on-LAN.";
            }
            [[self activeViewController] presentViewController:wolAlert animated:YES completion:nil];
        }]];
    }
    else if (host.pairState == PairStatePaired) {
        [longClickAlert addAction:[UIAlertAction actionWithTitle:@"Show Hidden Apps" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            self->_showHiddenApps = YES;
            [self hostClicked:host view:view];
        }]];
    }
    [longClickAlert addAction:[UIAlertAction actionWithTitle:@"Test Network" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
        [self showLoadingFrame:^{
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                // Perform the network test on a GCD worker thread. It may take a while.
                unsigned int portTestResult = LiTestClientConnectivity(CONN_TEST_SERVER, 443, ML_PORT_FLAG_ALL);
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [self hideLoadingFrame:^{
                        NSString* message;
                        
                        if (portTestResult == 0) {
                            message = @"This network does not appear to be blocking Moonlight. If you still have trouble connecting, check your PC's firewall settings.\n\nVisit the Moonlight Setup Guide on GitHub for additional setup help and troubleshooting steps.";
                        }
                        else if (portTestResult == ML_TEST_RESULT_INCONCLUSIVE) {
                            message = @"The network test could not be performed because none of Moonlight's connection testing servers were reachable. Check your Internet connection or try again later.";
                        }
                        else {
                            message = @"Your current network connection seems to be blocking Moonlight. Streaming may not work while connected to this network.\n\nThe following network ports were blocked:\n";
                            
                            for (int i = 0; i < 32; i++) {
                                if (portTestResult & (1 << i)) {
                                    NSString* portString = [NSString stringWithFormat:@"%s %u\n",
                                                            LiGetProtocolFromPortFlagIndex(i) == 17 ? "UDP" : "TCP",
                                                            LiGetPortFromPortFlagIndex(i)];
                                    message = [message stringByAppendingString:portString];
                                }
                            }
                        }
                        
                        UIAlertController* netTestAlert = [UIAlertController alertControllerWithTitle:@"Network Test Complete" message:message preferredStyle:UIAlertControllerStyleAlert];
                        [netTestAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                        [[self activeViewController] presentViewController:netTestAlert animated:YES completion:nil];
                    }];
                });
            });
        }];
    }]];
#if !TARGET_OS_TV
    if (host.state != StateOnline) {
        [longClickAlert addAction:[UIAlertAction actionWithTitle:@"Connection Help" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/moonlight-stream/moonlight-docs/wiki/Troubleshooting"]];
        }]];
    }
#endif
    [longClickAlert addAction:[UIAlertAction actionWithTitle:@"Remove Host" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action) {
        [self->_discMan removeHostFromDiscovery:host];
        DataManager* dataMan = [[DataManager alloc] init];
        [dataMan removeHost:host];
        @synchronized(hostList) {
            [hostList removeObject:host];
            [self updateAllHosts:[hostList allObjects]];
        }
        
    }]];
    [longClickAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    
    // these two lines are required for iPad support of UIAlertSheet
    longClickAlert.popoverPresentationController.sourceView = view;
    
    longClickAlert.popoverPresentationController.sourceRect = CGRectMake(view.bounds.size.width / 2.0, view.bounds.size.height / 2.0, 1.0, 1.0); // center of the view
    [[self activeViewController] presentViewController:longClickAlert animated:YES completion:nil];
}

- (void) addHostClicked {
    Log(LOG_D, @"Clicked add host");
    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"Add Host Manually" message:@"If Moonlight doesn't find your local gaming PC automatically,\nenter the IP address of your PC" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
        NSString* hostAddress = [((UITextField*)[[alertController textFields] objectAtIndex:0]).text trim];
        [self showLoadingFrame:^{
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [self->_discMan discoverHost:hostAddress withCallback:^(TemporaryHost* host, NSString* error){
                    if (host != nil) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self hideLoadingFrame:^{
                                @synchronized(hostList) {
                                    [hostList addObject:host];
                                }
                                [self updateHosts];
                            }];
                        });
                    } else {
                        unsigned int portTestResults = LiTestClientConnectivity(CONN_TEST_SERVER, 443,
                                                                                ML_PORT_FLAG_TCP_47984 | ML_PORT_FLAG_TCP_47989);
                        if (portTestResults != ML_TEST_RESULT_INCONCLUSIVE && portTestResults != 0) {
                            error = [error stringByAppendingString:@"\n\nYour device's network connection is blocking Moonlight. Streaming may not work while connected to this network."];
                        }
                        
                        UIAlertController* hostNotFoundAlert = [UIAlertController alertControllerWithTitle:@"Add Host Manually" message:error preferredStyle:UIAlertControllerStyleAlert];
                        [Utils addHelpOptionToDialog:hostNotFoundAlert];
                        [hostNotFoundAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self hideLoadingFrame:^{
                                [[self activeViewController] presentViewController:hostNotFoundAlert animated:YES completion:nil];
                            }];
                        });
                    }
                }];
            });
        }];
    }]];
    [alertController addTextFieldWithConfigurationHandler:nil];
    [[self activeViewController] presentViewController:alertController animated:YES completion:nil];
}

- (void) prepareToStreamApp:(TemporaryApp *)app {
    _streamConfig = [[StreamConfiguration alloc] init];
    _streamConfig.host = app.host.activeAddress;
    _streamConfig.appID = app.id;
    _streamConfig.appName = app.name;
    _streamConfig.serverCert = app.host.serverCert;
    
    DataManager* dataMan = [[DataManager alloc] init];
    TemporarySettings* streamSettings = [dataMan getSettings];
    
    _streamConfig.frameRate = [streamSettings.framerate intValue];
    if (@available(iOS 10.3, *)) {
        // Don't stream more FPS than the display can show
        if (_streamConfig.frameRate > [UIScreen mainScreen].maximumFramesPerSecond) {
            _streamConfig.frameRate = (int)[UIScreen mainScreen].maximumFramesPerSecond;
            Log(LOG_W, @"Clamping FPS to maximum refresh rate: %d", _streamConfig.frameRate);
        }
    }
    
    _streamConfig.height = [streamSettings.height intValue];
    _streamConfig.width = [streamSettings.width intValue];
#if TARGET_OS_TV
    // Don't allow streaming 4K on the Apple TV HD
    struct utsname systemInfo;
    uname(&systemInfo);
    if (strcmp(systemInfo.machine, "AppleTV5,3") == 0 && _streamConfig.height >= 2160) {
        Log(LOG_W, @"4K streaming not supported on Apple TV HD");
        _streamConfig.width = 1920;
        _streamConfig.height = 1080;
    }
#endif
    
    _streamConfig.bitRate = [streamSettings.bitrate intValue];
    _streamConfig.optimizeGameSettings = streamSettings.optimizeGames;
    _streamConfig.playAudioOnPC = streamSettings.playAudioOnPC;
    _streamConfig.allowHevc = streamSettings.useHevc;
    
    // multiController must be set before calling getConnectedGamepadMask
    _streamConfig.multiController = streamSettings.multiController;
    _streamConfig.gamepadMask = [ControllerSupport getConnectedGamepadMask:_streamConfig];
    

    // Probe for supported channel configurations
    long outputChannels = [AVAudioSession sharedInstance].maximumOutputNumberOfChannels;
    Log(LOG_I, @"Audio device supports %d channels", outputChannels);
    if (outputChannels >= 8) {
        _streamConfig.audioConfiguration = AUDIO_CONFIGURATION_71_SURROUND;
    }
    else if (outputChannels >= 6) {
        _streamConfig.audioConfiguration = AUDIO_CONFIGURATION_51_SURROUND;
    }
    else {
        _streamConfig.audioConfiguration = AUDIO_CONFIGURATION_STEREO;
    }
    
    // HDR requires HDR10 game, HDR10 display, and HEVC Main10 decoder on the client.
    // It additionally requires an HEVC Main10 encoder on the server (GTX 1000+).
    //
    // It should also be a user preference, since some games may require higher peak
    // brightness than the iOS device can support to look correct in HDR mode.
    if (@available(iOS 11.3, *)) {
        _streamConfig.enableHdr =
            app.hdrSupported && // App supported
            (app.host.serverCodecModeSupport & 0x200) != 0 && // HEVC Main10 encoding on host PC GPU
            VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) && // Decoder supported
            (AVPlayer.availableHDRModes & AVPlayerHDRModeHDR10) != 0 && // Display supported
            streamSettings.enableHdr; // User wants it enabled
    }
}

- (void)appLongClicked:(TemporaryApp *)app view:(UIView *)view {
    Log(LOG_D, @"Long clicked app: %@", app.name);
    
    [_appManager stopRetrieving];
    
#if !TARGET_OS_TV
    if (currentPosition != FrontViewPositionLeft) {
        // This must not be animated because we need the position
        // to change (and notify our callback to save settings data)
        // before we call prepareToStreamApp.
        [[self revealViewController] revealToggleAnimated:NO];
    }
#endif

    TemporaryApp* currentApp = [self findRunningApp:app.host];
    
    NSString* message;
    
    if (currentApp == nil || [app.id isEqualToString:currentApp.id]) {
        if (app.hidden) {
            message = @"Hidden";
        }
        else {
            message = @"";
        }
    }
    else {
        message = [NSString stringWithFormat:@"%@ is currently running", currentApp.name];
    }
    
    UIAlertController* alertController = [UIAlertController
                                          alertControllerWithTitle: app.name
                                          message:message
                                          preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction:[UIAlertAction
                                actionWithTitle:currentApp == nil ? @"Launch App" : ([app.id isEqualToString:currentApp.id] ? @"Resume App" : @"Resume Running App") style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
        if (currentApp != nil) {
            Log(LOG_I, @"Resuming application: %@", currentApp.name);
            [self prepareToStreamApp:currentApp];
        }
        else {
            Log(LOG_I, @"Launching application: %@", app.name);
            [self prepareToStreamApp:app];
        }

        [self performSegueWithIdentifier:@"createStreamFrame" sender:nil];
    }]];
    
    if (currentApp != nil) {
        [alertController addAction:[UIAlertAction actionWithTitle:
                                    [app.id isEqualToString:currentApp.id] ? @"Quit App" : @"Quit Running App and Start" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action){
                                        Log(LOG_I, @"Quitting application: %@", currentApp.name);
                                        [self showLoadingFrame: ^{
                                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                HttpManager* hMan = [[HttpManager alloc] initWithHost:app.host.activeAddress uniqueId:self->_uniqueId serverCert:app.host.serverCert];
                                                HttpResponse* quitResponse = [[HttpResponse alloc] init];
                                                HttpRequest* quitRequest = [HttpRequest requestForResponse: quitResponse withUrlRequest:[hMan newQuitAppRequest]];
                                                
                                                // Exempt this host from discovery while handling the quit operation
                                                [self->_discMan pauseDiscoveryForHost:app.host];
                                                [hMan executeRequestSynchronously:quitRequest];
                                                if (quitResponse.statusCode == 200) {
                                                    ServerInfoResponse* serverInfoResp = [[ServerInfoResponse alloc] init];
                                                    [hMan executeRequestSynchronously:[HttpRequest requestForResponse:serverInfoResp withUrlRequest:[hMan newServerInfoRequest:false]
                                                                                                        fallbackError:401 fallbackRequest:[hMan newHttpServerInfoRequest]]];
                                                    if (![serverInfoResp isStatusOk] || [[serverInfoResp getStringTag:@"state"] hasSuffix:@"_SERVER_BUSY"]) {
                                                        // On newer GFE versions, the quit request succeeds even though the app doesn't
                                                        // really quit if another client tries to kill your app. We'll patch the response
                                                        // to look like the old error in that case, so the UI behaves.
                                                        quitResponse.statusCode = 599;
                                                    }
                                                    else if ([serverInfoResp isStatusOk]) {
                                                        // Update the host object with this info
                                                        [serverInfoResp populateHost:app.host];
                                                    }
                                                }
                                                [self->_discMan resumeDiscoveryForHost:app.host];

                                                // If it fails, display an error and stop the current operation
                                                if (quitResponse.statusCode != 200) {
                                                    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Quitting App Failed"
                                                                                                message:@"Failed to quit app. If this app was started by "
                                                             "another device, you'll need to quit from that device."
                                                                                         preferredStyle:UIAlertControllerStyleAlert];
                                                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                                                    dispatch_async(dispatch_get_main_queue(), ^{
                                                        [self updateAppsForHost:app.host];
                                                        [self hideLoadingFrame: ^{
                                                            [[self activeViewController] presentViewController:alert animated:YES completion:nil];
                                                        }];
                                                    });
                                                }
                                                else {
                                                    app.host.currentGame = @"0";
                                                    dispatch_async(dispatch_get_main_queue(), ^{
                                                        // If it succeeds and we're to start streaming, segue to the stream
                                                        if (![app.id isEqualToString:currentApp.id]) {
                                                            [self prepareToStreamApp:app];
                                                            [self hideLoadingFrame: ^{
                                                                [self performSegueWithIdentifier:@"createStreamFrame" sender:nil];
                                                            }];
                                                        }
                                                        else {
                                                            // Otherwise, just hide the loading icon
                                                            [self hideLoadingFrame:nil];
                                                        }
                                                    });
                                                }
                                            });
                                        }];
                                        
                                    }]];
    }

    if (currentApp == nil || ![app.id isEqualToString:currentApp.id] || app.hidden) {
        [alertController addAction:[UIAlertAction actionWithTitle:app.hidden ? @"Show App" : @"Hide App" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
            app.hidden = !app.hidden;
            [self updateAppEntry:app forHost:app.host];
            
            // Don't call updateAppsForHost because that will nuke this
            // app immediately if we're not showing hidden apps.
        }]];
    }
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    // these two lines are required for iPad support of UIAlertSheet
    alertController.popoverPresentationController.sourceView = view;
    
    alertController.popoverPresentationController.sourceRect = CGRectMake(view.bounds.size.width / 2.0, view.bounds.size.height / 2.0, 1.0, 1.0); // center of the view
    [[self activeViewController] presentViewController:alertController animated:YES completion:nil];
}

- (void) appClicked:(TemporaryApp *)app view:(UIView *)view {
    Log(LOG_D, @"Clicked app: %@", app.name);
    
    [_appManager stopRetrieving];
    
#if !TARGET_OS_TV
    if (currentPosition != FrontViewPositionLeft) {
        // This must not be animated because we need the position
        // to change (and notify our callback to save settings data)
        // before we call prepareToStreamApp.
        [[self revealViewController] revealToggleAnimated:NO];
    }
#endif
    
    if ([self findRunningApp:app.host]) {
        // If there's a running app, display a menu
        [self appLongClicked:app view:view];
    } else {
        [self prepareToStreamApp:app];
        [self performSegueWithIdentifier:@"createStreamFrame" sender:nil];
    }
}

- (TemporaryApp*) findRunningApp:(TemporaryHost*)host {
    for (TemporaryApp* app in host.appList) {
        if ([app.id isEqualToString:host.currentGame]) {
            return app;
        }
    }
    return nil;
}

#if !TARGET_OS_TV
- (void)revealController:(SWRevealViewController *)revealController didMoveToPosition:(FrontViewPosition)position {
    // If we moved back to the center position, we should save the settings
    if (position == FrontViewPositionLeft) {
        [(SettingsViewController*)[revealController rearViewController] saveSettings];
    }
    
    currentPosition = position;
}
#endif

#if TARGET_OS_TV
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self appClicked:_sortedAppList[indexPath.row] view:nil];
}
#endif

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[StreamFrameViewController class]]) {
        StreamFrameViewController* streamFrame = segue.destinationViewController;
        streamFrame.streamConfig = _streamConfig;
    }
}

- (void) showLoadingFrame:(void (^)(void))completion {
    [_loadingFrame showLoadingFrame:completion];
}

- (void) hideLoadingFrame:(void (^)(void))completion {
    [self enableNavigation];
    [_loadingFrame dismissLoadingFrame:completion];
}

- (void)adjustScrollViewForSafeArea:(UIScrollView*)view {
    if (@available(iOS 11.0, *)) {
        if (self.view.safeAreaInsets.left >= 20 || self.view.safeAreaInsets.right >= 20) {
            view.contentInset = UIEdgeInsetsMake(0, 20, 0, 20);
        }
    }
}

// Adjust the subviews for the safe area on the iPhone X.
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    
    [self adjustScrollViewForSafeArea:self.collectionView];
    [self adjustScrollViewForSafeArea:self->hostScrollView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
        
#if !TARGET_OS_TV
    // Set the side bar button action. When it's tapped, it'll show the sidebar.
    [_settingsButton setTarget:self.revealViewController];
    [_settingsButton setAction:@selector(revealToggle:)];
    
    // Set the host name button action. When it's tapped, it'll show the host selection view.
    [_upButton setTarget:self];
    [_upButton setAction:@selector(showHostSelectionView)];
    [self disableUpButton];
    
    // Set the gesture
    [self.view addGestureRecognizer:self.revealViewController.panGestureRecognizer];
    
    // Get callbacks associated with the viewController
    [self.revealViewController setDelegate:self];
    
    // Disable bounce-back on reveal VC otherwise the settings will snap closed
    // if the user drags all the way off the screen opposite the settings pane.
    self.revealViewController.bounceBackOnOverdraw = NO;
#else
    // The settings button will direct the user into the Settings app on tvOS
    [_settingsButton setTarget:self];
    [_settingsButton setAction:@selector(openTvSettings:)];
    
    // Restore focus on the selected app on view controller pop navigation
    self.restoresFocusAfterTransition = NO;
    self.collectionView.remembersLastFocusedIndexPath = YES;
    
    _menuRecognizer = [[UITapGestureRecognizer alloc] init];
    [_menuRecognizer addTarget:self action: @selector(showHostSelectionView)];
    _menuRecognizer.allowedPressTypes = [[NSArray alloc] initWithObjects:[NSNumber numberWithLong:UIPressTypeMenu], nil];
    
    self.navigationController.navigationBar.titleTextAttributes = [NSDictionary dictionaryWithObject:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
#endif
    
    _loadingFrame = [self.storyboard instantiateViewControllerWithIdentifier:@"loadingFrame"];
    
    // Set the current position to the center
    currentPosition = FrontViewPositionLeft;
    
    // Set up crypto
    [CryptoManager generateKeyPairUsingSSL];
    _uniqueId = [IdManager getUniqueId];
    _clientCert = [CryptoManager readCertFromFile];

    _appManager = [[AppAssetManager alloc] initWithCallback:self];
    _opQueue = [[NSOperationQueue alloc] init];
    
    // Only initialize the host picker list once
    if (hostList == nil) {
        hostList = [[NSMutableSet alloc] init];
    }
    
    _boxArtCache = [[NSCache alloc] init];
        
    hostScrollView = [[ComputerScrollView alloc] init];
    hostScrollView.frame = CGRectMake(0, self.navigationController.navigationBar.frame.origin.y + self.navigationController.navigationBar.frame.size.height, self.view.frame.size.width, self.view.frame.size.height / 2);
    [hostScrollView setShowsHorizontalScrollIndicator:NO];
    hostScrollView.delaysContentTouches = NO;
    
    self.collectionView.delaysContentTouches = NO;
    self.collectionView.allowsMultipleSelection = NO;
#if !TARGET_OS_TV
    self.collectionView.multipleTouchEnabled = NO;
#endif
    
    [self retrieveSavedHosts];
    _discMan = [[DiscoveryManager alloc] initWithHosts:[hostList allObjects] andCallback:self];
        
    if ([hostList count] == 1) {
        [self hostClicked:[hostList anyObject] view:nil];
    }
    else {
        [self updateTitle];
        [self.view addSubview:hostScrollView];
    }
}

#if TARGET_OS_TV
- (void)openTvSettings:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
}
#endif

-(void)beginForegroundRefresh
{
    if (!_background) {
        // This will kick off box art caching
        [self updateHosts];
        
        // Reset state first so we can rediscover hosts that were deleted before
        [_discMan resetDiscoveryState];
        [_discMan startDiscovery];
        
        // This will refresh the applist when a paired host is selected
        if (_selectedHost != nil && _selectedHost.pairState == PairStatePaired) {
            [self hostClicked:_selectedHost view:nil];
        }
    }
}

-(void)handlePendingShortcutAction
{
    // Check if we have a pending shortcut action
    AppDelegate* delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    if (delegate.pcUuidToLoad != nil) {
        // Find the host it corresponds to
        TemporaryHost* matchingHost = nil;
        for (TemporaryHost* host in hostList) {
            if ([host.uuid isEqualToString:delegate.pcUuidToLoad]) {
                matchingHost = host;
                break;
            }
        }
        
        // Clear the pending shortcut action
        delegate.pcUuidToLoad = nil;
        
        // Complete the request
        if (delegate.shortcutCompletionHandler != nil) {
            delegate.shortcutCompletionHandler(matchingHost != nil);
            delegate.shortcutCompletionHandler = nil;
        }
        
        if (matchingHost != nil && _selectedHost != matchingHost) {
            // Navigate to the host page
            [self hostClicked:matchingHost view:nil];
        }
    }
}

-(void)handleReturnToForeground
{
    _background = NO;
    
    [self beginForegroundRefresh];
    
    // Check for a pending shortcut action when returning to foreground
    [self handlePendingShortcutAction];
}

-(void)handleEnterBackground
{
    _background = YES;
    
    [_discMan stopDiscovery];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
#if !TARGET_OS_TV
    [[self revealViewController] setPrimaryViewController:self];
#endif
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    
    // Hide 1px border line
    UIImage* fakeImage = [[UIImage alloc] init];
    [self.navigationController.navigationBar setShadowImage:fakeImage];
    [self.navigationController.navigationBar setBackgroundImage:fakeImage forBarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
    
    // Check for a pending shortcut action when appearing
    [self handlePendingShortcutAction];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleReturnToForeground)
                                                 name: UIApplicationDidBecomeActiveNotification
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleEnterBackground)
                                                 name: UIApplicationWillResignActiveNotification
                                               object: nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // We can get here on home press while streaming
    // since the stream view segues to us just before
    // entering the background. We can't check the app
    // state here (since it's in transition), so we have
    // to use this function that will use our internal
    // state here to determine whether we're foreground.
    //
    // Note that this is neccessary here as we may enter
    // this view via an error dialog from the stream
    // view, so we won't get a return to active notification
    // for that which would normally fire beginForegroundRefresh.
    [self beginForegroundRefresh];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // when discovery stops, we must create a new instance because
    // you cannot restart an NSOperation when it is finished
    [_discMan stopDiscovery];
    
    // Purge the box art cache
    [_boxArtCache removeAllObjects];
    
    // Remove our lifetime observers to avoid triggering them
    // while streaming
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) retrieveSavedHosts {
    DataManager* dataMan = [[DataManager alloc] init];
    NSArray* hosts = [dataMan getHosts];
    @synchronized(hostList) {
        [hostList addObjectsFromArray:hosts];
        
        // Initialize the non-persistent host state
        for (TemporaryHost* host in hostList) {
            if (host.activeAddress == nil) {
                host.activeAddress = host.localAddress;
            }
            if (host.activeAddress == nil) {
                host.activeAddress = host.externalAddress;
            }
            if (host.activeAddress == nil) {
                host.activeAddress = host.address;
            }
            if (host.activeAddress == nil) {
                host.activeAddress = host.ipv6Address;
            }
        }
    }
}

- (void) updateAllHosts:(NSArray *)hosts {
    dispatch_async(dispatch_get_main_queue(), ^{
        Log(LOG_D, @"New host list:");
        for (TemporaryHost* host in hosts) {
            Log(LOG_D, @"Host: \n{\n\t name:%@ \n\t address:%@ \n\t localAddress:%@ \n\t externalAddress:%@ \n\t ipv6Address:%@ \n\t uuid:%@ \n\t mac:%@ \n\t pairState:%d \n\t online:%d \n\t activeAddress:%@ \n}", host.name, host.address, host.localAddress, host.externalAddress, host.ipv6Address, host.uuid, host.mac, host.pairState, host.state, host.activeAddress);
        }
        @synchronized(hostList) {
            [hostList removeAllObjects];
            [hostList addObjectsFromArray:hosts];
        }
        [self updateHosts];
    });
}

- (void)updateHostShortcuts {
#if !TARGET_OS_TV
    NSMutableArray* quickActions = [[NSMutableArray alloc] init];
    
    @synchronized (hostList) {
        for (TemporaryHost* host in hostList) {
            // Pair state may be unknown if we haven't polled it yet, but the app list
            // count will persist from paired PCs
            if ([host.appList count] > 0) {
                UIApplicationShortcutItem* shortcut = [[UIApplicationShortcutItem alloc]
                                                       initWithType:@"PC"
                                                       localizedTitle:host.name
                                                       localizedSubtitle:nil
                                                       icon:[UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypePlay]
                                                       userInfo:[NSDictionary dictionaryWithObject:host.uuid forKey:@"UUID"]];
                [quickActions addObject: shortcut];
            }
        }
    }
    
    [UIApplication sharedApplication].shortcutItems = quickActions;
#endif
}

- (void)updateHosts {
    Log(LOG_I, @"Updating hosts...");
    [[hostScrollView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    UIComputerView* addComp = [[UIComputerView alloc] initForAddWithCallback:self];
    UIComputerView* compView;
    float prevEdge = -1;
    @synchronized (hostList) {
        // Sort the host list in alphabetical order
        NSArray* sortedHostList = [[hostList allObjects] sortedArrayUsingSelector:@selector(compareName:)];
        for (TemporaryHost* comp in sortedHostList) {
            compView = [[UIComputerView alloc] initWithComputer:comp andCallback:self];
            compView.center = CGPointMake([self getCompViewX:compView addComp:addComp prevEdge:prevEdge], hostScrollView.frame.size.height / 2);
            prevEdge = compView.frame.origin.x + compView.frame.size.width;
            [hostScrollView addSubview:compView];
            
            // Start jobs to decode the box art in advance
            for (TemporaryApp* app in comp.appList) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                    [self updateBoxArtCacheForApp:app];
                });
            }
        }
    }
    
    // Create or delete host shortcuts as needed
    [self updateHostShortcuts];
    
    // Update the title in case we now have a PC
    [self updateTitle];
    
    prevEdge = [self getCompViewX:addComp addComp:addComp prevEdge:prevEdge];
    addComp.center = CGPointMake(prevEdge, hostScrollView.frame.size.height / 2);
    
    [hostScrollView addSubview:addComp];
    [hostScrollView setContentSize:CGSizeMake(prevEdge + addComp.frame.size.width, hostScrollView.frame.size.height)];
}

- (float) getCompViewX:(UIComputerView*)comp addComp:(UIComputerView*)addComp prevEdge:(float)prevEdge {
    float padding;
    
#if TARGET_OS_TV
    padding = 100;
#else
    padding = addComp.frame.size.width / 2;
#endif
    
    if (prevEdge == -1) {
        return hostScrollView.frame.origin.x + comp.frame.size.width / 2 + padding;
    } else {
        return prevEdge + comp.frame.size.width / 2 + padding;
    }
}

// This function forces immediate decoding of the UIImage, rather
// than the default lazy decoding that results in janky scrolling.
+ (UIImage*) loadBoxArtForCaching:(TemporaryApp*)app {
    UIImage* boxArt;
    
    NSData* imageData = [NSData dataWithContentsOfFile:[AppAssetManager boxArtPathForApp:app]];
    if (imageData == nil) {
        // No box art on disk
        return nil;
    }
    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil);
    
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef imageContext =  CGBitmapContextCreate(NULL, width, height, 8, width * 4, colorSpace,
                                                       kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);

    CGContextDrawImage(imageContext, CGRectMake(0, 0, width, height), cgImage);
    
    CGImageRef outputImage = CGBitmapContextCreateImage(imageContext);

    boxArt = [UIImage imageWithCGImage:outputImage];
    
    CGImageRelease(outputImage);
    CGContextRelease(imageContext);
    
    CGImageRelease(cgImage);
    CFRelease(source);
    
    return boxArt;
}

- (void) updateBoxArtCacheForApp:(TemporaryApp*)app {
    if ([_boxArtCache objectForKey:app] == nil) {
        UIImage* image = [MainFrameViewController loadBoxArtForCaching:app];
        if (image != nil) {
            // Add the image to our cache if it was present
            [_boxArtCache setObject:image forKey:app];
        }
    }
}

- (void) updateAppsForHost:(TemporaryHost*)host {
    if (host != _selectedHost) {
        Log(LOG_W, @"Mismatched host during app update");
        return;
    }
    
    _sortedAppList = [host.appList allObjects];
    _sortedAppList = [_sortedAppList sortedArrayUsingSelector:@selector(compareName:)];
    
    if (!_showHiddenApps) {
        NSMutableArray* visibleAppList = [NSMutableArray array];
        for (TemporaryApp* app in _sortedAppList) {
            if (!app.hidden) {
                [visibleAppList addObject:app];
            }
        }
        _sortedAppList = visibleAppList;
    }
    
    [hostScrollView removeFromSuperview];
    [self.collectionView reloadData];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AppCell" forIndexPath:indexPath];
    
    TemporaryApp* app = _sortedAppList[indexPath.row];
    UIAppView* appView = [[UIAppView alloc] initWithApp:app cache:_boxArtCache andCallback:self];
    
    if (appView.bounds.size.width > 10.0) {
        CGFloat scale = cell.bounds.size.width / appView.bounds.size.width;
        [appView setCenter:CGPointMake(appView.bounds.size.width / 2 * scale, appView.bounds.size.height / 2 * scale)];
        appView.transform = CGAffineTransformMakeScale(scale, scale);
    }
    
    [cell.subviews.firstObject removeFromSuperview]; // Remove a view that was previously added
    [cell addSubview:appView];
    
    // Shadow opacity is controlled inside UIAppView based on whether the app
    // is hidden or not during the update cycle.
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:cell.bounds];
    cell.layer.masksToBounds = NO;
    cell.layer.shadowColor = [UIColor blackColor].CGColor;
    cell.layer.shadowOffset = CGSizeMake(1.0f, 5.0f);
    cell.layer.shadowPath = shadowPath.CGPath;
    
#if !TARGET_OS_TV
    cell.layer.borderWidth = 1;
    cell.layer.borderColor = [[UIColor colorWithRed:0 green:0 blue:0 alpha:0.3f] CGColor];
    cell.exclusiveTouch = YES;
#endif

    return cell;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1; // App collection only
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (_selectedHost != nil && _sortedAppList != nil) {
        return _sortedAppList.count;
    }
    else {
        return 0;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    // Purge the box art cache on low memory
    [_boxArtCache removeAllObjects];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#if !TARGET_OS_TV
- (BOOL)shouldAutorotate {
    return YES;
}
#endif

- (void) disableNavigation {
    self.navigationController.navigationBar.topItem.rightBarButtonItem.enabled = NO;
    self.navigationController.navigationBar.topItem.leftBarButtonItem.enabled = NO;
}

- (void) enableNavigation {
    self.navigationController.navigationBar.topItem.rightBarButtonItem.enabled = YES;
    self.navigationController.navigationBar.topItem.leftBarButtonItem.enabled = YES;
}

#if TARGET_OS_TV
- (BOOL)canBecomeFocused {
    return YES;
}
#endif

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    
#if !TARGET_OS_TV
    if (context.nextFocusedView != nil) {
        [context.nextFocusedView setAlpha:0.8];
    }
    [context.previouslyFocusedView setAlpha:1.0];
#endif
}

@end
