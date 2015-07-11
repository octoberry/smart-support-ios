//
//  ViewController.h
//  smart-support-ios
//
//  Created by Alexandr Turyev on 11/07/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JSQMessagesViewController.h"
#import <AChat/AChat.h>

@interface ViewController : JSQMessagesViewController <UIActionSheetDelegate, AChatDelegate,AChatIntegrationDelegate, UIImagePickerControllerDelegate>


@end

