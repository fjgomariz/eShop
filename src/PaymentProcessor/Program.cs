var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

var eventBusConnectionString = builder.Configuration.GetConnectionString("EventBus") ?? "";
var eventBus = eventBusConnectionString.StartsWith("Endpoint=sb://", StringComparison.OrdinalIgnoreCase)
    ? builder.AddServiceBusEventBus("EventBus")
    : builder.AddRabbitMqEventBus("EventBus");
eventBus.AddSubscription<OrderStatusChangedToStockConfirmedIntegrationEvent, OrderStatusChangedToStockConfirmedIntegrationEventHandler>();

builder.Services.AddOptions<PaymentOptions>()
    .BindConfiguration(nameof(PaymentOptions));

var app = builder.Build();

app.MapDefaultEndpoints();

await app.RunAsync();
