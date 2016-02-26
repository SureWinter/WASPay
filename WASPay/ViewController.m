//
//  ViewController.m
//  WASPay
//
//  Created by wangshuo on 16/2/26.
//  Copyright © 2016年 wangshuo. All rights reserved.
//

#import "ViewController.h"
#import <PassKit/PassKit.h>
#import <PassKit/PKPaymentAuthorizationViewController.h>
#import <AddressBook/AddressBook.h>

@interface ViewController ()<PKPaymentAuthorizationViewControllerDelegate>

@property (nonatomic,strong) NSMutableArray *summaryItems; //订单信息

@property (nonatomic,strong) NSMutableArray *shippingMethods; //配送方式

@property (nonatomic,strong) NSArray  *supportedNetworks; //可以支持的支付选项,这里以国内常用的银联和visa为例

@property (nonatomic,strong) PKPaymentRequest *payRequest; //支付请求

@property (nonatomic,strong) PKPaymentAuthorizationViewController  *applePayComponents; //ApplePay

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
}


/**
 *  买买买
 */
- (IBAction)buyAll:(id)sender {
   
    if (![self isSupportApplePay]) {
        return;
    }
    
    //发起支付
    self.applePayComponents.delegate = self;

    [self presentViewController:self.applePayComponents animated:YES completion:nil];

}
/**
 *  检查设备是否支持ApplePay
 */

- (BOOL)isSupportApplePay
{
    if (![PKPaymentAuthorizationViewController class]) {
        //PKPaymentAuthorizationViewController需iOS8.0以上支持
        NSLog(@"操作系统不支持ApplePay，请升级至9.0以上版本，且iPhone6以上设备才支持");
        return NO;
    }
    //检查当前设备是否可以支付
    if (![PKPaymentAuthorizationViewController canMakePayments]) {
        //支付需iOS9.0以上支持
        NSLog(@"设备不支持ApplePay，请升级至9.0以上版本，且iPhone6以上设备才支持");
        return NO;
    }
    //检查用户是否可进行某种卡的支付，根据自己项目的需要进行检测
    if (![PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:self.supportedNetworks]) {
        NSLog(@"没有绑定支付卡");
        return NO;
    }
    NSLog(@"可以支付，开始建立支付请求");
    return YES;
}


#pragma mark - PKPaymentAuthorizationViewControllerDelegate
/**
 *送货信息选择回调，如果需要根据送货地址调整送货方式，比如普通地区包邮+极速配送，偏远地区只有付费普通配送，
 *进行支付金额重新计算，可以实现该代理，返回给系统：shippingMethods配送方式，summaryItems账单列表，
 *如果不支持该送货信息返回想要的PKPaymentAuthorizationStatus
 */
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                  didSelectShippingContact:(PKContact *)contact
                                completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKShippingMethod *> * _Nonnull, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion{
    
    //contact送货地址信息，PKContact类型
    NSPersonNameComponents *name = contact.name;                //联系人姓名
    CNPostalAddress *postalAddress = contact.postalAddress;     //联系人地址
    NSString *emailAddress = contact.emailAddress;              //联系人邮箱
    CNPhoneNumber *phoneNumber = contact.phoneNumber;           //联系人手机
    NSString *supplementarySubLocality = contact.supplementarySubLocality;  //补充信息,iOS9.2及以上才有
    NSLog(@"%@%@%@%@%@",name,postalAddress,emailAddress,phoneNumber,supplementarySubLocality);
    
    completion(PKPaymentAuthorizationStatusSuccess, _shippingMethods, _summaryItems);
}


/**
 *   配送方式回调，如果需要根据不同的送货方式进行支付金额的调整，比如包邮和付费加速配送，可以实现该代理
 */

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                   didSelectShippingMethod:(PKShippingMethod *)shippingMethod
                                completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion{
    PKShippingMethod *oldShippingMethod = [_summaryItems objectAtIndex:2];
    PKPaymentSummaryItem *total = [_summaryItems lastObject];
    total.amount = [total.amount decimalNumberBySubtracting:oldShippingMethod.amount];
    total.amount = [total.amount decimalNumberByAdding:shippingMethod.amount];
    
    [_summaryItems replaceObjectAtIndex:2 withObject:shippingMethod];
    [_summaryItems replaceObjectAtIndex:3 withObject:total];
    
    completion(PKPaymentAuthorizationStatusSuccess, _summaryItems);
}


/**
 *  支付银行卡回调，如果需要根据不同的银行调整付费金额，可以实现该代理
 */

-(void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectPaymentMethod:(PKPaymentMethod *)paymentMethod completion:(void (^)(NSArray<PKPaymentSummaryItem *> * _Nonnull))completion{
    completion(_summaryItems);
}
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                       didAuthorizePayment:(PKPayment *)payment
                                completion:(void (^)(PKPaymentAuthorizationStatus status))completion {
    
    PKPaymentToken *payToken = payment.token;
    //支付凭据，发给服务端进行验证支付是否真实有效
    PKContact *billingContact = payment.billingContact;     //账单信息
    PKContact *shippingContact = payment.shippingContact;   //送货信息
//    PKContact *shippingMethod = payment.shippingMethod;     //送货方式
    NSLog(@"%@%@%@",billingContact,shippingContact,payToken);

    //等待服务器返回结果后再进行系统block调用
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //模拟服务器通信
        completion(PKPaymentAuthorizationStatusSuccess);
    });
    
    
}
- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller{
    [controller dismissViewControllerAnimated:YES completion:nil];
    self.applePayComponents = nil;
    
}


