/*
	Autosplitter for Species Unknown.
	Includes the ability to automatically start, split, and reset.
	Configurable settings.

	By daltone_21 on Discord.

	Todo:
		- Add splitting support for enemy phase changes
		- Add component support for enemy on beginning a mission
*/

state("SpeciesUnknown-Win64-Shipping") {}

startup
{
	// Start settings.
	settings.Add("start", true, "Start Settings");

	settings.CurrentDefaultParent = "start";
	settings.Add("start_OpenShipDoor", true, "Open Ship Door");
	
	settings.CurrentDefaultParent = null;

	// Split settings.
	settings.Add("split", true, "Split Settings");
	
	settings.CurrentDefaultParent = "split";
	settings.Add("split_CompleteAnyObjective", true, "Complete Any Objective");
	settings.Add("split_CompleteLastObjective", true, "Complete Last Objective");
	settings.Add("split_CompleteSectionGoal", true, "Complete Section Goal (Keypasses, Pipes, Airlock, etc.)");
	
	settings.CurrentDefaultParent = null;

	// Reset settings.
	settings.Add("reset", false, "Reset Settings");
	
	settings.CurrentDefaultParent = "reset";
	settings.Add("reset_GoToLobby", false, "Go To Lobby");
	
	settings.CurrentDefaultParent = null;
}

