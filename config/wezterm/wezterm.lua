-- https://wezfurlong.org/wezterm/config/lua/keyassignment/
-- https://wezfurlong.org/wezterm/config/default-keys.html
-- https://github.com/yutkat/dotfiles/tree/main/.config/wezterm
-- https://github.com/KevinSilvester/wezterm-config
-- https://github.com/mrjones2014/smart-splits.nvim#wezterm
-- https://github.com/wez/wezterm/discussions/2329

-- NOTE: environment variable WEZTERM_CONFIG_DIR should point to this file
local wezterm = require 'wezterm'

local act = wezterm.action
-- local mux = wezterm.mux
local io = require 'io'
local os = require 'os'

local platform = {
  is_win = string.find(wezterm.target_triple, 'windows') ~= nil,
  is_linux = string.find(wezterm.target_triple, 'linux') ~= nil,
  is_mac = string.find(wezterm.target_triple, 'apple') ~= nil,
}

local sys = require('widgets')

sys.apply_to_config(config, {
  right = {
    sys.battery.charge.widget(),
    sys.cpu.utilization.widget(),
    sys.ram.utilization.widget(),
    sys.network.download.widget(),
    sys.network.upload.widget(),
  },
  separator = { text = "|", color = "#3b4261" },
})

-- Troubleshooting
-- https://wezfurlong.org/wezterm/troubleshooting.html

-- Allow working with both the current release and the nightly
local config = {}
if wezterm.config_builder then
  config = wezterm.config_builder()
end
config.colors = {
  split = '#449999', -- split lines between panes color
}
-- https://wezfurlong.org/wezterm/config/fonts.html
-- https://www.jetbrains.com/lp/mono/
-- https://github.com/microsoft/cascadia-code
-- https://github.com/tonsky/FiraCode
-- https://github.com/adobe-fonts/source-code-pro
-- https://fonts.google.com/specimen/IBM+Plex+Sans

config.font_size = 10

config.disable_default_key_bindings = true
config.hide_tab_bar_if_only_one_tab = true
-- https://wezfurlong.org/wezterm/config/lua/config/debug_key_events.html
config.debug_key_events = false

config.hide_mouse_cursor_when_typing = true
config.pane_focus_follows_mouse = false

config.switch_to_last_active_tab_when_closing_tab = false
config.adjust_window_size_when_changing_font_size = false

-- https://wezfurlong.org/wezterm/faq.html?h=path#im-on-macos-and-wezterm-cannot-find-things-in-my-path
if platform.is_mac then
  config.set_environment_variables = {
    PATH = table.concat({
      wezterm.home_dir .. '/.cargo/bin',
      wezterm.home_dir .. '/bin',
      wezterm.home_dir .. '/.local/share/bob/nvim-bin',
      '/opt/homebrew/bin',
      os.getenv 'PATH',
    }, ':'),
    -- prepend the path to custom binaries
  }
end

local function normalize_path(path)
  local is_win = string.find(wezterm.target_triple, 'windows') ~= nil
  return is_win and path:gsub('\\', '/') or path
end

local home = normalize_path(wezterm.home_dir)
--
-- Common Folder Paths
--
local folders_to_search = {}
if platform.is_win then
  folders_to_search = {
    home .. '/src',
    home .. '/src/oss',
    '/s/eklang-wt/',
    '/s/customerprj/',
  }
else
  folders_to_search = {
    home .. '/src',
    home .. '/src/oss',
  }
end

--
-- Shell Profiles
--
local nushell = wezterm.home_dir .. '/.cargo/bin/nu'
local launch_menu = {}
if platform.is_win then
  -- wezterm.log_info 'on windows'
  config.default_prog = { nushell }
  launch_menu = {
    { label = 'PowerShell Core', args = { 'pwsh' } },
    { label = 'PowerShell Desktop', args = { 'powershell' } },
    { label = 'Command Prompt', args = { 'cmd' } },
    {
      label = 'Visual Studio Prompt',
      args = { 'cmd', ' /k', '"c:\\Program Files\\Microsoft Visual Studio\\2022\\Professional\\Common7\\Tools\\VsDevCmd.bat"' },
    },
    { label = 'Nushell', args = { nushell } },
  }
else
  -- wezterm.log_info 'on mac or linux'
  config.default_prog = { 'nu' }
  launch_menu = {
    { label = 'Bash', args = { 'bash' } },
    { label = 'Nushell', args = { 'nu' } },
    { label = 'Zsh', args = { 'zsh' } },
  }
