# ~/.ipython/profile_default/ipython_config.py

# import IPython
# %edit {IPython.paths.locate_profile()}/ipython_config.py

c = get_config()  # noqa

c.TerminalInteractiveShell.editing_mode = "vi"
c.TerminalInteractiveShell.true_color = True
c.TerminalInteractiveShell.confirm_exit = True

c.TerminalInteractiveShell.display_completions = "readlinelike"

c.PlainTextFormatter.max_width = 120
c.PlainTextFormatter.max_seq_length = 0  # unlimited

c.TerminalInteractiveShell.editor = "nvim"

# Startup
c.InteractiveShellApp.extensions = ["autoreload"]

c.InteractiveShellApp.exec_lines = [
    "%autoreload 2",
    "import os, sys, re, json, math, subprocess, sys, collections, itertools, pathlib",
    "from pathlib import Path",
    "from pprint import pprint",
]

# Matplotlib  (uncomment one backend)
# c.InteractiveShellApp.matplotlib = "inline"   # static images in notebook/qtconsole
# c.InteractiveShellApp.matplotlib = "widget"   # interactive ipympl widgets
# c.InteractiveShellApp.matplotlib = "tk"       # separate Tk window
# c.InteractiveShellApp.matplotlib = "qt"       # separate Qt window

# Logging

# c.InteractiveShell.logstart = True
# c.InteractiveShell.logfile = "~/.ipython/logs/session_%Y%m%d_%H%M%S.py"
# c.InteractiveShell.logappend = True           # append if file already exists
# c.InteractiveShell.logmode = "rotate"         # rotate | append | backup | over


from pathlib import Path
print(f'loaded {Path(__file__)}')

