local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.font = wezterm.font_with_fallback {
--'JetBrainsMono Nerd Font Mono',
    'D2Coding',
}

config.font_size = 16.0

return config
