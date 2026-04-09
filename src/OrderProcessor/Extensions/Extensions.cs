using System.Text.Json.Serialization;
using eShop.OrderProcessor.Events;
using Npgsql;
using Microsoft.Extensions.Hosting;

namespace eShop.OrderProcessor.Extensions;

public static class Extensions
{
    public static void AddApplicationServices(this IHostApplicationBuilder builder)
    {
        var eventBusConnectionString = builder.Configuration.GetConnectionString("eventbus") ?? "";
        var eventBusBuilder = eventBusConnectionString.StartsWith("Endpoint=sb://", StringComparison.OrdinalIgnoreCase)
            ? builder.AddServiceBusEventBus("eventbus")
            : builder.AddRabbitMqEventBus("eventbus");
        eventBusBuilder.ConfigureJsonOptions(options => options.TypeInfoResolverChain.Add(IntegrationEventContext.Default));

        var connectionString = builder.Configuration.GetConnectionString("orderingdb")
            ?? throw new InvalidOperationException("Connection string 'orderingdb' not found.");

        builder.Services.AddSingleton<NpgsqlDataSource>(sp =>
        {
            var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);
            return dataSourceBuilder.Build();
        });

        builder.Services.AddOptions<BackgroundTaskOptions>()
            .BindConfiguration(nameof(BackgroundTaskOptions));

        builder.Services.AddHostedService<GracePeriodManagerService>();
    }
}

[JsonSerializable(typeof(GracePeriodConfirmedIntegrationEvent))]
partial class IntegrationEventContext : JsonSerializerContext
{

}
