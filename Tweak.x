/*
 * Windir Keygate - Theos Tweak
 *
 * Inject into any .ipa to add keygate protection.
 * Keys are validated against the Windir dashboard API.
 *
 * Build: cd artifacts/windir-dylib && make package
 * Requires: Theos installed at $THEOS, iOS SDK
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ─── Configuration ───────────────────────────────────────────────────────────
static NSString *const kAPIBase     = @"https://web-dynamic-library--karrderriim.replit.app/api";
static NSString *const kKeyStoreKey = @"WindirActivatedKey";
static NSString *const kKeyExpiry   = @"WindirKeyExpiry";
static NSString *const kDeviceIDKey = @"WindirDeviceID";
// ─────────────────────────────────────────────────────────────────────────────

// Returns or generates a persistent device identifier
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

// Returns YES if a valid (non-expired) key is already stored
static BOOL hasValidStoredKey() {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *key = [ud stringForKey:kKeyStoreKey];
    NSDate   *exp = [ud objectForKey:kKeyExpiry];
    if (!key || !exp) return NO;
    return [exp timeIntervalSinceNow] > 0;
}

// ─── Keygate Window ──────────────────────────────────────────────────────────
@interface WindirKeygateViewController : UIViewController
@property (nonatomic, strong) UITextField  *keyField;
@property (nonatomic, strong) UILabel      *statusLabel;
@property (nonatomic, strong) UILabel      *timeLabel;
@property (nonatomic, strong) UIButton     *validateBtn;
@property (nonatomic, strong) UIView       *successView;
@end

@implementation WindirKeygateViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Dark background
    self.view.backgroundColor = [UIColor colorWithRed:0.118 green:0.118 blue:0.220 alpha:1.0];

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:container];

    [NSLayoutConstraint activateConstraints:@[
        [container.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [container.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [container.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [container.widthAnchor constraintEqualToAnchor:scroll.widthAnchor],
    ]];

    // Shield icon
    UILabel *icon = [self labelWithText:@"🛡" size:64 bold:NO color:[UIColor whiteColor]];
    icon.textAlignment = NSTextAlignmentCenter;

    // Title
    UILabel *title = [self labelWithText:@"Windir Security" size:26 bold:YES
                                   color:[UIColor colorWithRed:0.306 green:0.451 blue:0.875 alpha:1]];
    title.textAlignment = NSTextAlignmentCenter;

    // Subtitle
    UILabel *sub = [self labelWithText:@"Enter your activation key to continue"
                                  size:14 bold:NO color:[UIColor colorWithWhite:0.63 alpha:1]];
    sub.textAlignment = NSTextAlignmentCenter;
    sub.numberOfLines = 0;

    // Key input
    self.keyField = [[UITextField alloc] init];
    self.keyField.placeholder = @"WINDI-VIP-1D-XXXXXXXXXX";
    self.keyField.backgroundColor = [UIColor colorWithRed:0.102 green:0.102 blue:0.208 alpha:1];
    self.keyField.textColor = [UIColor whiteColor];
    self.keyField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"WINDI-VIP-1D-XXXXXXXXXX"
            attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.4 alpha:1]}];
    self.keyField.layer.cornerRadius = 12;
    self.keyField.layer.borderWidth  = 1;
    self.keyField.layer.borderColor  = [UIColor colorWithRed:0.247 green:0.247 blue:0.431 alpha:1].CGColor;
    self.keyField.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyField.returnKeyType = UIReturnKeyDone;
    UIView *leftPad = [[UIView alloc] initWithFrame:CGRectMake(0,0,14,0)];
    self.keyField.leftView = leftPad;
    self.keyField.leftViewMode = UITextFieldViewModeAlways;

    // Validate button
    self.validateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.validateBtn setTitle:@"Activate Key" forState:UIControlStateNormal];
    [self.validateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.validateBtn.backgroundColor = [UIColor colorWithRed:0.306 green:0.451 blue:0.875 alpha:1];
    self.validateBtn.layer.cornerRadius = 14;
    self.validateBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.validateBtn addTarget:self action:@selector(validateKey) forControlEvents:UIControlEventTouchUpInside];

    // Status label
    self.statusLabel = [self labelWithText:@"" size:13 bold:NO color:[UIColor colorWithRed:0.91 green:0.3 blue:0.24 alpha:1]];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;

    // Social links
    UILabel *social = [self labelWithText:@"📱 t.me/windirffx   💬 discord.gg/4hsjpkWfa"
                                     size:12 bold:NO color:[UIColor colorWithWhite:0.45 alpha:1]];
    social.textAlignment = NSTextAlignmentCenter;
    social.numberOfLines = 0;

    // Success view (hidden initially)
    self.successView = [self buildSuccessView];
    self.successView.hidden = YES;

    // Stack everything with manual frames approach via constraints
    NSArray *views = @[icon, title, sub, self.keyField, self.validateBtn, self.statusLabel, social, self.successView];
    for (UIView *v in views) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:v];
    }

    CGFloat pad = 28;
    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:container.topAnchor constant:60],
        [icon.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],

        [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:12],
        [title.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:pad],
        [title.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-pad],

        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [sub.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:pad],
        [sub.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-pad],

        [self.keyField.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:30],
        [self.keyField.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:pad],
        [self.keyField.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-pad],
        [self.keyField.heightAnchor constraintEqualToConstant:52],

        [self.validateBtn.topAnchor constraintEqualToAnchor:self.keyField.bottomAnchor constant:16],
        [self.validateBtn.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:pad],
        [self.validateBtn.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-pad],
        [self.validateBtn.heightAnchor constraintEqualToConstant:52],

        [self.statusLabel.topAnchor constraintEqualToAnchor:self.validateBtn.bottomAnchor constant:12],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:pad],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-pad],

        [self.successView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:20],
        [self.successView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:pad],
        [self.successView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-pad],

        [social.topAnchor constraintEqualToAnchor:self.successView.bottomAnchor constant:24],
        [social.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:pad],
        [social.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-pad],
        [social.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-40],
    ]];
}

- (UIView *)buildSuccessView {
    UIView *box = [[UIView alloc] init];
    box.backgroundColor = [UIColor colorWithRed:0.102 green:0.102 blue:0.208 alpha:1];
    box.layer.cornerRadius = 16;
    box.layer.borderWidth = 1.5;
    box.layer.borderColor = [UIColor colorWithRed:0.18 green:0.80 blue:0.44 alpha:1].CGColor;

    UILabel *checkmark = [self labelWithText:@"✅ Key Activated" size:16 bold:YES
                                       color:[UIColor colorWithRed:0.18 green:0.80 blue:0.44 alpha:1]];
    checkmark.textAlignment = NSTextAlignmentCenter;
    checkmark.tag = 101;

    self.timeLabel = [self labelWithText:@"" size:14 bold:NO color:[UIColor colorWithWhite:0.75 alpha:1]];
    self.timeLabel.textAlignment = NSTextAlignmentCenter;
    self.timeLabel.numberOfLines = 0;

    UILabel *security = [self labelWithText:@"🔒 Windir Protection Active" size:12 bold:NO
                                      color:[UIColor colorWithWhite:0.5 alpha:1]];
    security.textAlignment = NSTextAlignmentCenter;

    UIButton *enterBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [enterBtn setTitle:@"Enter App →" forState:UIControlStateNormal];
    [enterBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    enterBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.80 blue:0.44 alpha:1];
    enterBtn.layer.cornerRadius = 12;
    enterBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [enterBtn addTarget:self action:@selector(enterApp) forControlEvents:UIControlEventTouchUpInside];

    NSArray *views = @[checkmark, self.timeLabel, security, enterBtn];
    for (UIView *v in views) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [box addSubview:v];
    }
    [NSLayoutConstraint activateConstraints:@[
        [checkmark.topAnchor constraintEqualToAnchor:box.topAnchor constant:20],
        [checkmark.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:16],
        [checkmark.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-16],

        [self.timeLabel.topAnchor constraintEqualToAnchor:checkmark.bottomAnchor constant:8],
        [self.timeLabel.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:16],
        [self.timeLabel.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-16],

        [security.topAnchor constraintEqualToAnchor:self.timeLabel.bottomAnchor constant:8],
        [security.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:16],
        [security.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-16],

        [enterBtn.topAnchor constraintEqualToAnchor:security.bottomAnchor constant:16],
        [enterBtn.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:16],
        [enterBtn.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-16],
        [enterBtn.heightAnchor constraintEqualToConstant:44],
        [enterBtn.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-20],
    ]];
    return box;
}

- (UILabel *)labelWithText:(NSString *)text size:(CGFloat)size bold:(BOOL)bold color:(UIColor *)color {
    UILabel *l = [[UILabel alloc] init];
    l.text = text;
    l.font = bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
    l.textColor = color;
    return l;
}

- (void)validateKey {
    NSString *key = [self.keyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (key.length == 0) {
        [self showStatus:@"Please enter your key." success:NO];
        return;
    }

    [self.validateBtn setTitle:@"Validating…" forState:UIControlStateNormal];
    self.validateBtn.enabled = NO;
    self.statusLabel.text = @"";

    NSString *deviceID = getDeviceID();
    NSURL *url = [NSURL URLWithString:[kAPIBase stringByAppendingString:@"/keys/validate"]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *body = @{@"key": key, @"deviceId": deviceID};
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.validateBtn setTitle:@"Activate Key" forState:UIControlStateNormal];
            self.validateBtn.enabled = YES;

            if (err || !data) {
                [self showStatus:@"Network error. Check connection." success:NO];
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BOOL valid = [json[@"valid"] boolValue];

            if (!valid) {
                NSString *errMsg = json[@"error"] ?: @"Invalid key.";
                [self showStatus:errMsg success:NO];
                return;
            }

            // Store key and expiry locally
            NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
            [ud setObject:key forKey:kKeyStoreKey];
            NSDate *exp = [NSDate dateWithTimeIntervalSince1970:
                [[[NSISO8601DateFormatter alloc] init] dateFromString:json[@"expiresAt"]].timeIntervalSince1970];
            [ud setObject:exp forKey:kKeyExpiry];
            [ud synchronize];

            NSString *type     = json[@"type"] ?: @"";
            NSString *timeLeft = json[@"timeLeft"] ?: @"";
            self.timeLabel.text = [NSString stringWithFormat:@"Package: %@\n⏳ Time remaining: %@", type, timeLeft];
            self.successView.hidden = NO;
            [self showStatus:@"" success:YES];
        });
    }] resume];
}

- (void)showStatus:(NSString *)msg success:(BOOL)success {
    self.statusLabel.text = msg;
    self.statusLabel.textColor = success
        ? [UIColor colorWithRed:0.18 green:0.80 blue:0.44 alpha:1]
        : [UIColor colorWithRed:0.91 green:0.30 blue:0.24 alpha:1];
}

- (void)enterApp {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// ─── Hook into UIApplicationDelegate ─────────────────────────────────────────
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    // Only trigger once, from root view controller
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (hasValidStoredKey()) return; // Already activated — skip gate

        dispatch_async(dispatch_get_main_queue(), ^{
            WindirKeygateViewController *gate = [[WindirKeygateViewController alloc] init];
            gate.modalPresentationStyle = UIModalPresentationFullScreen;
            gate.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
            [self presentViewController:gate animated:YES completion:nil];
        });
    });
}

%end
