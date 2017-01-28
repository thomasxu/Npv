using System.Collections.Generic;
using NpvApi.Dtos;

namespace NpvApi.Application
{
    public interface INpvCalculator
    {
        IEnumerable<NpvResult> Calculate(NpvOptions options);
    }
}