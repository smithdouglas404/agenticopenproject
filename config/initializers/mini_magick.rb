require "mini_magick"

# Ensure ImageMagick reads the project-local policy.xml (websafe)
# ENV["MAGICK_CONFIGURE_PATH"] ||= Rails.root.join("config/imagemagick").to_s

MiniMagick.configure do |config|
  # configure MiniMagick CLI to use ImageMagick (not GraphicsMagick)
  config.graphicsmagick = false
  # also set the MAGICK_CONFIGURE_PATH for the CLI commands
  config.cli_env = {
    "MAGICK_CONFIGURE_PATH" => Rails.root.join("config/imagemagick").to_s
  }
end
