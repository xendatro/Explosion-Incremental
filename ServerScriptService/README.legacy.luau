--[[

You will be helping me create a game called 50 PLAYER GUESS THE DRAWING

First, let me familiarize you with the structure of this game.

ReplicatedStorage - Storage for client and server stuff

ReplicatedStorage.Services - Services are interfaces/modules used to control a 
specific, major aspect of the game. As you can see, TagService already exists,
and it's used as a pipeline for automatically linking tagged instances to
modules (usually classes). 

ReplicatedStorage.Classes - Classes are any class in the form of Roblox's class
syntax. These might be used through Tagger, they might not. Please observe the 
ExampleClass file. Please take note of syntax. Please take note of how
connections should be handled. Any connections should be stored in self.Connections
which is created from a local function called setUpConnections.

ReplicatedStorage.Config - Configs are any predefined "settings" that relate
to a certain topic. Note ExampleConfig, which is named by the topic "Example" 
followed by "Config". It returns back only the table.

ReplicatedStoroage.Communication - This is where any RemoteEvents or RemoteFunctions
will be stored. This folder is organized by subfolders which describe what the topic
is about, which contain RemoteEvents or RemoteFunctions that are actions.

ServerStorage - Storage for server stuff specifically. If something should not be
revealed to the client at all, keep it here.

ServerStorage.Services - These are the same as ReplicatedStorage.Services, but
they are exclusively server.

ServerStorage.Classes - These are the same as ReplicatedStorage.Classes, but they
are exclusively server.

ServerStorage.Config - These are the same as ReplicatedStorage.Config, but they
are exclusively server.

ALL Services (unless specifically changed) are self initializing as a result of Tagger 
in modules from the Init in either StarterPlayerScripts (client) or ServerScriptService
(server). Therefore, there is no reason to ever make an :Init() method on any
service. It is fine to just put the connections at the bottom.

Now let's talk about how this game will work (from the player's perspective).

This game will function like skribbl.io, which is a game where one player
draws a prompt while other players guess it. This process continues in a loop
indefinitely. By guessing correctly, players will end gems, which they will
then be able to spend on cosmetics (different physical boards).

]]