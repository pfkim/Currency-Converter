//
//  ViewController.m
//  Currency Converter
//
//  Created by kimpf on 2018. 1. 17..
//  Copyright © 2018년 Kim. All rights reserved.
//

#define SOURCE_CURRENCY @"source_CURRENCY"
#define TARGET_CURRENCY @"TARGET_CURRENCY"
#define SOURCE @"source"
#define TARGET @"target"
#define DELETE @"Delete"
#define PORTRAIT @"portrait"
#define LANDSCAPE @"landscape"

#import "ViewController.h"

@interface ViewController () <UIPickerViewDelegate, UIPickerViewDataSource>

@property (weak, nonatomic) IBOutlet UIButton *dateButton;
@property (weak, nonatomic) IBOutlet UIView *currencyView;
@property (weak, nonatomic) IBOutlet UIView *keypadView;
@property (weak, nonatomic) IBOutlet UIDatePicker *datePickerView;
@property (weak, nonatomic) IBOutlet UIPickerView *currencyPickerView;
@property (weak, nonatomic) IBOutlet UIButton *sourceAmountButton;
@property (weak, nonatomic) IBOutlet UIButton *targetAmountButton;
@property (weak, nonatomic) IBOutlet UIButton *sourceCurrencyButton;
@property (weak, nonatomic) IBOutlet UIButton *targetCurrencyButton;
@property (weak, nonatomic) IBOutlet UIButton *todayButton;

@property (strong, nonatomic) NSUserDefaults *defaults;
@property (strong, nonatomic) NSString *currencyMode;
@property (strong, nonatomic) NSMutableArray *currencies;
@property (strong, nonatomic) NSMutableArray *rates;
@property (strong, nonatomic) NSString *sourceCurrency;
@property (strong, nonatomic) NSString *targetCurrency;
@property (strong, nonatomic) NSString *sourceAmount;
@property (strong, nonatomic) NSString *targetAmount;
@property (strong, nonatomic) NSString *rotation;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *currencyViewHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *currencyViewRight;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self prepareDeviceRotation];
    [self jsonFetch];
    [self initData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self initKeypadView];
    [self initCurrencyView];
    [self initDatePickerView];
    [self initCurrencyPickerView];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark Init

- (void)prepareDeviceRotation {
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice]];
}

- (void)initData {
    self.sourceCurrency = @"EUR";
    self.sourceAmount = @"1";
    
    self.targetCurrency = @"EUR";
    self.targetAmount = @"1";
}

- (void)initKeypadView {
    for (UIView *subView in self.keypadView.subviews) [subView removeFromSuperview];
    
    CGRect windowRect = [[UIScreen mainScreen] bounds];
    CGFloat windowWidth = windowRect.size.width - 40;
    CGFloat windowHeight = windowRect.size.height - 40;
    
    CGRect frame = CGRectZero;
    if ([self.rotation isEqualToString:PORTRAIT]) {
        frame = CGRectMake(20, self.currencyViewHeight.constant + 60, windowWidth, windowHeight - self.currencyViewHeight.constant - 60);
    }
    else {
        frame = CGRectMake(windowWidth / 2 + 30, 20, windowWidth / 2 - 10, windowHeight);
    }
    self.keypadView.frame = frame;
    
    NSArray *keypads = [NSArray arrayWithObjects:
                        @"7", @"8", @"9",
                        @"4", @"5", @"6",
                        @"1", @"2", @"3",
                        @"0", @".", DELETE,
                        nil];
    
    float width = frame.size.width / 3;
    float height = frame.size.height / 4;
    
    for (int i = 0; i < 12; i++) {
        UIButton *keypad = [UIButton buttonWithType:UIButtonTypeSystem];
        keypad.frame = CGRectMake(width * (i % 3), height * (i / 3), width, height);
        [keypad.titleLabel setFont:[UIFont systemFontOfSize:24.0f weight:UIFontWeightLight]];
        [keypad setTitle:keypads[i] forState:UIControlStateNormal];
        [keypad setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [keypad setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];
        [keypad addTarget:self action:@selector(keypadPressed:)
         forControlEvents:UIControlEventTouchUpInside];
        
        [self.keypadView addSubview:keypad];
    }
}

- (void)initDatePickerView {
    self.datePickerView.frame = self.keypadView.frame;
    
    [self.datePickerView setValue:[UIColor whiteColor] forKey:@"textColor"];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    self.datePickerView.minimumDate = [dateFormatter dateFromString:@"1999-01-04"];
    self.datePickerView.maximumDate = [NSDate date];
    self.datePickerView.date = [NSDate date];
    
    [self displayDate];
}

- (void)initCurrencyPickerView {
    self.currencyPickerView.frame = self.keypadView.frame;
    
    self.currencyPickerView.delegate = self;
    self.currencyPickerView.dataSource = self;
}

- (void)initCurrencyView {
    self.currencyView.layer.cornerRadius = 12;
    self.currencyView.layer.masksToBounds = true;
    
    if ([self.rotation isEqualToString:PORTRAIT]) {
        self.currencyViewRight.constant = 20;
        self.currencyViewHeight.constant = 223;
    } else {
        CGRect windowRect = [[UIScreen mainScreen] bounds];
        CGFloat windowWidth = windowRect.size.width - 40;
        CGFloat windowHeight = windowRect.size.height - 40;
        self.currencyViewRight.constant = windowWidth / 2 + 30;
        self.currencyViewHeight.constant = windowHeight;
    }
    
    self.currencyMode = SOURCE;
    
    [self displayCurrencies];
    [self displayAmounts];
}

#pragma mark Process Methods

- (void)jsonFetch {
    self.currencies = [NSMutableArray arrayWithObject:@"EUR"];
    self.rates = [NSMutableArray arrayWithObject:@"1.000"];
    
    NSDate *date = self.datePickerView.date;

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    
    NSString *dateString = [formatter stringFromDate:date];
    NSString *urlString = [NSString stringWithFormat:@"https://api.fixer.io/%@", dateString];
    NSLog(@"url string: %@", urlString);
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSURLSessionDataTask *data = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSLog(@"data: %@", data);
        NSLog(@"error: %@", error);
        
        if (data != nil && error == nil) {
            NSError *jsonError = nil;
            
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError ];

            for (NSString *currency in [json[@"rates"] allKeys]) {
                [self.currencies addObject:currency];
                [self.rates addObject:@"1.000"];
            }
            
            // sort
            NSLog(@"currencies: %@", self.currencies);
            
            if (json.count > 0) {
                for (NSString *currency in self.currencies) {
                    NSLog(@"currency: %@", currency);
                    if ([currency isEqualToString:@"EUR"]) {
                        [self.rates replaceObjectAtIndex:[self.currencies indexOfObject:currency] withObject:@"1.000"];
                    }
                    else {
                        [self.rates replaceObjectAtIndex:[self.currencies indexOfObject:currency] withObject:[json[@"rates"] valueForKey:currency]];
                    }
                }
            }
        }
        
        dispatch_sync(dispatch_get_main_queue(),^{
            [self.currencyPickerView reloadAllComponents];
            [self displayAmounts];
        });
    }];
    
    [data resume];
}

