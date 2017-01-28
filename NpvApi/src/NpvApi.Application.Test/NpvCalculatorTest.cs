using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Threading.Tasks;
using NpvApi.Dtos;
using NpvApi.Dtos.Validators;
using Xunit;

namespace NpvApi.Application.Test
{
    public class NpvCalculatorTest
    {
        [Theory]
        [InlineData(new double[] { 4381.35 }, 2, 2, 0, 10000, new double[] { 4000, 5000, 6000 })]
        public void ValidInputShouldGetCorrectNpvResultsTheory(double[] expectedNpvResult, 
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
                    UpperDiscount = upperDiscount
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
