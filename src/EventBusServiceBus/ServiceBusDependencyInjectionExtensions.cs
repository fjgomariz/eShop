using System.Diagnostics.CodeAnalysis;
using Azure.Messaging.ServiceBus;
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
    /// The connection string is read from <c>ConnectionStrings:{connectionName}</c>.
    /// </summary>
    [UnconditionalSuppressMessage("Trimming", "IL2026:RequiresUnreferencedCode",
        Justification = "EventBusOptions only has simple string/int properties; no referenced-code risk.")]
    [UnconditionalSuppressMessage("AOT", "IL3050:RequiresDynamicCode",
        Justification = "Azure App Service uses JIT; AOT is not a target for this deployment.")]
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
