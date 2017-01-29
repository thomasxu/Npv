using NpvApi.Dtos.Validators;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Threading.Tasks;

namespace NpvApi.Dtos
{
    public class NpvOptions
    {
        [Range(Constants.MinValue, double.MaxValue)]    
        public decimal Outflow { get; set; }

        public IList<Inflow> Inflows { get; set; }

        public RateOption RateOption { get; set; }

        public NpvOptions()
        {
             Inflows = new List<Inflow>();
             RateOption = new RateOption();
        }
    }

    public class RateOption
    {   
        [Range(Constants.MinValue, double.MaxValue)]   
        public decimal LowerDiscount { get; set; }

        [Range(Constants.MinValue, double.MaxValue)]
        [GreaterThanField("LowerDiscount")]
        public decimal UpperDiscount { get; set; }

        //Can be 0 and will just calculate once using the lowerDiscount value
        [Range(0, double.MaxValue)]
        [LessThanOrEqualToDifferenceOfTwoFieldsAndPositiveAttribute("LowerDiscount", "UpperDiscount")]
        public decimal DiscountIncrement { get; set; }        
    }

    public class Inflow
    {
        [Range(Constants.MinValue, double.MaxValue)]
        public decimal Value  { get; set; }        
    }
}
