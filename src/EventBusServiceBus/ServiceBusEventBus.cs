using System.Diagnostics;
using System.Diagnostics.CodeAnalysis;
using Azure.Messaging.ServiceBus;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using OpenTelemetry;
using OpenTelemetry.Context.Propagation;

namespace eShop.EventBusServiceBus;

/// <summary>
/// Azure Service Bus implementation of <see cref="IEventBus"/>.
/// Uses topics (one per event type) with per-service subscriptions for a pub/sub pattern.
/// </summary>
public sealed class ServiceBusEventBus(
    ILogger<ServiceBusEventBus> logger,
    IServiceProvider serviceProvider,
    IOptions<EventBusOptions> options,
    IOptions<EventBusSubscriptionInfo> subscriptionOptions,
    ServiceBusClient serviceBusClient) : IEventBus, IAsyncDisposable, IHostedService
{
    private static readonly TextMapPropagator s_propagator = Propagators.DefaultTextMapPropagator;
    private static readonly ActivitySource s_activitySource = new("eShop.EventBusServiceBus");

    private readonly string _subscriptionName = options.Value.SubscriptionClientName;
    private readonly EventBusSubscriptionInfo _subscriptionInfo = subscriptionOptions.Value;
    private readonly List<ServiceBusProcessor> _processors = [];

    public async Task PublishAsync(IntegrationEvent @event)
    {
        var topicName = @event.GetType().Name;

        if (logger.IsEnabled(LogLevel.Trace))
        {
            logger.LogTrace("Publishing event {EventName} ({EventId}) to Service Bus topic", topicName, @event.Id);
        }

        await using var sender = serviceBusClient.CreateSender(topicName);

        var body = SerializeMessage(@event);
        var message = new ServiceBusMessage(body)
        {
            MessageId = @event.Id.ToString(),
            Subject = topicName,
        };

        var activityName = $"{topicName} publish";
        using var activity = s_activitySource.StartActivity(activityName, ActivityKind.Producer);

        ActivityContext contextToInject = activity?.Context ?? Activity.Current?.Context ?? default;

        s_propagator.Inject(
            new PropagationContext(contextToInject, Baggage.Current),
            message.ApplicationProperties,
            static (props, key, value) => props[key] = value);

        SetActivityTags(activity, topicName, "publish");

        try
        {
            await sender.SendMessageAsync(message);
        }
        catch (Exception ex)
        {
            activity?.SetExceptionTags(ex);
            throw;
        }
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        logger.LogInformation("Starting Azure Service Bus event bus processors");

        foreach (var (eventName, _) in _subscriptionInfo.EventTypes)
        {
            try
            {
                var processor = serviceBusClient.CreateProcessor(
                    topicName: eventName,
                    subscriptionName: _subscriptionName,
                    new ServiceBusProcessorOptions
                    {
                        MaxConcurrentCalls = 1,
                        AutoCompleteMessages = false,
                    });

                processor.ProcessMessageAsync += args => OnMessageReceived(args, eventName);
                processor.ProcessErrorAsync += OnProcessError;

                await processor.StartProcessingAsync(cancellationToken);
                _processors.Add(processor);

                logger.LogInformation("Started processor for topic {TopicName}, subscription {Subscription}", eventName, _subscriptionName);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to start processor for topic {TopicName}", eventName);
            }
        }
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        logger.LogInformation("Stopping Azure Service Bus event bus processors");

        foreach (var processor in _processors)
        {
            await processor.StopProcessingAsync(cancellationToken);
        }
    }

    public async ValueTask DisposeAsync()
    {
        foreach (var processor in _processors)
        {
            await processor.DisposeAsync();
        }
    }

    private async Task OnMessageReceived(ProcessMessageEventArgs args, string eventName)
    {
        static IEnumerable<string> ExtractTraceContext(IReadOnlyDictionary<string, object> props, string key)
        {
            if (props.TryGetValue(key, out var value) && value is string strValue)
            {
                return [strValue];
            }
            return [];
        }

        var parentContext = s_propagator.Extract(default, args.Message.ApplicationProperties, ExtractTraceContext);
        Baggage.Current = parentContext.Baggage;

        var activityName = $"{eventName} receive";
        using var activity = s_activitySource.StartActivity(activityName, ActivityKind.Consumer, parentContext.ActivityContext);
        SetActivityTags(activity, eventName, "receive");

        var message = args.Message.Body.ToString();

        try
        {
            activity?.SetTag("message", message);

            if (message.Contains("throw-fake-exception", StringComparison.InvariantCultureIgnoreCase))
            {
                throw new InvalidOperationException($"Fake exception requested: \"{message}\"");
            }

            await ProcessEvent(eventName, message);
            await args.CompleteMessageAsync(args.Message);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Error processing Service Bus message \"{Message}\"", message);
            activity?.SetExceptionTags(ex);

            // Dead-letter the message so it doesn't block the queue
            await args.DeadLetterMessageAsync(args.Message, "ProcessingError", ex.Message);
        }
    }

    private Task OnProcessError(ProcessErrorEventArgs args)
    {
        logger.LogError(args.Exception, "Service Bus error on {EntityPath}: {ErrorSource}", args.EntityPath, args.ErrorSource);
        return Task.CompletedTask;
    }

    private async Task ProcessEvent(string eventName, string message)
    {
        if (logger.IsEnabled(LogLevel.Trace))
        {
            logger.LogTrace("Processing Service Bus event: {EventName}", eventName);
        }

        await using var scope = serviceProvider.CreateAsyncScope();

        if (!_subscriptionInfo.EventTypes.TryGetValue(eventName, out var eventType))
        {
            logger.LogWarning("Unable to resolve event type for event name {EventName}", eventName);
            return;
        }

        var integrationEvent = DeserializeMessage(message, eventType);

        foreach (var handler in scope.ServiceProvider.GetKeyedServices<IIntegrationEventHandler>(eventType))
        {
            await handler.Handle(integrationEvent);
        }
    }

    private static void SetActivityTags(Activity activity, string topicName, string operation)
    {
        if (activity is not null)
        {
            activity.SetTag("messaging.system", "servicebus");
            activity.SetTag("messaging.destination_kind", "topic");
            activity.SetTag("messaging.operation", operation);
            activity.SetTag("messaging.destination.name", topicName);
        }
    }

    [UnconditionalSuppressMessage("Trimming", "IL2026:RequiresUnreferencedCode",
        Justification = "The 'JsonSerializer.IsReflectionEnabledByDefault' feature switch, which is set to false by default for trimmed .NET apps, ensures the JsonSerializer doesn't use Reflection.")]
    [UnconditionalSuppressMessage("AOT", "IL3050:RequiresDynamicCode", Justification = "See above.")]
    private IntegrationEvent DeserializeMessage(string message, Type eventType)
    {
        return JsonSerializer.Deserialize(message, eventType, _subscriptionInfo.JsonSerializerOptions) as IntegrationEvent;
    }

    [UnconditionalSuppressMessage("Trimming", "IL2026:RequiresUnreferencedCode",
        Justification = "The 'JsonSerializer.IsReflectionEnabledByDefault' feature switch, which is set to false by default for trimmed .NET apps, ensures the JsonSerializer doesn't use Reflection.")]
    [UnconditionalSuppressMessage("AOT", "IL3050:RequiresDynamicCode", Justification = "See above.")]
    private byte[] SerializeMessage(IntegrationEvent @event)
    {
        return JsonSerializer.SerializeToUtf8Bytes(@event, @event.GetType(), _subscriptionInfo.JsonSerializerOptions);
    }
}
