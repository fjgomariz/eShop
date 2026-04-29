namespace eShop.WebApp.Services;

public class OrderStatusNotificationService(ILogger<OrderStatusNotificationService> logger)
{
    // Locking manually because we need multiple values per key, and only need to lock very briefly
    private readonly object _subscriptionsLock = new();
    private readonly Dictionary<string, HashSet<Subscription>> _subscriptionsByBuyerId = new();

    public IDisposable SubscribeToOrderStatusNotifications(string buyerId, Func<Task> callback)
    {
        var subscription = new Subscription(this, buyerId, callback);

        lock (_subscriptionsLock)
        {
            if (!_subscriptionsByBuyerId.TryGetValue(buyerId, out var subscriptions))
            {
                subscriptions = [];
                _subscriptionsByBuyerId.Add(buyerId, subscriptions);
            }

            subscriptions.Add(subscription);
        }

        return subscription;
    }

    public Task NotifyOrderStatusChangedAsync(string buyerId)
    {
        Subscription[] subscriptions;
        lock (_subscriptionsLock)
        {
            if (!_subscriptionsByBuyerId.TryGetValue(buyerId, out var subs))
            {
                return Task.CompletedTask;
            }
            // Copy under the lock so we don't invoke callbacks while holding it
            subscriptions = [.. subs];
        }

        // Fire-and-forget: the Service Bus event handler must not wait for all UI
        // subscribers to finish before the message is acknowledged, otherwise slow
        // or disconnected Blazor circuits will cause receive-lock timeouts.
        foreach (var subscription in subscriptions)
        {
            _ = NotifySafeAsync(subscription);
        }

        return Task.CompletedTask;
    }

    private async Task NotifySafeAsync(Subscription subscription)
    {
        try
        {
            await subscription.NotifyAsync();
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Error notifying order status change subscriber");
        }
    }

    private void Unsubscribe(string buyerId, Subscription subscription)
    {
        lock (_subscriptionsLock)
        {
            if (_subscriptionsByBuyerId.TryGetValue(buyerId, out var subscriptions))
            {
                subscriptions.Remove(subscription);
                if (subscriptions.Count == 0)
                {
                    _subscriptionsByBuyerId.Remove(buyerId);
                }
            }
        }
    }

    private class Subscription(OrderStatusNotificationService owner, string buyerId, Func<Task> callback) : IDisposable
    {
        public Task NotifyAsync()
        {
            return callback();
        }

        public void Dispose()
            => owner.Unsubscribe(buyerId, this);
    }
}
