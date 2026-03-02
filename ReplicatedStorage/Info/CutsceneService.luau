--[[
================================================================================
	CUTSCENE SYSTEM
================================================================================

	A client-side cutscene player for Moon Animator exports. Cutscenes are
	exported from Moon Animator as StringValue instances (JSON + keyframe
	folders) and played back frame-by-frame via RunService.BindToRenderStep.

	The system supports rig animation, property animation, camera control,
	and named marker callbacks. It does not use Moon Animator's runtime
	plugin — everything is self-contained.

	Cutscenes are stored at:
	    ReplicatedStorage.Cutscenes.[CutsceneName]   (StringValue)


--------------------------------------------------------------------------------
	CUTSCENESERVICE API    (ReplicatedStorage.Services.CutsceneService)
--------------------------------------------------------------------------------

	CutsceneService:Create(settings) → Cutscene
		Creates and configures a Cutscene instance ready to play.
		Returns the Cutscene so you can attach callbacks before calling :Play().

		settings = {
		    Name:    string,    -- name of the StringValue in ReplicatedStorage.Cutscenes
		    Parent:  Instance?, -- search root for instance paths (default: workspace)
		    Rigs: {
		        [rigName: string]: {
		            Model:  Model,    -- the model to use for this rig
		            Clone:  boolean?, -- clone Model before using it (default: false)
		            CFrame: CFrame?,  -- pivot here and play animation relative to this
		        }
		    }?,
		    Objects: {
		        [objectName: string]: {
		            Model:  Instance?, -- the part/model to use (optional, see below)
		            Clone:  boolean?,  -- clone it before using (default: false)
		            CFrame: CFrame?,   -- pivot here and play animation relative to this
		        }
		    }?
		}

		Both Rigs and Objects share the same shape and behavior. Rigs is for
		character rigs (joint animation); Objects is for anything else animated
		via property tracks (CFrame, Transparency, etc.).

		Model is optional in Objects. If omitted, the instance is not replaced —
		only the CFrame offset is applied. This is useful for the Camera, which
		is always resolved automatically and never needs replacing:
		    Objects = { ["Camera"] = { CFrame = CFrame.new(0, 5, 10) } }

		Items not listed in either table are resolved automatically as children
		of Parent.

		CFrame behaviour:
		    - Specified → the animation plays relative to this CFrame. The first
		      keyframe's world position becomes the new origin, so the whole path
		      shifts accordingly. For Rigs, the model is also pivoted here.
		    - Not specified → raw absolute world positions from Moon Animator are
		      used as-is. Correct for cutscenes that always play in the same spot.


--------------------------------------------------------------------------------
	CUTSCENE API    (ReplicatedStorage.Classes.Cutscene)
--------------------------------------------------------------------------------

	Cutscene.new(file: StringValue, folder: Instance?) → Cutscene
		Low-level constructor. Prefer CutsceneService:Create() for most cases.
		file   = the exported Moon Animator StringValue
		folder = optional search root for instance paths (equivalent to "map")

	Cutscene:Play()
		Starts playback from the beginning. Resets markers and timeElapsed.

	Cutscene:Stop()
		Stops playback and restores the camera to CameraType.Custom.

	Cutscene:Find(name: string) → number?
		Returns the object index for an item, matched by instance name or ItemType.
		Searching "Camera" works even though the instance is named "CurrentCamera".
		    cs:Find("Player")   -- by instance name
		    cs:Find("Camera")   -- by ItemType

	Cutscene:Replace(idx: number, newInstance: Instance)
		Swaps the resolved instance for a given object index.
		Automatically re-parses rig motor references for the new instance.
		    cs:Replace(cs:Find("Player"), player.Character)

	Cutscene:SetOffset(idx: number, origin: CFrame)
		Sets a world-space origin for an object's CFrame track so the animation
		plays relative to origin instead of the absolute recorded positions.
		Silently does nothing if the object has no CFrame track.
		Called automatically by CutsceneService when CFrame is provided in settings.

	Cutscene:OnMarker(name: string, callback: (value: string?) -> nil) → () -> nil
		Registers a callback to fire when a named marker is reached during playback.
		Returns a disconnect function.
		    local disconnect = cs:OnMarker("Camera", function(value) ... end)

	Cutscene.Finished (BindableEvent)
		Fires when the cutscene reaches its end naturally (not on :Stop()).
		    cs.Finished.Event:Connect(function() ... end)

	Cutscene:Destroy()
		Stops playback and cleans up the Finished BindableEvent.


--------------------------------------------------------------------------------
	NOTES
--------------------------------------------------------------------------------

	Camera
		Use cs:Find("Camera") to get the camera's index — it matches by ItemType
		so you don't need to know the internal name "CurrentCamera".
		CFrame and FieldOfView are animated natively. CameraType is set to
		Scriptable during playback and restored to Custom on :Stop().
		AttachToPart and LookAtPart tracks are skipped — instance referents do
		not survive export. To offset the camera path, pass CFrame in Objects:
		    Objects = { ["Camera"] = { CFrame = CFrame.new(0, 5, 10) } }

	Markers
		MarkerTrack data is parsed from the export. Each marker has a name and
		an optional string value (the "Val" field in Moon Animator).
		Multiple callbacks can be registered for the same marker name.
		Markers are reset on every :Play() call.

	Rigs vs. Objects (CFrame animation)
		Rig joint animation is always relative to the rig's position in the world,
		so rigs can be placed anywhere. Plain parts/models animated via a CFrame
		property track store absolute world positions. Specifying CFrame in Objects
		offsets the entire path so it plays relative to the given origin instead.

	Instances not in the scene
		If an instance is not already a child of Parent, specify it with
		Clone = true so the service clones it into the scene before playing.
		Cloned instances are parented to Parent.


--------------------------------------------------------------------------------
	EXAMPLE USAGE
--------------------------------------------------------------------------------

	local CutsceneService = require(ReplicatedStorage.Services.CutsceneService)

	local cs = CutsceneService:Create({
	    Name    = "Intro",
	    Parent  = workspace.Map,
	    Rigs    = {
	        -- player character: already in world, reposition and offset animation
	        ["Player"] = {
	            Model  = player.Character,
	            CFrame = CFrame.new(0, 0, 10),
	        },
	        -- NPC stored in ReplicatedStorage: clone into the scene
	        ["Caden"] = {
	            Model  = ReplicatedStorage.NPCs.Caden,
	            Clone  = true,
	            CFrame = CFrame.new(5, 0, 10),
	        },
	        -- "Effects" not listed → found automatically as child of workspace.Map
	    },
	    Objects = {
	        -- prop stored in ReplicatedStorage: clone and position it
	        ["PropDoor"] = {
	            Model  = ReplicatedStorage.Props.Door,
	            Clone  = true,
	            CFrame = CFrame.new(10, 0, 5),
	        },
	        -- camera path offset — no Model needed, instance is always resolved
	        ["Camera"] = {
	            CFrame = CFrame.new(0, 5, 10),
	        },
	    },
	})

	cs:OnMarker("DialogueStart", function(value)
	    DialogueService:Play(value)
	end)

	cs.Finished.Event:Connect(function()
	    cs:Destroy()
	end)

	cs:Play()

================================================================================
]]

return {}