#pragma mark - lazy load

/**
 *  可以支持的支付选项,这里以国内常用的银联和visa为例
 */
- (NSArray *)supportedNetworks
{
    if (_supportedNetworks == nil) {
        _supportedNetworks = @[PKPaymentNetworkVisa,PKPaymentNetworkChinaUnionPay];
    }
    return _supportedNetworks;
}

/**
 * 设置币种、国家码及merchant标识符等基本信息
 */
- (PKPaymentRequest *)payRequest
{
    if (_payRequest == nil) {
        _payRequest = [[PKPaymentRequest alloc] init];
        
        //国家代码
        _payRequest.countryCode = @"CN";
        
        //RMB的币种代码
        _payRequest.currencyCode = @"CNY";
        
        //申请的merchantID
        _payRequest.merchantIdentifier = @"merchant.WASPay";
        
        //用户可进行支付的银行卡
        _payRequest.supportedNetworks = self.supportedNetworks;
        
        //设置支持的交易处理协议，3DS必须支持，EMV为可选。
        _payRequest.merchantCapabilities = PKMerchantCapability3DS|PKMerchantCapabilityEMV;
        
        //如果需要邮寄账单可以选择进行设置，默认PKAddressFieldNone(不邮寄账单)
        _payRequest.requiredBillingAddressFields = PKAddressFieldEmail;
        
        //送货地址信息，这里设置需要地址和联系方式和姓名，如果需要进行设置，默认PKAddressFieldNone(没有送货地址)
        _payRequest.requiredShippingAddressFields = PKAddressFieldPostalAddress|PKAddressFieldPhone|PKAddressFieldName;
        
        //快递方式
        _payRequest.shippingMethods = self.shippingMethods;
        
        //订单信息
        _payRequest.paymentSummaryItems = self.summaryItems;

    }
    return _payRequest;
}

/**
 *  配送方式
 */
- (NSMutableArray *)shippingMethods
{
    if (_shippingMethods == nil) {
        
        PKShippingMethod *freeShipping = [PKShippingMethod summaryItemWithLabel:@"包邮" amount:[NSDecimalNumber zero]];
        freeShipping.identifier = @"freeshipping";
        freeShipping.detail = @"6-8 天 送达";
        
        PKShippingMethod *expressShipping = [PKShippingMethod summaryItemWithLabel:@"极速送达" amount:[NSDecimalNumber decimalNumberWithString:@"10.00"]];
        expressShipping.identifier = @"expressshipping";
        expressShipping.detail = @"2-3 小时 送达";
        _shippingMethods = [NSMutableArray arrayWithArray:@[freeShipping, expressShipping]];
        
    }
    return _shippingMethods;
}

/**
 *  订单信息
 */
- (NSMutableArray *)summaryItems
{
    if (_summaryItems == nil) {
        
        
        NSDecimalNumber *subtotalAmount = [NSDecimalNumber decimalNumberWithMantissa:5288 exponent:0 isNegative:NO];
        PKPaymentSummaryItem *subtotal = [PKPaymentSummaryItem summaryItemWithLabel:@"商品价格" amount:subtotalAmount];
        
        NSDecimalNumber *discountAmount = [NSDecimalNumber decimalNumberWithMantissa:2165 exponent:-2 isNegative:YES];
        PKPaymentSummaryItem *discount = [PKPaymentSummaryItem summaryItemWithLabel:@"优惠折扣" amount:discountAmount];
        
        NSDecimalNumber *methodsAmount = [NSDecimalNumber zero];
        PKPaymentSummaryItem *methods = [PKPaymentSummaryItem summaryItemWithLabel:@"包邮" amount:methodsAmount];
        
        NSDecimalNumber *totalAmount = [NSDecimalNumber zero];
        totalAmount = [totalAmount decimalNumberByAdding:subtotalAmount];
        totalAmount = [totalAmount decimalNumberByAdding:discountAmount];
        totalAmount = [totalAmount decimalNumberByAdding:methodsAmount];
        PKPaymentSummaryItem *total = [PKPaymentSummaryItem summaryItemWithLabel:@"老王" amount:totalAmount];
        
        _summaryItems = [NSMutableArray arrayWithArray:@[subtotal, discount, methods, total]];
    }
    return _summaryItems;
}

- (PKPaymentAuthorizationViewController *)applePayComponents
{
    if (_applePayComponents == nil) {
        _applePayComponents = [[PKPaymentAuthorizationViewController alloc]initWithPaymentRequest:self.payRequest];
    }
    return _applePayComponents;
}
@end
