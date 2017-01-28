using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using NpvApi.Application;
using NpvApi.Dtos;

namespace NpvApi.Controllers
{
    [Route("api/[controller]")]
    public class NpvController : Controller
    {
        private INpvCalculator _nvpCalculator;

        public NpvController(INpvCalculator nvpCalculator)
        {
            this._nvpCalculator = nvpCalculator;
        }

        // GET api/npv
        [HttpGet]
        public IEnumerable<string> Get()
        {
            return new string[] { "value1", "value2" };
        }

        // GET api/npv/5
        [HttpGet("{id}")]
        public string Get(int id)
        {
            return "value";
        }

        // POST api/npv
        [HttpPost("calculate")]
        public IActionResult Post([FromBody]NpvOptions npvOptions)
        {
            if (!ModelState.IsValid) {
                return BadRequest(ModelState);
            }

           var result = _nvpCalculator.Calculate(npvOptions);
           return Ok(result);
        }

        // PUT api/npv/5
        [HttpPut("{id}")]
        public void Put(int id, [FromBody]string value)
        {
        }

        // DELETE api/npv/5
        [HttpDelete("{id}")]
        public void Delete(int id)
        {
        }
    }
}
