using NpvApi.Dtos;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace NpvApi.Application
{
    public class NpvCalculator: INpvCalculator
    {
        //Extensive validations have been done API level, so will not do validation again here.
        public IEnumerable<NpvResult> Calculate(NpvOptions options) {
            decimal lowerDiscount = options.RateOption.LowerDiscount;
            decimal upperDiscount = options.RateOption.UpperDiscount;
            decimal increment = options.RateOption.DiscountIncrement;
            decimal initialOutflow = options.outflow;

            var inflows = options.Inflows.Select(i => i.Value).ToList();

            var result = new List<NpvResult>();            
            do
            {
                var npv = (double)initialOutflow;

                for (int i = 0; i < inflows.Count(); i++)
                {
                    var denom = Math.Pow((1 + (double)lowerDiscount/100), i + 1);
                    npv += ((double)inflows[i] / denom);
                }
                result.Add(new NpvResult()
                {
                    DiscountRate = lowerDiscount,
                    NetPresentValue = (decimal)npv
                });

                lowerDiscount += increment;
            }
            while (lowerDiscount <= upperDiscount);

            return result;
        }
    }
}
