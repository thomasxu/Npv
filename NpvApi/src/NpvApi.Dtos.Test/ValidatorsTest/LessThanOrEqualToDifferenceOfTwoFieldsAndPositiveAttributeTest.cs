using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Threading.Tasks;
using NpvApi.Dtos.Validators;
using Xunit;

namespace NpvApi.Dtos.Test.ValidatorsTest
{
    public class LessThanOrEqualToDifferenceOfTwoFieldsAndPositiveAttributeTest
    {

        [Theory]
        [InlineData(0, 8.8, 8.8)]
        [InlineData(0.1, 8.8, 8.9)]
        [InlineData(8.9, 0, 8.9)]
        [InlineData(0.1, -8.9, -8.8)] //This should pass, since negative check is the responsibility of RangeAttribute
        [InlineData(0.4, -8.9, 0)]
        [InlineData(0.5, 8, 9)]
        public void ValidInputShouldPassValidation(decimal increment, decimal lowerDiscount, decimal upperDiscount)
        {
            var rateOption = new RateOption
            {
                LowerDiscount = lowerDiscount,
                UpperDiscount = upperDiscount
            };

            var greaterThanAttribute = new LessThanOrEqualToDifferenceOfTwoFieldsAndPositiveAttribute("LowerDiscount", "UpperDiscount");
            var validationContext = new ValidationContext(rateOption);

            //No exception means success
            greaterThanAttribute.Validate(increment, validationContext);
        }


        [Theory]
        [InlineData(0.1, 8.8, 8.8)]
        [InlineData(-1, 8.8, 8.8)]
        [InlineData(0.2, 8.8, 8.9)]
        [InlineData(9, 0, 8.9)]
        [InlineData(0.2, -8.9, -8.8)] 
        [InlineData(9, -8.9, 0)]
        [InlineData(2, 8, 9)]
        [InlineData(-2, -6, -9)]
        public void InvalidInputShouldThrowException(decimal increment, decimal lowerDiscount, decimal upperDiscount)
        {
            var rateOption = new RateOption
            {
                LowerDiscount = lowerDiscount,
                UpperDiscount = upperDiscount
            };

            var greaterThanAttribute = new LessThanOrEqualToDifferenceOfTwoFieldsAndPositiveAttribute("LowerDiscount",
                "UpperDiscount");
            var validationContext = new ValidationContext(rateOption);
            
            Assert.Throws<ValidationException>(() => greaterThanAttribute.Validate(increment, validationContext));
        }
    }
}
