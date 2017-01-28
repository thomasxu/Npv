using System.Collections.Generic;
using NpvApi.Dtos;

namespace NpvApi.Application
{
    public interface INpvCalculator
    {
        IList<NpvResult> Calculate(NpvOptions options);
    }
}