init
{
	// Offsets of classes possible to change with updates. The value of PARENT_CHILD is the offset of CHILD from PARENT.

	vars.UWORLD_MYGAMESTATE = 0x1B0;

	vars.MYGAMESTATE_GAMEMANAGER = 0x350;
	vars.MYGAMESTATE_MONSTERENUM = 0x5B9;

	vars.GAMEMANAGER_MONSTER = 0x2D0;
	vars.GAMEMANAGER_PLAYERARRAY = 0x2D8;

	vars.CHARACTER_MYPLAYERSTATE = 0x2D0;
	vars.CHARACTER_INTERACTINGACTOR = 0xCB8;
	vars.CHARACTER_MYPLAYERCONTROLLER = 0xCC0;

	vars.MYPLAYERSTATE_OBJECTIVECOUNT = 0x410;
	vars.MYPLAYERSTATE_OLDOBJECTIVE = 0x43C;

	vars.MYPLAYERCONTROLLER_INWIDGETTOFOCUS = 0x7E0;

	vars.LEVERSHIP_ISUSED = 0x328;
	vars.LEVERSHIP_ACTIVATEDONCE = 0x348;

	vars.CONSOLEKEYPASS_MAX = 0x4B8;
	vars.CONSOLEKEYPASS_CURRENT = 0x4BC;
	
	vars.REACTORCONTROLTERMINAL_FINISHED = 0x4A9;

	vars.GAZCONTROLTERMINAL_PUZZLE = 0x490;
	vars.PUZZLE_PURGE = 0x4E8;

	// Function declarations.

	vars.getFNameToString = (Func<IntPtr, string>)((UObjectAddress) => {

		if (UObjectAddress == IntPtr.Zero) return null;

		IntPtr FName = IntPtr.Add(UObjectAddress, 0x18);
		uint comparisonID = memory.ReadValue<uint>(FName);

		ushort blockKey = (ushort)(comparisonID >> 16);
		ushort innerKey = (ushort)comparisonID;
		int blockStartOffset = 0x30;
		
		IntPtr blockPtr = IntPtr.Add(vars.FNamePoolBase, ((int)(blockKey) + 2) * 8 + blockStartOffset);
		ulong FNameEntryAddress = memory.ReadValue<ulong>(blockPtr) + 2 * (ulong)innerKey;

		ushort Header = memory.ReadValue<ushort>((IntPtr)FNameEntryAddress);
		IntPtr FNameStringStartAddress = (IntPtr)(FNameEntryAddress + 2);

		ushort stringLength = (ushort)(Header >> 6);

		string FNameString = memory.ReadString(FNameStringStartAddress, stringLength);

		return FNameString;
	});
	
	// Credit to Micrologist and Meta for this func, found in the Stray autosplitter.
	vars.GetStaticPointerFromSig = (Func<string, int, IntPtr>) ( (signature, instructionOffset) => {
		var scanner = new SignatureScanner(game, modules.First().BaseAddress, (int)modules.First().ModuleMemorySize);
		var pattern = new SigScanTarget(signature);
		var location = scanner.Scan(pattern);
		if (location == IntPtr.Zero) return IntPtr.Zero;
		int offset = game.ReadValue<int>((IntPtr)location + instructionOffset);
		return (IntPtr)location + offset + instructionOffset + 0x4;
	});

	// Loop through a specific loaded level and find the actor's address. Returns the first instance of the actor.
	vars.getActorInLevel = (Func<string, string, IntPtr>)((actorString_i, levelString_i) => {
		
		uint numOfLevels = memory.ReadValue<uint>((IntPtr)IntPtr.Add(vars.watchers["UWorld"].Current, 0x1D0));
		IntPtr levelTArray = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(vars.watchers["UWorld"].Current, 0x1C8));

		IntPtr levelAddress = IntPtr.Zero;
		string levelString = "";
		
		for (int k = 0; k < numOfLevels; k++)
		{
			levelAddress = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(levelTArray, 8 * k));
			if (levelAddress == IntPtr.Zero) continue;
			IntPtr outer = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(levelAddress, 0x20));
			levelString = vars.getFNameToString(outer);
			if (levelString == levelString_i) break;
		}

		if (levelString != levelString_i) return IntPtr.Zero;

		uint numOfActors = memory.ReadValue<uint>((IntPtr)IntPtr.Add(levelAddress, 0xA8));
		IntPtr actorTArray = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(levelAddress, 0xA0));

		for (int k = 0; k < numOfActors; k++)
		{
			IntPtr actorAddress = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(actorTArray, 8 * k));
			if (actorAddress == IntPtr.Zero) continue;
			string actorString = vars.getFNameToString(actorAddress);
			if (actorString == actorString_i) {
				return actorAddress;
			}
		}

		return IntPtr.Zero;
	});

	// Dump the currently loaded level names.
	vars.dumpLevelNames = (Func<bool>)(() => {
		
		uint numOfLevels = memory.ReadValue<uint>((IntPtr)IntPtr.Add(vars.watchers["UWorld"].Current, 0x1D0));
		IntPtr levelTArray = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(vars.watchers["UWorld"].Current, 0x1C8));

		string message = "";
		
		for (int k = 0; k < numOfLevels; k++)
		{
			IntPtr levelAddress = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(levelTArray, 8 * k));
			if (levelAddress == IntPtr.Zero) continue;
			IntPtr outer = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(levelAddress, 0x20));
			string levelString = vars.getFNameToString(outer);

			if (k != 0) message += "\n";

			message += "Level " + k.ToString() + ":\n" + levelString;
		}

		print(message);
		return true;
	});

	// Find UWorld via sigscan.

	string sig = "48 89 5C 24 18 56 48 83 EC 40 41 8B D8 48 8B F2";
	int insOffset = 0xEC;

	vars.UWorldPointer = vars.GetStaticPointerFromSig(sig, insOffset);
	
	if (vars.UWorldPointer == IntPtr.Zero)
	{
		MessageBox.Show("UWorld could not be found via given signature\n" + sig, "ERROR: Autosplitter Will Not Work", MessageBoxButtons.OK, MessageBoxIcon.Error);
	}

	IntPtr UWorldOffset = (IntPtr)((ulong)vars.UWorldPointer - (ulong)modules.First().BaseAddress);

	// Find FNamePool via sigscan.

	sig = "48 89 5C 24 10 48 89 74 24 18 57 48 83 EC 30 83 79 04 00";
	insOffset = 0x32;
	
	var sigScanner = new SignatureScanner(game, modules.First().BaseAddress, (int)modules.First().ModuleMemorySize);
	var sigPattern = new SigScanTarget(sig);
	var sigLocation = sigScanner.Scan(sigPattern);

	if (sigLocation == IntPtr.Zero)
	{
		vars.FNamePoolBase = IntPtr.Zero;
	}
	else
	{
		int disp = game.ReadValue<int>((IntPtr)sigLocation + insOffset);
		vars.FNamePoolBase = (IntPtr)(sigLocation + 0x06) + disp;
	}

	if (vars.FNamePoolBase == IntPtr.Zero)
	{
		MessageBox.Show("FNamePool could not be found via given signature\n" + sig, "ERROR: Autosplitter Will Not Work", MessageBoxButtons.OK, MessageBoxIcon.Error);
	}

	ulong FNamePoolOffset = (ulong)((ulong)vars.FNamePoolBase - (ulong)modules.First().BaseAddress);
	
	// Watcher variables used in code.

	vars.watchers = new MemoryWatcherList {

		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer)) {Name = "UWorld" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer, vars.UWORLD_MYGAMESTATE, vars.MYGAMESTATE_GAMEMANAGER, vars.GAMEMANAGER_MONSTER)) {Name = "Monster" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<uint>(new DeepPointer(vars.UWorldPointer, vars.UWORLD_MYGAMESTATE, vars.MYGAMESTATE_GAMEMANAGER, vars.GAMEMANAGER_PLAYERARRAY + 0x08)) {Name = "PlayerCount" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer, vars.UWORLD_MYGAMESTATE, vars.MYGAMESTATE_GAMEMANAGER, vars.GAMEMANAGER_PLAYERARRAY)) {Name = "PlayerArray" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<uint>(new DeepPointer(vars.UWorldPointer, vars.UWORLD_MYGAMESTATE, vars.MYGAMESTATE_GAMEMANAGER, vars.GAMEMANAGER_PLAYERARRAY, 0x0, vars.CHARACTER_MYPLAYERSTATE, vars.MYPLAYERSTATE_OBJECTIVECOUNT)) {Name = "PlayerObjectiveCount" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<uint>(new DeepPointer(vars.UWorldPointer, vars.UWORLD_MYGAMESTATE, vars.MYGAMESTATE_GAMEMANAGER, vars.GAMEMANAGER_PLAYERARRAY, 0x0, vars.CHARACTER_MYPLAYERSTATE, vars.MYPLAYERSTATE_OLDOBJECTIVE)) {Name = "PlayerOldObjective" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer, vars.UWORLD_MYGAMESTATE, vars.MYGAMESTATE_GAMEMANAGER, vars.GAMEMANAGER_PLAYERARRAY, 0x0, vars.CHARACTER_INTERACTINGACTOR)) {Name = "PlayerInteractingActor" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer, vars.UWORLD_MYGAMESTATE, vars.MYGAMESTATE_GAMEMANAGER, vars.GAMEMANAGER_PLAYERARRAY, 0x0, vars.CHARACTER_MYPLAYERCONTROLLER, vars.MYPLAYERCONTROLLER_INWIDGETTOFOCUS)) {Name = "PlayerInteractingWidget" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<byte>(new DeepPointer(vars.UWorldPointer, vars.UWORLD_MYGAMESTATE, vars.MYGAMESTATE_MONSTERENUM)) {Name = "MonsterEnum" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},

	};

	// Print the game information.

	vars.watchers.UpdateAll(game);

	print("UWorldOffset:\n0x" + UWorldOffset.ToString("X") + "\nFNamePoolOffset:\n0x" + FNamePoolOffset.ToString("X"));

	vars.dumpLevelNames();

	IntPtr monsterAddress = vars.watchers["Monster"].Current;
	IntPtr interactingActorAddress = vars.watchers["PlayerInteractingActor"].Current;
	IntPtr interactingWidgetAddress = vars.watchers["PlayerInteractingWidget"].Current;

	string output = "";

	if (monsterAddress != IntPtr.Zero)
	{
		output += "\nMonster:\n" + vars.getFNameToString(monsterAddress);
	}
	if (interactingActorAddress != IntPtr.Zero)
	{
		output += "\nInteracting Actor:\n" + vars.getFNameToString(interactingActorAddress);
	}
	if (interactingWidgetAddress != IntPtr.Zero)
	{
		output += "\nInteracting Widget:\n" + vars.getFNameToString(interactingWidgetAddress);
	}

	if (output != "") print(output.Trim());

	// Initialize certain variables.

	vars.importantActors = new Dictionary<string, IntPtr> {};

}

