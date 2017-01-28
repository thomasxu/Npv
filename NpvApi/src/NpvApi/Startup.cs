using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Autofac;
using Autofac.Extensions.DependencyInjection;
using NpvApi.Application;

namespace NpvApi
{
    public class Startup
    {
        public Startup(IHostingEnvironment env)
        {
            var builder = new ConfigurationBuilder()
                .SetBasePath(env.ContentRootPath)
                .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
                .AddJsonFile($"appsettings.{env.EnvironmentName}.json", optional: true);

            if (env.IsEnvironment("Development"))
            {
            }

            builder.AddEnvironmentVariables();
            Configuration = builder.Build();
        }

        public IConfigurationRoot Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container
        public IServiceProvider ConfigureServices(IServiceCollection services)
        {
            //Allow all for cors policy for now
            services.AddCors(o => o.AddPolicy("AllowAllPolicy",
                corsBuilder => corsBuilder.AllowAnyHeader()
                .AllowAnyMethod()
                .AllowAnyOrigin()
                .AllowCredentials()
            ));

            // Add framework services.
            services.AddMvc();

            //Add autofac 
            IContainer container = BuildContainer(services);
            return container.Resolve<IServiceProvider>();
        }

        private static IContainer BuildContainer(IServiceCollection services)
        {
            var builder = new Autofac.ContainerBuilder();
            builder.RegisterType<NpvCalculator>().As<INpvCalculator>();

            builder.Populate(services);
            var container = builder.Build();
            return container;
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline
        public void Configure(IApplicationBuilder app, IHostingEnvironment env, ILoggerFactory loggerFactory)
        {
            loggerFactory.AddConsole(Configuration.GetSection("Logging"));
            loggerFactory.AddDebug();

            //Allow all for cors policy for now
            app.UseCors("AllowAllPolicy");
            app.UseMvc();
        }
    }
}
