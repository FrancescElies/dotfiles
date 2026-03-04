# Beast Mode

Beast Mode is a custom chat mode for VS Code agent that adds an opinionated workflow to the agent, including use of a todo list, extensive internet research capabilities, planning, tool usage instructions and more. Designed to be used with 4.1, although it will work with any model.

Below you will find the Beast Mode prompt in various versions - starting with the most recent - 3.1

## Installation Instructions

* Go to the "agent" dropdown in VS Code chat sidebar and select "Configure Modes". 
* Select "Create new custom chat mode file"
* Select "User Data Folder"
* Give it a name (Beast Mode)
* Paste in the content of beastmode.chatmode.md

"Beast Mode" will now appear as a mode in your "Agent" dropdown.

## Recommended VS Code Settings

Because agent mode depends heavily on tool calling, it's recommended that you turn on "Auto Approve" in the settings. Note that this will allow the agent to execute commands in your terminal without asking for permission. I also recommend bumping "Max Requests" to 100 to keep the agent working on long running tasks without asking you if you want it to continue. You can do that through the settings UI or via your user settings json file...

```json
"chat.tools.autoApprove": true
"chat.agent.maxRequests": 100
```

## UI Instructions

I recommend being quite opinionated about your ui with something like shadcn. I've inlcuded an instructions file at the bottom of this gist that you can add to `.github/instructions`. Combined with Beast Mode, it will crawl the shadcn docs to do design. It's quite good!