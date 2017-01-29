using System.Linq;
using Microsoft.AspNetCore.Mvc;
using NpvApi.Application;
using NpvApi.Controllers;
using NpvApi.Dtos;
using NSubstitute;
using Xunit;

namespace NpvApi.Test
{
    /// ***************************************************************************************
    /// Important Behavior test controller inturn call application service with same input data
    /// Or return BadRequest status code
    /// The concrete calculator test will be done on NvpApi.Application.Test
    /// ***************************************************************************************
    public class NpcControllerTest
    {
        [Theory]
        [InlineData(new double[] {4381.35}, 2, 2, 0, 10000, new double[] {4000, 5000, 6000})]
        public void InvalidInputShouldReturnBadRequestStatusWithModelErrors(double[] expectedNpvResult,
            decimal lowerDiscount, decimal upperDiscount, decimal increment, decimal outflow,
            double[] inflows)
        {
            //Arrange
            var stubCalculator = Substitute.For<INpvCalculator>();
            var controller = new NpvController(stubCalculator);

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
                npvOptions.Inflows.Add(new Inflow() {Value = (decimal) inflow});
            }

            const string errorPropertyKey = "UpperDiscount";
            const string errorPropertyValue = "Required";
            //Add the error to model state to mock 400 BadRequest
            controller.ModelState.AddModelError(errorPropertyKey, errorPropertyValue);

            //Act
            var actionResult = controller.Post(npvOptions);
            var badRequestResult = actionResult as BadRequestObjectResult;

            //Assert response should contain the model errors 
            Assert.NotNull(badRequestResult);
            Assert.Equal(400, badRequestResult.StatusCode);

            var responseContent = badRequestResult.Value as SerializableError;
            Assert.NotNull(responseContent);
            Assert.Equal(1, responseContent.Keys.Count);
            Assert.Equal(errorPropertyKey, responseContent.Keys.First());
            Assert.Equal(errorPropertyValue, (responseContent.Values.First() as string[]).First());
        }


        
        [Theory]
        [InlineData(new double[] {4381.35}, 2, 2, 0, 10000, new double[] {4000, 5000, 6000})]
        public void ValidInputShouldCallApplicationServiceWithCorrectDataAndReturnOk(double[] expectedNpvResult,
            decimal lowerDiscount, decimal upperDiscount, decimal increment, decimal outflow,
            double[] inflows)
        {
            //Autofixture does not support Asp.net Core so can not use AutoData for 
            //NSubstitute and just use InlineData instead

            var mockCalculator = Substitute.For<INpvCalculator>();
            var controller = new NpvController(mockCalculator);

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
                npvOptions.Inflows.Add(new Inflow() {Value = (decimal) inflow});
            }
            var actionResult = controller.Post(npvOptions);
            mockCalculator.Received().Calculate(npvOptions);

            var badRequestResult = actionResult as OkObjectResult;

            //Assert response should contain the model errors 
            Assert.NotNull(badRequestResult);
            Assert.Equal(200, badRequestResult.StatusCode);
        }
    }
}
