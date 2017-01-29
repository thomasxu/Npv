using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace NpvApi.Dtos
{
    public static class Constants
    {
        //Since some range validation do not allow Min 0, just give some reasonablly small number 
        //for Npn calculation (e.g. allowed min value for inflow and outflow)
        public const double MinValue = 0.001;
    }
}
