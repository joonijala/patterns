# frozen_string_literal: true

Patterns::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # base url for emails
  config.action_mailer.default_url_options = { host: ENV['PRODUCTION_SERVER'] }

  # Code is not reloaded between requests.
  config.cache_classes = true
  config.hosts << ENV['PRODUCTION_SERVER']

  config.action_mailbox.ingress = :mandrill
  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both thread web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like nginx, varnish or squid.
  config.action_dispatch.rack_cache = true

  # Disable Rails's static asset server (Apache or nginx will already do this).
  config.serve_static_files = false

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Whether to fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Generate digests for assets URLs.
  config.assets.digest = true

  # Version of your assets, change this if you want to expire all your assets.
  config.assets.version = '1.0'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Store uploaded files on the local file system (see config/storage.yml for options)
  config.active_storage.service = :amazon

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]
  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Prepend all log lines with the following tags.
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups.
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production.
  config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] || 'redis://localhost:6379/1/', namespace: 'patterns-cache' }
  config.session_store :cookie_store
  # config.cache_store = :redis_cache_store, driver: :hiredis, namespace: 'patterns-cache',timeout: 1

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets.
  # application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
  # config.assets.precompile += %w( search.js )

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = true

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  # config.active_support.deprecation = :notify

  # Disable automatic flushing of the log to improve performance.
  # config.autoflush_log = false

  # Set to :debug to see everything in the log.
  config.log_level = :info
  config.lograge.enabled = true
  # this doesn't do what i had hoped it would do.
  config.lograge.custom_options = lambda do |event|
    { remote_ip: event.payload[:remote_ip] }
  end
  # Analytics
  config.google_analytics_enabled = true

  config.action_mailer.smtp_settings = {
    address: Rails.application.credentials.smtp[:host],
    port: Rails.application.credentials.smtp[:port],
    user_name: Rails.application.credentials.smtp[:username],
    password: Rails.application.credentials.smtp[:password]
  }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true # we want to know whats up
  config.action_mailer.default charset: 'utf-8'

  config.middleware.use Rack::TwilioWebhookAuthentication, Rails.application.credentials.twilio[:auth_token], '/receive_text/index'

  # 12 factor
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  if ENV['RAILS_LOG_TO_STDOUT'].present?
    logger           = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end
end
