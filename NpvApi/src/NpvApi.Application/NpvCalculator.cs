using NpvApi.Dtos;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace NpvApi.Application
{
    public class NpvCalculator: INpvCalculator
    {
        //Extensive validations have been done API level by Custom DataAnnotationAttribute, 
        //so will not do validation again here.
        public IList<NpvResult> Calculate(NpvOptions options) {
            decimal lowerDiscount = options.RateOption.LowerDiscount;
            decimal upperDiscount = options.RateOption.UpperDiscount;
            decimal increment = options.RateOption.DiscountIncrement;
            decimal initialOutflow = -options.Outflow;

            var inflows = options.Inflows.Select(i => i.Value).ToList();


            var result = new List<NpvResult>();            
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

                //If increment = 0 means user only want to calculate one result instead of serial of results
                //In this case normally should set lowerDiscount = higherDiscount, but user specify
                //different value for lower or higherDiscount we just assume we will use the lowerDiscount
                //and make sure we break out of the loop. Negtive should already been checked by ValidationAttribute
                //Just double check and break it since we do not want infinite loop.
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
