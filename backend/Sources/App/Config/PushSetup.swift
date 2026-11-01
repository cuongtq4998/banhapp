import Vapor

/// Picks the `PushSender` for the configured provider. `live` builds the APNs
/// and FCM clients over the application's HTTP client; they were written from
/// the providers' public documentation and never ran against the real services
/// (no credentials exist yet, dev-guide).
func configurePush(_ app: Application, config: AppConfig) throws {
    switch config.push.provider {
    case .off:
        app.logger.warning("Push is off (PUSH_PROVIDER); new orders are not announced to phones")
    case .recording:
        app.services.push = RecordingPushSender()
    case .live:
        guard let apns = config.push.apns, let fcm = config.push.fcm else { throw AppConfig.Failure.missing(AppConfig.Key.pushProvider) }
        let transport = AsyncHTTPOutboundTransport(client: app.http.client.shared)
        let clock = app.services.clock
        app.services.push = LivePushSender(
            apns: try ApnsPushSender(credentials: apns, transport: transport, clock: clock),
            fcm: try FcmPushSender(credentials: fcm, transport: transport, clock: clock)
        )
    }
}
