using System.Text.Json.Serialization;
using eShop.Basket.API.Repositories;
using eShop.Basket.API.IntegrationEvents.EventHandling;
using eShop.Basket.API.IntegrationEvents.EventHandling.Events;
using StackExchange.Redis;

namespace eShop.Basket.API.Extensions;

public static class Extensions
{
    public static void AddApplicationServices(this IHostApplicationBuilder builder)
    {
        builder.AddDefaultAuthentication();

        // Add Redis
        var redisConnection = builder.Configuration.GetConnectionString("Redis") ?? "localhost:6379";
        builder.Services.AddSingleton<IConnectionMultiplexer>(sp =>
        {
            var configuration = ConfigurationOptions.Parse(redisConnection, true);
            return ConnectionMultiplexer.Connect(configuration);
        });

        builder.Services.AddSingleton<IBasketRepository, RedisBasketRepository>();

        var eventBusConnectionString = builder.Configuration.GetConnectionString("eventbus") ?? "";
        var eventBus = eventBusConnectionString.StartsWith("Endpoint=sb://", StringComparison.OrdinalIgnoreCase)
            ? builder.AddServiceBusEventBus("eventbus")
            : builder.AddRabbitMqEventBus("eventbus");
        eventBus.AddSubscription<OrderStartedIntegrationEvent, OrderStartedIntegrationEventHandler>()
               .ConfigureJsonOptions(options => options.TypeInfoResolverChain.Add(IntegrationEventContext.Default));
    }
}

[JsonSerializable(typeof(OrderStartedIntegrationEvent))]
partial class IntegrationEventContext : JsonSerializerContext
{

}
