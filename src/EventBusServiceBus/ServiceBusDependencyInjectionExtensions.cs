using Azure.Messaging.ServiceBus;
using eShop.EventBus;
using eShop.EventBusServiceBus;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Microsoft.Extensions.Hosting;

public static class ServiceBusDependencyInjectionExtensions
{
    // {
    //   "EventBus": {
    //     "SubscriptionClientName": "...",
    //   }
    // }

    private const string SectionName = "EventBus";

    /// <summary>
    /// Adds Azure Service Bus as the event bus implementation.
    /// The connection string is read from <c>ConnectionStrings:EventBus</c>.
    /// </summary>
    public static IEventBusBuilder AddServiceBusEventBus(this IHostApplicationBuilder builder, string connectionName)
    {
        ArgumentNullException.ThrowIfNull(builder);

        var connectionString = builder.Configuration.GetConnectionString(connectionName)
            ?? throw new InvalidOperationException($"Connection string '{connectionName}' not found.");

        builder.Services.AddSingleton(_ => new ServiceBusClient(connectionString, new ServiceBusClientOptions
        {
            TransportType = ServiceBusTransportType.AmqpTcp,
        }));

        builder.Services.Configure<EventBusOptions>(builder.Configuration.GetSection(SectionName));

        builder.Services.AddSingleton<ServiceBusEventBus>();
        builder.Services.AddSingleton<IEventBus>(sp => sp.GetRequiredService<ServiceBusEventBus>());
        builder.Services.AddSingleton<IHostedService>(sp => sp.GetRequiredService<ServiceBusEventBus>());

        return new EventBusBuilder(builder.Services);
    }

    private sealed class EventBusBuilder(IServiceCollection services) : IEventBusBuilder
    {
        public IServiceCollection Services => services;
    }
}
