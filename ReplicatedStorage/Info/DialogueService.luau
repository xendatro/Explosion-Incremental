--[[
================================================================================
	DIALOGUE SYSTEM
================================================================================

	A lightweight dialogue system built on top of xenterface. Displays a
	dialogue frame on-screen with a speaker name and message. Supports
	per-player and all-player control from the server, and direct control
	from the client.

	The system is safe to include in any game — if the UI elements are not
	present, all calls silently do nothing.


--------------------------------------------------------------------------------
	DESIGNER SETUP (Studio)
--------------------------------------------------------------------------------

	PAGE SETUP (open/close)

	    Tag your dialogue frame(s) with "Page" and set these attributes:
	        PageGroup = "Dialogue"
	        PageId    = "Main"

	    Define your open/close animations via the Active and Inactive
	    attributes (or a Preset). The system fires the "Dialogue" controller
	    — any Page in that group with PageId "Main" will respond.
	    You can have as many Pages in the group as you like.

	ELEMENT SETUP (name & text)

	    Set ElementId attributes on your TextLabels:
	        ElementId = "DialogueName"   — displays the speaker's name
	        ElementId = "DialogueText"   — displays the message (typewriter)


--------------------------------------------------------------------------------
	CLIENT API    (ReplicatedStorage.Services.DialogueService)
--------------------------------------------------------------------------------

	DialogueService:Show(name?, text?)
		Opens the frame. If name and/or text are provided, sets them first.
		Omit both to open the frame without touching the labels.

	DialogueService:Hide()
		Closes the frame.

	DialogueService:Set(name?, text?)
		Updates whichever labels are provided, without opening or closing.
		Cancels any in-progress typewriter tween and starts a new one.
		Either param can be omitted to leave that label unchanged.

	DialogueService:Open()
		Opens the frame (plays Active animation).

	DialogueService:Close()
		Closes the frame (plays Inactive animation).


--------------------------------------------------------------------------------
	SERVER API    (ServerStorage.Services.DialogueService)
--------------------------------------------------------------------------------

	DialogueService:Show(player, name, text)
		Shows dialogue to a specific player.

	DialogueService:ShowAll(name, text)
		Shows dialogue to all players.

	DialogueService:Hide(player)
		Hides dialogue for a specific player.

	DialogueService:HideAll()
		Hides dialogue for all players.


--------------------------------------------------------------------------------
	REMOTES
--------------------------------------------------------------------------------

	Created automatically at runtime under:
	    ReplicatedStorage.Communication.Dialogue.Show    (RemoteEvent)
	    ReplicatedStorage.Communication.Dialogue.Hide    (RemoteEvent)


--------------------------------------------------------------------------------
	EXAMPLE USAGE
--------------------------------------------------------------------------------

	-- Server: NPC speaks to a player
	local DialogueService = require(ServerStorage.Services.DialogueService)
	DialogueService:Show(player, "Old Man", "You shouldn't be here...")

	-- Server: broadcast to all players
	DialogueService:ShowAll("System", "The ritual has begun.")

	-- Server: hide for everyone
	DialogueService:HideAll()

	-- Client: convenience (set + open in one call)
	local DialogueService = require(ReplicatedStorage.Services.DialogueService)
	DialogueService:Show("Narrator", "Something stirs in the dark.")
	task.wait(3)
	DialogueService:Hide()

	-- Client: open first, then set content separately
	DialogueService:Show()
	DialogueService:Set("Old Man", "You shouldn't be here...")
	task.wait(4)
	DialogueService:Hide()

================================================================================
]]

return {}
