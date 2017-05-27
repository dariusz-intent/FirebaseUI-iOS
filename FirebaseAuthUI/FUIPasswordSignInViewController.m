//
//  Copyright (c) 2016 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FUIPasswordSignInViewController.h"

#import <FirebaseAuth/FirebaseAuth.h>
#import "FUIAuthStrings.h"
#import "FUIAuthTableViewCell.h"
#import "FUIAuthUtils.h"
#import "FUIAuth_Internal.h"
#import "FUIPasswordRecoveryViewController.h"

/** @var kCellReuseIdentifier
    @brief The reuse identifier for table view cell.
 */
static NSString *const kCellReuseIdentifier = @"cellReuseIdentifier";

@interface FUIPasswordSignInViewController () <UITableViewDataSource, UITextFieldDelegate>
@end

@implementation FUIPasswordSignInViewController {
  /** @var _email
      @brief The @c email address of the user from the previous screen.
   */
  NSString *_email;

  /** @var _emailField
      @brief The @c UITextField that user enters email address into.
   */
  UITextField *_emailField;

  /** @var _passwordField
      @brief The @c UITextField that user enters password into.
   */
  UITextField *_passwordField;
  
  __weak IBOutlet UIButton *_forgotPasswordButton;
}

- (instancetype)initWithAuthUI:(FUIAuth *)authUI
                         email:(NSString *_Nullable)email {
  return [self initWithNibName:NSStringFromClass([self class])
                        bundle:[FUIAuthUtils bundleNamed:FUIAuthBundleName]
                        authUI:authUI
                         email:email];
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil
                         authUI:(FUIAuth *)authUI
                          email:(NSString *_Nullable)email {
  self = [super initWithNibName:nibNameOrNil
                         bundle:nibBundleOrNil
                         authUI:authUI];
  if (self) {
    _email = [email copy];

    self.title = FUILocalizedString(kStr_SignInTitle);
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  UIBarButtonItem *signInButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:FUILocalizedString(kStr_SignInTitle)
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(signIn)];
  self.navigationItem.rightBarButtonItem = signInButtonItem;
  [_forgotPasswordButton setTitle:FUILocalizedString(kStr_ForgotPasswordTitle) forState:UIControlStateNormal];
}

#pragma mark - Actions

- (void)signInWithEmail:(NSString *)email andPassword:(NSString *)password {
  if (![[self class] isValidEmail:email]) {
    [self showAlertWithMessage:FUILocalizedString(kStr_InvalidEmailError)];
    return;
  }
  if (password.length <= 0) {
    [self showAlertWithMessage:FUILocalizedString(kStr_InvalidPasswordError)];
    return;
  }

  [self incrementActivity];

  [self.auth signInWithEmail:email
                    password:password
                  completion:^(FIRUser *_Nullable user, NSError *_Nullable error) {
                    [self decrementActivity];

                    if (error) {
                      switch (error.code) {
                        case FIRAuthErrorCodeWrongPassword:
                          [self showAlertWithMessage:FUILocalizedString(kStr_WrongPasswordError)];
                          return;
                        case FIRAuthErrorCodeUserNotFound:
                          [self showAlertWithMessage:FUILocalizedString(kStr_UserNotFoundError)];
                          return;
                        case FIRAuthErrorCodeUserDisabled:
                          [self showAlertWithMessage:FUILocalizedString(kStr_AccountDisabledError)];
                          return;
                        case FIRAuthErrorCodeTooManyRequests:
                          [self showAlertWithMessage:FUILocalizedString(kStr_SignInTooManyTimesError)];
                          return;
                      }
                    }
                    
                    [self.navigationController dismissViewControllerAnimated:YES completion:^{
                      [self.authUI invokeResultCallbackWithUser:user error:error];
                    }];
                  }];
}

- (void)signIn {
  [self signInWithEmail:_emailField.text andPassword:_passwordField.text];
}

- (void)forgotPasswordForEmail:(NSString *)email {
  UIViewController *viewController;
  if ([self.authUI.delegate respondsToSelector:@selector(passwordRecoveryViewControllerForAuthUI:email:)]) {
    viewController = [self.authUI.delegate passwordRecoveryViewControllerForAuthUI:self.authUI
                                                                             email:email];
  } else {
    viewController = [[FUIPasswordRecoveryViewController alloc] initWithAuthUI:self.authUI
                                                                         email:email];
  }
  [self pushViewController:viewController];

}

- (IBAction)forgotPassword {
  [self forgotPasswordForEmail:_emailField.text];
}

- (void)textFieldDidChange {
  [self didChangeEmail:_emailField.text andPassword:_passwordField.text];
}

- (void)didChangeEmail:(NSString *)email andPassword:(NSString *)password {
  BOOL enableActionButton = email.length > 0 && password.length > 0;
  self.navigationItem.rightBarButtonItem.enabled = enableActionButton;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  FUIAuthTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellReuseIdentifier];
  if (!cell) {
    UINib *cellNib = [UINib nibWithNibName:NSStringFromClass([FUIAuthTableViewCell class])
                                    bundle:[FUIAuthUtils bundleNamed:FUIAuthBundleName]];
    [tableView registerNib:cellNib forCellReuseIdentifier:kCellReuseIdentifier];
    cell = [tableView dequeueReusableCellWithIdentifier:kCellReuseIdentifier];
  }
  cell.textField.delegate = self;
  if (indexPath.row == 0) {
    cell.label.text = FUILocalizedString(kStr_Email);
    _emailField = cell.textField;
    _emailField.text = _email;
    _emailField.placeholder = FUILocalizedString(kStr_EnterYourEmail);
    _emailField.secureTextEntry = NO;
    _emailField.returnKeyType = UIReturnKeyNext;
    _emailField.keyboardType = UIKeyboardTypeEmailAddress;
    _emailField.autocorrectionType = UITextAutocorrectionTypeNo;
    _emailField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  } else if (indexPath.row == 1) {
    cell.label.text = FUILocalizedString(kStr_Password);
    _passwordField = cell.textField;
    _passwordField.placeholder = FUILocalizedString(kStr_EnterYourPassword);
    _passwordField.secureTextEntry = YES;
    _passwordField.returnKeyType = UIReturnKeyNext;
    _passwordField.keyboardType = UIKeyboardTypeDefault;
  }
  [cell.textField addTarget:self
                     action:@selector(textFieldDidChange)
           forControlEvents:UIControlEventEditingChanged];
  [self didChangeEmail:_emailField.text andPassword:_passwordField.text];
  return cell;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  if (textField == _emailField) {
    [_passwordField becomeFirstResponder];
  } else if (textField == _passwordField) {
    [self signIn];
  }
  return NO;
}

@end
