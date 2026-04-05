# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.

threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

environment ENV.fetch("RAILS_ENV", "development")

# Render expects the app to listen on 0.0.0.0:$PORT.
app_port = Integer(ENV.fetch("PORT", 3000))
bind "tcp://0.0.0.0:#{app_port}"

plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
