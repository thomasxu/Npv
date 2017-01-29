using NpvApi.Dtos;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace NpvApi.Application
{
    public class NpvCalculator: INpvCalculator
    {  
        private static readonly int MaxLoopCount = 20;
        
        public IList<NpvResult> Calculate(NpvOptions options) {
            decimal lowerDiscount = options.RateOption.LowerDiscount;
            decimal upperDiscount = options.RateOption.UpperDiscount;
            decimal increment = options.RateOption.DiscountIncrement;
            decimal initialOutflow = -options.Outflow;

            var inflows = options.Inflows.Select(i => i.Value).ToList();


            var result = new List<NpvResult>();
            int loopCount = 0;          
            do
            {

                var npv = (double)initialOutflow;

                for (int i = 0; i < inflows.Count(); i++)
                {
                    var denom = Math.Pow((1 + (double)lowerDiscount/100), i + 1);
                    npv += (double)inflows[i] / denom;
                }
                result.Add(new NpvResult()
                {
                    DiscountRate = lowerDiscount,
                    //Round result to 2 digits 
                    NetPresentValue = (decimal)Math.Round(npv, 2)
                });

                lowerDiscount += increment;

                //The max results we will return to user to prevent 
                //malicious user putting some edge case input to make calculation do very long loop
                loopCount++;
                if (loopCount >= MaxLoopCount)
                {
                    break;
                }

                //If increment = 0 means user only want to calculate one result instead of serial of results
                //In this case normally should set lowerDiscount = higherDiscount, but user specify
                //different value for lower or higherDiscount we just assume we will use the lowerDiscount
                //and make sure we break out of the loop. Negtive should already been checked by ValidationAttribute and should never happen.
                if (increment <= 0)
                {
                    break;
                }
            }
            while (lowerDiscount <= upperDiscount);

            return result;
        }
    }
}