update
{
	vars.watchers.UpdateAll(game);

	// Based on certain conditions, check levels for important actors and add their addresses to the importantActors dictionary.

	// Clear the importantActors if the world changes.
	if (vars.watchers["UWorld"].Changed) vars.importantActors.Clear();

	vars.scanForActorIfNeeded = (Func<string, string, bool>)((actorName_i, levelName_i) => {

		if (!vars.importantActors.ContainsKey(actorName_i))
		{
			IntPtr actor = vars.getActorInLevel(actorName_i, levelName_i);
			if (actor != IntPtr.Zero)
			{
				vars.importantActors[actorName_i] = actor;
				print("Scanned for and found:\n" + actorName_i + " at 0x" + actor.ToString("X"));
				return true;
			}
		}

		return false;
	});

	vars.scanForActorIfNeeded("BP_LeverShip_C", "SpaceShip");
	vars.scanForActorIfNeeded("BP_ConsoleKeypass_C", "SpaceShip");
	vars.scanForActorIfNeeded("BP_ReactorControl_Terminal_REFACT_C", "Hawking_StaticMap_Enginery");
	vars.scanForActorIfNeeded("BP_GAZ_Control_Terminal_REFACT_C", "Hawking_StaticMap_Laboratory");

	// Create debug/coding tools.

	if (vars.watchers["PlayerInteractingActor"].Changed && vars.watchers["PlayerInteractingActor"].Current != IntPtr.Zero)
	{
		// Actors.

		IntPtr objectAddress = vars.watchers["PlayerInteractingActor"].Current;
		string objectString = vars.getFNameToString(objectAddress);

		print("0x" + objectAddress.ToString("X") + ": ACTOR\nPlayer interacted with actor " + objectString);
	}
	
	if (vars.watchers["PlayerInteractingWidget"].Changed && vars.watchers["PlayerInteractingWidget"].Current != IntPtr.Zero)
	{
		// Widgets.

		IntPtr widgetAddress = vars.watchers["PlayerInteractingWidget"].Current;
		string widgetString = vars.getFNameToString(widgetAddress);

		print("0x" + widgetAddress.ToString("X") + ": WIDGET\nPlayer interacted with widget " + widgetString);
	}

	if (vars.watchers["Monster"].Changed && vars.watchers["Monster"].Current != IntPtr.Zero)
	{
		// Monster.

		IntPtr monsterAddress = vars.watchers["Monster"].Current;
		string monsterString = vars.getFNameToString(monsterAddress);

		print("0x" + monsterAddress.ToString("X") + ": MONSTER\nMonster is " + monsterString + " (Enum " + vars.watchers["MonsterEnum"].Current.ToString() + ")");
	}

}

