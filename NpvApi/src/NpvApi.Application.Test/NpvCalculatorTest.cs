using System.Linq;
using NpvApi.Dtos;
using Xunit;

namespace NpvApi.Application.Test
{
    /// *************************************************************************
    /// IMPORTANT: All validation has been by Custom Data Annotation Attibute 
    /// there is no validation on Application Service Layer since I do not want to  
    /// duplicate the work and the system complex, ideally it should have validation
    /// on every layer, but I do not have time for that. 
    /// please check NpvApi.Dtos.Test for validation related test.
    /// **************************************************************************
    public class NpvCalculatorTest
    {
        //Test the max results we will return to user is 20 to prevent 
        //malicious user putting some edge case input to make calculation do very long loop
        [Theory]
        [InlineData(new double[] { 4381.35 }, 2, 100, 2, 10000, new double[] { 4000, 5000, 6000 })]
        public void MoreThan20ResultShouldOnlyReturn20Records(
           double[] expectedNpvResult, decimal lowerDiscount, decimal upperDiscount,
           decimal increment, decimal outflow, double[] inflows)
        {

            var sut = new NpvCalculator();

            //Validation has been tested on project NpvApi.Dtos.Test so will not test again here.
            var npvOptions = new NpvOptions
            {
                RateOption = new RateOption
                {
                    LowerDiscount = lowerDiscount,
                    UpperDiscount = upperDiscount,
                    DiscountIncrement = increment
                },
                Outflow = outflow
            };

            foreach (var inflow in inflows.ToList())
            {
                npvOptions.Inflows.Add(new Inflow() { Value = (decimal)inflow });
            }

            var result = sut.Calculate(npvOptions);

            Assert.Equal(20, result.Count);
        }

        /// <summary>
        ///If increment = 0 means user only want to calculate one result instead of serial of results
        ///In this case normally should set lowerDiscount = higherDiscount, but user specify
        ///different value for lower or higherDiscount we just assume we will use the lowerDiscount
        ///and make sure we break out of the loop. Negtive should already been checked by ValidationAttribute and should never happen.
        /// </summary>
        [Theory]
        [InlineData(new double[] { 4381.35 }, 2, 100, 0, 10000, new double[] { 4000, 5000, 6000 })]
        public void RateIncrement0ShouldOnlyReturn1ResultBack(
           double[] expectedNpvResult, decimal lowerDiscount, decimal upperDiscount,
           decimal increment, decimal outflow, double[] inflows)
        {
            //This case need to check the result set which is different than the previous one\
            //so just keep it seperate.
            var sut = new NpvCalculator();
        
            var npvOptions = new NpvOptions
            {
                RateOption = new RateOption
                {
                    LowerDiscount = lowerDiscount,
                    UpperDiscount = upperDiscount,
                    DiscountIncrement = increment
                },
                Outflow = outflow
            };

            foreach (var inflow in inflows.ToList())
            {
                npvOptions.Inflows.Add(new Inflow() { Value = (decimal)inflow });
            }

            var result = sut.Calculate(npvOptions);

            Assert.Equal(1, result.Count);

            var expected = expectedNpvResult.First();
            var actual = (double)result.First().NetPresentValue;
            Assert.Equal(expected, actual);
            
        }


        [Theory]
        [InlineData(new double[] { 4381.35 }, 2, 2, 0, 10000, new double[] { 4000, 5000, 6000 })]
        public void ValidInputShouldGetCorrectNpvResults(double[] expectedNpvResult, 
            decimal lowerDiscount, decimal upperDiscount, decimal increment, decimal outflow,
            double[] inflows)
        {

            var sut = new NpvCalculator();

            //Validation testing has been done on project NpvApi.Dtos.Test so will not test again here.
            var npvOptions = new NpvOptions
            {
                RateOption = new RateOption
                {
                    LowerDiscount = lowerDiscount,
                    UpperDiscount = upperDiscount,
                    DiscountIncrement = increment
                },
                Outflow = outflow
            };

            foreach (var inflow in inflows.ToList())
            {
                npvOptions.Inflows.Add(new Inflow() { Value = (decimal)inflow });
            }

            var result = sut.Calculate(npvOptions);

            Assert.Equal(expectedNpvResult.Length, result.Count);

            for (int i = 0; i < expectedNpvResult.Length; i++)
            {
                var expected = expectedNpvResult[i];
                var actual = (double)result[i].NetPresentValue;
                Assert.Equal(expected, actual);
            }
        }
    }
}
