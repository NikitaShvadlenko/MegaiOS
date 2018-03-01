
#import "PasswordStrengthIndicatorView.h"

@interface PasswordStrengthIndicatorView ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *strengthLabel;
@property (weak, nonatomic) IBOutlet UILabel *strengthDescriptionLabel;

@end

@implementation PasswordStrengthIndicatorView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self customInit];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self customInit];
    }
    
    return self;
}

- (void)customInit {
    self.customView = [[[NSBundle mainBundle] loadNibNamed:@"PasswordStrengthIndicatorView" owner:self options:nil] firstObject];
    [self addSubview:self.customView];
    self.customView.frame = self.bounds;
}

#pragma mark - Public

- (void)updateViewWithPasswordStrength:(PasswordStrength)passwordStrength {
    switch (passwordStrength) {
        case PasswordStrengthVeryWeak:
            self.imageView.image = [UIImage imageNamed:@"indicatorVeryWeak"];
            self.strengthLabel.text = AMLocalizedString(@"veryWeak", @"Label displayed during checking the strength of the password introduced. Represents Very Weak security");
            self.strengthLabel.textColor = [UIColor mnz_redF0373A];
            self.strengthDescriptionLabel.text = AMLocalizedString(@"passwordVeryWeakOrWeak", @"");
            break;
            
        case PasswordStrengthWeak:
            self.imageView.image = [UIImage imageNamed:@"indicatorWeak"];
            self.strengthLabel.text = AMLocalizedString(@"weak", @"");
            self.strengthLabel.textColor = [UIColor colorWithRed:1.0 green:165.0/255.0 blue:0 alpha:1.0];
            self.strengthDescriptionLabel.text = AMLocalizedString(@"passwordVeryWeakOrWeak", @"");
            break;
            
        case PasswordStrengthMedium:
            self.imageView.image = [UIImage imageNamed:@"indicatorMedium"];
            self.strengthLabel.text = AMLocalizedString(@"medium", @"Label displayed during checking the strength of the password introduced. Represents Medium security");
            self.strengthLabel.textColor = [UIColor mnz_green31B500];
            self.strengthDescriptionLabel.text = AMLocalizedString(@"passwordMedium", @"");
            break;
            
        case PasswordStrengthGood:
            self.imageView.image = [UIImage imageNamed:@"indicatorGood"];
            self.strengthLabel.text = AMLocalizedString(@"good", @"");
            self.strengthLabel.textColor = [UIColor colorWithRed:18.0/255.0 green:210.0/255.0 blue:56.0/255.0 alpha:1.0];
            self.strengthDescriptionLabel.text = AMLocalizedString(@"passwordGood", @"");
            break;
            
        case PasswordStrengthStrong:
            self.imageView.image = [UIImage imageNamed:@"indicatorStrong"];
            self.strengthLabel.text = AMLocalizedString(@"strong", @"Label displayed during checking the strength of the password introduced. Represents Strong security");
            self.strengthLabel.textColor = [UIColor mnz_blue2BA6DE];
            self.strengthDescriptionLabel.text = AMLocalizedString(@"passwordStrong", @"");
            break;
    }
}

@end
