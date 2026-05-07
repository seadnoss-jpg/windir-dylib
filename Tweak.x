/*
 * WINDIR MODE - Keygate Tweak
 * Native UIAlertController popup — matches iOS system style.
 * Keys validated against Windir dashboard API.
 *
 * Build: make package FINALPACKAGE=1
 * Requires: Theos + iOS SDK (arm64)
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ── Config ────────────────────────────────────────────────────────────────────
static NSString *const kAPIBase     = @"https://web-dynamic-library--karrderriim.replit.app/api";
static NSString *const kKeyStoreKey = @"WindirActivatedKey";
static NSString *const kKeyExpiry   = @"WindirKeyExpiry";
static NSString *const kDeviceIDKey = @"WindirDeviceID";
// ─────────────────────────────────────────────────────────────────────────────

static NSString *getDeviceID() {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *did = [ud stringForKey:kDeviceIDKey];
    if (!did) {
        did = [[[NSUUID UUID] UUIDString] lowercaseString];
        [ud setObject:did forKey:kDeviceIDKey];
        [ud synchronize];
    }
    return did;
}

static BOOL hasValidKey() {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *key = [ud stringForKey:kKeyStoreKey];
    NSDate   *exp = [ud objectForKey:kKeyExpiry];
    if (!key || !exp) return NO;
    return [exp timeIntervalSinceNow] > 0;
}

// Shows the key input alert — blocks the app until a valid key is entered
static void showWindirAlert(UIViewController *vc) {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"WINDIR MODE"
        message:@"Enter your WINDIR key to continue."
        preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Paste license key";
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];

    // ── Activate button ──────────────────────────────────────────────────────
    UIAlertAction *activate = [UIAlertAction
        actionWithTitle:@"Activate"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) {

        NSString *key = [[alert.textFields.firstObject.text
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];

        if (key.length == 0) {
            // Show error and re-present
            UIAlertController *err = [UIAlertController
                alertControllerWithTitle:@"WINDIR MODE"
                message:@"Please paste your license key."
                preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *a) { showWindirAlert(vc); }];
            [err addAction:ok];
            [vc presentViewController:err animated:YES completion:nil];
            return;
        }

        // Show loading indicator
        UIAlertController *loading = [UIAlertController
            alertControllerWithTitle:@"WINDIR MODE"
            message:@"Validating key…"
            preferredStyle:UIAlertControllerStyleAlert];
        [vc presentViewController:loading animated:YES completion:nil];

        // Call API
        NSString *deviceID = getDeviceID();
        NSURL *url = [NSURL URLWithString:[kAPIBase stringByAppendingString:@"/keys/validate"]];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSDictionary *body = @{@"key": key, @"deviceId": deviceID};
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        req.timeoutInterval = 15;

        [[[NSURLSession sharedSession] dataTaskWithRequest:req
            completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:NO completion:^{

                    if (err || !data) {
                        UIAlertController *netErr = [UIAlertController
                            alertControllerWithTitle:@"WINDIR MODE"
                            message:@"Network error. Check your connection."
                            preferredStyle:UIAlertControllerStyleAlert];
                        [netErr addAction:[UIAlertAction actionWithTitle:@"Retry"
                            style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *a) { showWindirAlert(vc); }]];
                        [vc presentViewController:netErr animated:YES completion:nil];
                        return;
                    }

                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    BOOL valid = [json[@"valid"] boolValue];

                    if (!valid) {
                        NSString *msg = json[@"error"] ?: @"Invalid key.";
                        UIAlertController *invalid = [UIAlertController
                            alertControllerWithTitle:@"WINDIR MODE"
                            message:msg
                            preferredStyle:UIAlertControllerStyleAlert];
                        [invalid addAction:[UIAlertAction actionWithTitle:@"Try Again"
                            style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *a) { showWindirAlert(vc); }]];
                        [vc presentViewController:invalid animated:YES completion:nil];
                        return;
                    }

                    // ── Key valid — save locally ──────────────────────────
                    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
                    [ud setObject:key forKey:kKeyStoreKey];
                    NSISO8601DateFormatter *fmt = [[NSISO8601DateFormatter alloc] init];
                    NSDate *exp = [fmt dateFromString:json[@"expiresAt"]];
                    if (exp) [ud setObject:exp forKey:kKeyExpiry];
                    [ud synchronize];

                    // ── Success popup ─────────────────────────────────────
                    NSString *pkg      = json[@"type"] ?: @"";
                    NSString *timeLeft = json[@"timeLeft"] ?: @"";
                    NSString *successMsg = [NSString stringWithFormat:
                        @"✅ WINDIR %@ activated\n⏳ %@ remaining\n\n🔒 Protected by WINDIR",
                        pkg, timeLeft];

                    UIAlertController *success = [UIAlertController
                        alertControllerWithTitle:@"WINDIR MODE"
                        message:successMsg
                        preferredStyle:UIAlertControllerStyleAlert];
                    [success addAction:[UIAlertAction actionWithTitle:@"Enter App"
                        style:UIAlertActionStyleDefault handler:nil]];
                    [vc presentViewController:success animated:YES completion:nil];
                }];
            });
        }] resume];
    }];

    // ── Quit button ──────────────────────────────────────────────────────────
    UIAlertAction *quit = [UIAlertAction
        actionWithTitle:@"Quit"
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *action) {
            exit(0);
        }];

    [alert addAction:activate];
    [alert addAction:quit];
    [vc presentViewController:alert animated:YES completion:nil];
}

// ── Hook ──────────────────────────────────────────────────────────────────────
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (hasValidKey()) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            showWindirAlert(self);
        });
    });
}

%end
