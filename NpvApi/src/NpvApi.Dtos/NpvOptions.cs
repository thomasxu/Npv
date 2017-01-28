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
        [Range(double.MinValue, 0)]    
        public decimal outflow { get; set; }

        public Inflow[] Inflows { get; set; }

        public RateOption RateOption { get; set; }
    }

    public class RateOption
    {
        [Range(0, double.MaxValue)]   
        public decimal LowerDiscount { get; set; }

        [Range(0, double.MaxValue)]
        [GreaterThanField("LowerDiscount")]
        public decimal UpperDiscount { get; set; }

        [Range(0, double.MaxValue)]
        [LessThanOrEqualToDifferenceOfTwoFieldsAndPositiveAttribute("LowerDiscount", "UpperDiscount")]
        public decimal DiscountIncrement { get; set; }        
    }

    public class Inflow
    {
        [Range(0, double.MaxValue)]
        public decimal Value  { get; set; }        
    }
}
