//
//  FontDescriptorToStringValueTransformer.m
//  SubEthaEdit
//
//  Created by Dominik Wagner on Fri Apr 02 2004.
//  Copyright (c) 2004 TheCodingMonkeys. All rights reserved.
//

#import "FontAttributesToStringValueTransformer.h"


@implementation FontAttributesToStringValueTransformer
+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;   
}

- (id)transformedValue:(id)aValue {
    if (![aValue isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *attributes=(NSDictionary  *)aValue;
    NSFont *font=[NSFont fontWithName:[attributes objectForKey:NSFontNameAttribute] size:[[attributes objectForKey:NSFontSizeAttribute] floatValue]];
    return [NSString stringWithFormat:@"%@, %.0f",[font displayName],[font pointSize]];
}

@end