start
{
	if (settings["start_OpenShipDoor"])
	{
		if (vars.importantActors.ContainsKey("BP_LeverShip_C"))
		{
			bool isUsed = memory.ReadValue<bool>((IntPtr)IntPtr.Add(vars.importantActors["BP_LeverShip_C"], vars.LEVERSHIP_ISUSED));
			bool activatedOnce = memory.ReadValue<bool>((IntPtr)IntPtr.Add(vars.importantActors["BP_LeverShip_C"], vars.LEVERSHIP_ACTIVATEDONCE));
			if (isUsed && !activatedOnce)
			{
				return true;
			}
		}
	}
}

onStart
{
	// Global variables used in code. Here for reference and resetting at the start of a run.
	vars.completedSectionGoals = new List<string>();
}

reset
{
	if(settings["reset_GoToLobby"])
	{
		if (vars.watchers["UWorld"].Current == IntPtr.Zero)
		{
			return true;
		}
	}
}

split
{
	if (vars.watchers["Monster"].Current == IntPtr.Zero) return false; // Disallows weird splitting mishaps in lobby and potentally other areas of the game.

	if (settings["split_CompleteAnyObjective"])
	{
		if (vars.watchers["PlayerOldObjective"].Current > vars.watchers["PlayerOldObjective"].Old)
		{
			return true;
		}
	}

	if (settings["split_CompleteLastObjective"])
	{
		if (vars.watchers["PlayerOldObjective"].Changed && vars.watchers["PlayerOldObjective"].Current == vars.watchers["PlayerObjectiveCount"].Current)
		{
			return true;
		}
	}

	if (settings["split_CompleteSectionGoal"])
	{
		foreach (string key in vars.importantActors.Keys)
		{
			if (vars.completedSectionGoals.Contains(key)) continue;

			bool completed = false;
			IntPtr actor = vars.importantActors[key];

			switch (key)
			{
				case "BP_ConsoleKeypass_C":
					uint keypassMax = memory.ReadValue<uint>((IntPtr)IntPtr.Add(actor, vars.CONSOLEKEYPASS_MAX));
					uint keypassCurrent = memory.ReadValue<uint>((IntPtr)IntPtr.Add(actor, vars.CONSOLEKEYPASS_CURRENT));
					completed = (keypassCurrent >= keypassMax);
					break;
				case "BP_ReactorControl_Terminal_REFACT_C":
					bool finished = memory.ReadValue<bool>((IntPtr)IntPtr.Add(actor, vars.REACTORCONTROLTERMINAL_FINISHED));
					completed = finished;
					break;
				case "BP_GAZ_Control_Terminal_REFACT_C":
					IntPtr puzzle = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(actor, vars.GAZCONTROLTERMINAL_PUZZLE));
					bool purge = memory.ReadValue<bool>((IntPtr)IntPtr.Add(puzzle, vars.PUZZLE_PURGE));
					completed = purge;
					break;
				default:
					break;
			}

			if (completed)
			{
				vars.completedSectionGoals.Add(key);
				return true;
			}
		}
	}
}
