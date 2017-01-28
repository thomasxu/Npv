using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace NpvApi.Dtos
{
    public class NpvResult
    {
        public decimal DiscountRate { get; set; }

        public decimal NetPresentValue{ get; set; }
    }
}
