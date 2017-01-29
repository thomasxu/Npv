using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Threading.Tasks;
using NpvApi.Dtos.Validators;
using Xunit;

namespace NpvApi.Dtos.Test.ValidatorsTest
{
    public class GreaterThanFieldAttributeTest
    {
        
        [Theory]
        [InlineData(8.8, 8.8)]
        [InlineData(8.8, 8.9)]
        [InlineData(0, 8.9)]
        [InlineData(-8.9, -8.8)]
        [InlineData(-8.9, 0)]
        [InlineData(8, 9)]
        //required and negative condition is valid here since that's the responsibility of Required and RangeAttribute
        public void PassValidationShouldSuccessTheory(decimal lowerDiscount, decimal upperDiscount)
        {
            var  rateOption = new RateOption
            {
                LowerDiscount = lowerDiscount,
                UpperDiscount = upperDiscount
            };

            var greaterThanAttribute = new GreaterThanFieldAttribute("LowerDiscount");
            var validationContext = new ValidationContext(rateOption);

            //No exception means success
            greaterThanAttribute.Validate(upperDiscount, validationContext);
        }

        [Theory]
        [InlineData(8.9, 8.8)]
        [InlineData(-8.8, -8.9)]
        [InlineData(8.9, 0)]
        [InlineData(8.9, -8.9)]
        [InlineData(9, 8)]
        //required and negative condition is valid here since that's the responsibility of Required and RangeAttribute
        public void NotPassValidationShouldThrowExceptionTheory(decimal lowerDiscount, decimal upperDiscount)
        {
            var rateOption = new RateOption
            {
                LowerDiscount = lowerDiscount,
                UpperDiscount = upperDiscount
            };

            var greaterThanAttribute = new GreaterThanFieldAttribute("LowerDiscount");
            var validationContext = new ValidationContext(rateOption);

            //No exception means succes
            Assert.Throws<ValidationException>(() => greaterThanAttribute.Validate(upperDiscount, validationContext));
        }

        [Theory]
        [InlineData(0)]
        [InlineData(10)]
        [InlineData(10.1)]
        [InlineData(11)]
        //required and negative condition is valid here since that's the responsibility of Required and RangeAttribute
        public void RangeValidatorPassValidationShouldSuccessTheory(decimal input)
        {
            var rateOption = new RateOption
            {
            };

            var greaterThanAttribute = new RangeAttribute(0d, 10d);
            var validationContext = new ValidationContext(rateOption);

            //No exception means success
            greaterThanAttribute.Validate(input, validationContext);
        }
    }
}