- (void)displayDate {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterLongStyle];
    [dateFormatter setTimeZone:[NSTimeZone defaultTimeZone]];
    NSString * dateString = [dateFormatter stringFromDate:self.datePickerView.date];
    
    [self.dateButton setTitle:dateString forState:UIControlStateNormal];
}

- (void)displayCurrencies {
    [self.sourceCurrencyButton setTitle:self.sourceCurrency forState:UIControlStateNormal];
    [self.targetCurrencyButton setTitle:self.targetCurrency forState:UIControlStateNormal];
}

- (void)displayAmounts {
    [self convertAmount];
    
    [self.sourceAmountButton setTitle:[self stringToDecimal:self.sourceAmount] forState:UIControlStateNormal];
    [self.targetAmountButton setTitle:[self stringToDecimal:self.targetAmount] forState:UIControlStateNormal];
}

- (void)convertAmount {
    double sourceRate = [[self.rates objectAtIndex:[self.currencies indexOfObject:self.sourceCurrency]] doubleValue];
    double targetRate = [[self.rates objectAtIndex:[self.currencies indexOfObject:self.targetCurrency]] doubleValue];
    
    if ([self.currencyMode isEqualToString:SOURCE]) {
        self.targetAmount = [NSString stringWithFormat:@"%.2f", [self.sourceAmount doubleValue] * targetRate / sourceRate];
    }
    else if ([self.currencyMode isEqualToString:TARGET]) {
        self.sourceAmount = [NSString stringWithFormat:@"%.2f", [self.targetAmount doubleValue] * sourceRate / targetRate];
    }
}

- (NSString *)stringToDecimal:(NSString *)string {
    NSString *leftString;
    NSString *rightString;
    
    if ([string rangeOfString:@"."].location != NSNotFound) {
        leftString = [string substringToIndex:[string rangeOfString:@"."].location];
        rightString = [string substringFromIndex:[string rangeOfString:@"."].location + 1];
        
        return [NSString stringWithFormat:@"%@.%@", [NSString localizedStringWithFormat:@"%@", [NSNumber numberWithDouble:[leftString doubleValue]]], rightString];
    }
    
    return [NSString localizedStringWithFormat:@"%@", [NSNumber numberWithDouble:[string doubleValue]]];
}

- (void)changeAmount:(NSString *)string {
    NSString *amount;
    
    if ([self.currencyMode isEqualToString:SOURCE]) {
        amount = self.sourceAmount;
    }
    else if ([self.currencyMode isEqualToString:TARGET]) {
        amount = self.targetAmount;
    }
    
    if ([string isEqualToString:DELETE]) {
        if (amount.length > 0) {
            amount = [amount substringToIndex:amount.length - 1];
        }
    }
    else if ([string isEqualToString:@"."]){
        if ([amount rangeOfString:string].location == NSNotFound) {
            amount = [NSString stringWithFormat:@"%@%@", amount, string];
        }
    }
    else {
        if ([amount rangeOfString:@"."].location != NSNotFound && [amount rangeOfString:@"."].location == amount.length - 3) {
            //
        }
        else {
            if ([amount isEqualToString:@"0"]) {
                amount = [NSString stringWithFormat:@"%@", string];
            }
            else {
                amount = [NSString stringWithFormat:@"%@%@", amount, string];
            }
        }
    }
    
    if ([self.currencyMode isEqualToString:SOURCE]) {
        self.sourceAmount = amount;
    }
    else if ([self.currencyMode isEqualToString:TARGET]) {
        self.targetAmount = amount;
    }
}