end
config.launch_menu = launch_menu

-- Styling Inactive Panes
config.inactive_pane_hsb = {
  saturation = 0.5, -- smaller values can make it appear more washed out
  brightness = 1., -- dims or increases the perceived amount of light
}

config.mouse_bindings = {
  --   -- https://dystroy.org/blog/from-terminator-to-wezterm/
  --   -- Disable the default click behavior
  --   {
  --     event = { Up = { streak = 1, button = 'Left' } },
  --     mods = 'NONE',
  --     action = w.action.DisableDefaultAssignment,
  --   },
  --   -- Ctrl-click will open the link under the mouse cursor
  --   {
  --     event = { Up = { streak = 1, button = 'Left' } },
  --     mods = 'CTRL',
  --     action = w.action.OpenLinkAtMouseCursor,
  --   },
  --   -- Disable the Ctrl-click down event to stop programs from seeing it when a URL is clicked
  --   {
  --     event = { Down = { streak = 1, button = 'Left' } },
  --     mods = 'CTRL',
  --     action = w.action.Nop,
  --   },
  {
    event = { Down = { streak = 3, button = 'Left' } },
    action = wezterm.action.SelectTextAtMouseCursor 'SemanticZone',
    mods = 'NONE',
  },
}

local mods = 'CTRL|SHIFT'
local mods2 = 'CTRL|SHIFT|ALT'

local edit_pane_in_nvim = wezterm.action_callback(function(window, pane)
  -- Retrieve the text from the pane
  local text = pane:get_lines_as_text(pane:get_dimensions().scrollback_rows)

  -- Create a temporary file to pass to vim
  local name = os.tmpname()
  local f = io.open(name, 'w+')
  if f == nil then
    wezterm.log_error('failed to open ' .. name)
    return
  end
  f:write(text)
  f:flush()
  f:close()

  window:perform_action(act.SplitHorizontal { args = { 'nu', '-e', 'nvim ' .. name } }, pane)

  -- Wait "enough" time for vim to read the file before we remove it.
  -- The window creation and process spawn are asynchronous wrt. Running
  -- this script and are not awaitable, so we just pick a number.
  --
  -- Note: We don't strictly need to remove this file, but it is nice
  -- to avoid cluttering up the temporary directory.
  wezterm.sleep_ms(1000)
  os.remove(name)
end)

local new_pane = wezterm.action_callback(function(window, pane)
  wezterm.log_info { window, pane }
  local tab = window:active_tab(window)
  local num_panes = #tab:panes_with_info()
  if num_panes == 1 then
    pane:split { direction = 'Right' }
  else
    pane:split { direction = 'Bottom' }
  end
end)

local open_project = wezterm.action_callback(function(window, pane)
  local projects = {}

  for _, folder in ipairs(folders_to_search) do
    wezterm.log_info(folder)
    for _, project in pairs(wezterm.glob(folder .. '/*')) do
      project = normalize_path(project)
      table.insert(projects, { label = project, id = project })
    end
  end

  window:perform_action(
    wezterm.action.InputSelector {
      action = wezterm.action_callback(function(win, _, id, label)
        if not id and not label then
          wezterm.log_info 'Select Project cancelled'
        else
          wezterm.log_info('Selected project: ' .. label)
          win:perform_action(
            wezterm.action.SwitchToWorkspace {
              name = id,
              spawn = {
                cwd = label,
                args = { 'nu', '-e', 'nvim' },
              },
            },
            pane
          )
        end
      end),
      fuzzy = true,
      title = 'Select project',
      choices = projects,
    },
    pane
  )
end)

local break_to_new_tab = wezterm.action_callback(function(_, pane) pane:move_to_new_tab() end)

