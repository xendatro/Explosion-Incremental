--[[
================================================================================
	CURTAIN SYSTEM
================================================================================

	A dynamic transition screen system built on top of xenterface. Curtains
	are full-screen overlays (fades, wipes, etc.) controlled entirely through
	the xenterface Page/Controller system. The service has no knowledge of
	the UI hierarchy — all visual design is handled in Studio.

	The system is safe to include in any game — if no curtain pages are
	present, all calls silently do nothing.


--------------------------------------------------------------------------------
	DESIGNER SETUP (Studio)
--------------------------------------------------------------------------------

	Tag each curtain frame with "Page" and set these attributes:
	    PageGroup = "Curtain"
	    PageId    = "YourCurtainName"   (e.g. "Fade", "Wipe", "Iris")

	Define open/close animations via the Active and Inactive attributes
	(or a Preset). You can have as many curtain designs as you like —
	each is identified by its PageId.


--------------------------------------------------------------------------------
	CLIENT API    (ReplicatedStorage.Services.CurtainService)
--------------------------------------------------------------------------------

	CurtainService:Show(pageId)
		Shows the curtain with the given pageId (plays its Active animation).

	CurtainService:Hide()
		Hides whatever curtain is currently active (plays its Inactive animation).

	CurtainService:Play(pageId, duration)
		Shows the curtain, waits duration seconds, then hides it.


--------------------------------------------------------------------------------
	SERVER API    (ServerStorage.Services.CurtainService)
--------------------------------------------------------------------------------

	CurtainService:Show(player, pageId)
		Shows a curtain for a specific player.

	CurtainService:ShowAll(pageId)
		Shows a curtain for all players.

	CurtainService:Hide(player)
		Hides the active curtain for a specific player.

	CurtainService:HideAll()
		Hides the active curtain for all players.

	CurtainService:Play(player, pageId, duration)
		Plays a curtain for a specific player.

	CurtainService:PlayAll(pageId, duration)
		Plays a curtain for all players.


--------------------------------------------------------------------------------
	REMOTES
--------------------------------------------------------------------------------

	Created automatically at runtime under:
	    ReplicatedStorage.Communication.Curtain.Show    (RemoteEvent)
	    ReplicatedStorage.Communication.Curtain.Hide    (RemoteEvent)
	    ReplicatedStorage.Communication.Curtain.Play    (RemoteEvent)


--------------------------------------------------------------------------------
	EXAMPLE USAGE
--------------------------------------------------------------------------------

	-- Server: fade transition for one player
	local CurtainService = require(ServerStorage.Services.CurtainService)
	CurtainService:Play(player, "Fade", 1.5)

	-- Server: wipe transition for all players
	CurtainService:PlayAll("Wipe", 2)

	-- Server: manual control
	CurtainService:ShowAll("Fade")
	task.wait(3)
	CurtainService:HideAll()

	-- Client: local transition
	local CurtainService = require(ReplicatedStorage.Services.CurtainService)
	CurtainService:Play("Fade", 1.5)

================================================================================
]]

return {}