- (void)orientationChanged:(NSNotification *)note{
    BOOL isChanged = NO;
    
    UIDevice * device = note.object;
    
    switch(device.orientation) {
        case UIDeviceOrientationPortrait:
            self.rotation = PORTRAIT;
            isChanged = YES;
            break;
            
        case UIDeviceOrientationLandscapeLeft:
        case UIDeviceOrientationLandscapeRight:
            self.rotation = LANDSCAPE;
            isChanged = YES;
            break;
            
        default:
            break;
    };
    
    if (isChanged) {
        [self initCurrencyView];
        [self initKeypadView];
        [self initDatePickerView];
        [self initCurrencyPickerView];
    }
}

#pragma mark Action Methods

- (void)keypadPressed:(UIButton *)keypad {
    [self changeAmount:keypad.titleLabel.text];
    [self displayAmounts];
}

- (void)showDatePickerView {
    self.datePickerView.hidden = NO;
    [UIView animateWithDuration:0.3 animations:^{
        self.keypadView.alpha = 0.0;
        self.currencyPickerView.alpha = 0.0;
        self.datePickerView.alpha = 1.0;
    } completion: ^(BOOL finished) {
        self.keypadView.hidden = finished;
        self.currencyPickerView.hidden = finished;
    }];
}

- (void)showCurrencyPickerView {
    NSInteger row = 0;
    
    if ([self.currencyMode isEqualToString:SOURCE]) {
        row = [self.currencies indexOfObject:self.sourceCurrency];
    }
    else if ([self.currencyMode isEqualToString:TARGET]) {
        row = [self.currencies indexOfObject:self.targetCurrency];
    }
    
    [self.currencyPickerView selectRow:row inComponent:0 animated:NO];
    
    self.currencyPickerView.hidden = NO;
    [UIView animateWithDuration:0.3 animations:^{
        self.keypadView.alpha = 0;
        self.currencyPickerView.alpha = 1.0;
        self.datePickerView.alpha = 0;
    } completion: ^(BOOL finished) {
        self.keypadView.hidden = finished;
        self.datePickerView.hidden = finished;
    }];
}

- (void)showKeypadView {
    self.keypadView.hidden = NO;
    [UIView animateWithDuration:0.3 animations:^{
        self.keypadView.alpha = 1.0;
        self.currencyPickerView.alpha = 0.0;
        self.datePickerView.alpha = 0.0;
    } completion: ^(BOOL finished) {
        self.currencyPickerView.hidden = finished;
        self.datePickerView.hidden = finished;
    }];
}


- (IBAction)datePressed:(id)sender {
    [self showDatePickerView];
}

- (IBAction)currencyPressed:(id)sender {
    UIButton *button = (UIButton *)sender;
    
    if (button.tag == 0) {
        self.currencyMode = SOURCE;
    }
    else if (button.tag == 1) {
        self.currencyMode = TARGET;
    }
    else {
        //
    }
    
    [self showCurrencyPickerView];
}

- (IBAction)amountPressed:(id)sender {
    UIButton *button = (UIButton *)sender;
    
    if (button.tag == 0) {
        self.currencyMode = SOURCE;
    }
    else if (button.tag == 1) {
        self.currencyMode = TARGET;
    }
    else {
        //
    }
    
    [self showKeypadView];
}

- (IBAction)datePickerViewChanged:(id)sender {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    if ([[formatter stringFromDate:self.datePickerView.date] isEqualToString:[formatter stringFromDate:[NSDate date]]]) {
        self.todayButton.hidden = YES;
    }
    else {
        self.todayButton.hidden = NO;
    }
    
    [self displayDate];
    [self jsonFetch];
}

- (IBAction)todayButtonPressed:(id)sender {
    self.todayButton.hidden = YES;
    self.datePickerView.date = [NSDate date];
    
    [self displayDate];
    [self jsonFetch];
}

#pragma mark UIPickerView

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.currencies.count;
}

- (NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return self.currencies[row];
}

- (NSAttributedString *)pickerView:(UIPickerView *)pickerView attributedTitleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSString *title = self.currencies[row];
    NSAttributedString *attString = [[NSAttributedString alloc] initWithString:title attributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}];
    
    return attString;
}

- (void)pickerView:(UIPickerView *)thePickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if ([self.currencyMode isEqualToString:SOURCE]) {
        self.sourceCurrency = self.currencies[row];
    }
    else if ([self.currencyMode isEqualToString:TARGET]) {
        self.targetCurrency = self.currencies[row];
    }
    
    [self displayCurrencies];
    [self displayAmounts];
}

@end