config.keys = {

  { key = '_', mods = mods, action = wezterm.action.DecreaseFontSize },
  { key = '+', mods = mods, action = wezterm.action.IncreaseFontSize },

  { key = 'z', mods = mods, action = act.TogglePaneZoomState },
  -- { key = 'd',   mods = mods,        action = act.DisableDefaultAssignment },  -- don't remember why

  -- fix ctrl-space not reaching the term https://github.com/wez/wezterm/issues/4055#issuecomment-1694542317
  { key = 'Enter', mods = 'CTRL', action = act.SendKey { key = 'Enter', mods = 'CTRL' } },
  { key = ' ', mods = 'CTRL', action = act.SendKey { key = ' ', mods = 'CTRL' } },
  { key = ',', mods = 'CTRL', action = act.SendKey { key = ',', mods = 'CTRL' } },
  { key = 'm', mods = 'CTRL', action = act.SendKey { key = 'Enter' } },
  { key = 'i', mods = 'CTRL', action = act.SendKey { key = 'Tab' } },
  { key = '[', mods = 'CTRL', action = act.SendKey { key = 'Escape' } },

  -- { key = '^',   mods = "NONE", action = act.SendKey { key = '6', mods = mods.shift_ctrl } },

  -- Main bidings
  { key = 'F9', mods = 'NONE', action = wezterm.action.ToggleAlwaysOnBottom },
  { key = 'F10', mods = 'NONE', action = wezterm.action.ToggleAlwaysOnTop },
  { key = 'F11', mods = 'NONE', action = act.ToggleFullScreen },

  { key = 's', mods = mods, action = act { SplitVertical = { domain = 'CurrentPaneDomain' } } },
  { key = '|', mods = mods, action = act { SplitHorizontal = { domain = 'CurrentPaneDomain' } } },
  { key = 'n', mods = mods, action = new_pane }, -- poor man's zellij New split pane

  { key = 'a', mods = mods, action = act.ActivateCommandPalette }, -- [c]ommands
  { key = 'd', mods = mods, action = act.ShowDebugOverlay },
  { key = 'f', mods = mods, action = act.Search { CaseInSensitiveString = '' } }, -- [f]ind
  { key = 'r', mods = mods, action = act.RotatePanes 'Clockwise' }, -- [r]otate panes
  { key = 'u', mods = mods, action = act.CharSelect }, -- insert [u]nicode character, e.g. emoji

  { key = 'o', mods = mods, action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES|DOMAINS|TABS' } }, -- [o]pen
  { key = 'p', mods = mods, action = open_project },

  { key = '{', mods = mods, action = act.ActivateTabRelative(-1) },
  { key = '}', mods = mods, action = act.ActivateTabRelative(1) },
  { key = '<', mods = mods, action = act.SwitchWorkspaceRelative(-1) },
  { key = '>', mods = mods, action = act.SwitchWorkspaceRelative(1) },

  -- adjust panes
  { key = 'h', mods = mods2, action = act.AdjustPaneSize { 'Left', 5 } },
  { key = 'j', mods = mods2, action = act.AdjustPaneSize { 'Down', 5 } },
  { key = 'k', mods = mods2, action = act.AdjustPaneSize { 'Up', 5 } },
  { key = 'l', mods = mods2, action = act.AdjustPaneSize { 'Right', 5 } },

  { key = 'h', mods = mods, action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = mods, action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = mods, action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = mods, action = act.ActivatePaneDirection 'Right' },

  { key = 'q', mods = mods, action = act.CloseCurrentPane { confirm = false } },

  { key = 'b', mods = mods, action = break_to_new_tab },

  { key = 'e', mods = mods, action = edit_pane_in_nvim },

  { key = 'c', mods = mods, action = act.CopyTo 'ClipboardAndPrimarySelection' },
  { key = 'v', mods = mods, action = act.PasteFrom 'Clipboard' },
}

config.switch_to_last_active_tab_when_closing_tab = true
config.exit_behavior = 'CloseOnCleanExit'

config.hyperlink_rules = {
  -- Matches: a URL in parens: (URL)
  { regex = '\\((\\w+://\\S+)\\)', format = '$1', highlight = 1 },
  -- Matches: a URL in brackets: [URL]
  { regex = '\\[(\\w+://\\S+)\\]', format = '$1', highlight = 1 },
  -- Matches: a URL in curly braces: {URL}
  { regex = '\\{(\\w+://\\S+)\\}', format = '$1', highlight = 1 },
  -- Matches: a URL in angle brackets: <URL>
  { regex = '<(\\w+://\\S+)>', format = '$1', highlight = 1 },
  -- Then handle URLs not wrapped in brackets
  { regex = '[^(]\\b(\\w+://\\S+[)/a-zA-Z0-9-]+)', format = '$1', highlight = 1 },
  -- implicit mailto link
  { regex = '\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b', format = 'mailto:$0', highlight = 1 },
}

return config
