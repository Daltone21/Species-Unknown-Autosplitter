/*
	Autosplitter for Species Unknown.
	Includes the ability to automatically start, split, and reset.
	Configurable settings.

	By daltone_21 on Discord.

	Todo:
		- Add information component support for monster on beginning a mission.
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
	settings.Add("split_CompleteLastObjective", true, "Complete Last Objective");
	settings.Add("split_CompleteAnyObjective", true, "Complete Any Objective");
	settings.Add("split_CompleteSectionGoal", true, "Complete Section Goal (Keypasses, Pipes, Airlock, etc.)");
	settings.Add("split_MonsterSpecific", true, "Monster Specific");

	settings.CurrentDefaultParent = "split_MonsterSpecific";
	settings.Add("split_MonsterSpecific_Octopus", true, "Octopus");
	settings.Add("split_MonsterSpecific_Mike", true, "Mike");
	settings.Add("split_MonsterSpecific_TheEye", true, "The Eye");
	settings.Add("split_MonsterSpecific_Ghost", true, "Ghost");
	settings.Add("split_MonsterSpecific_PuppetMaster", true, "Puppet Master");
	settings.Add("split_MonsterSpecific_Peacekeeper", true, "Peacekeeper");

	settings.CurrentDefaultParent = "split_MonsterSpecific_Octopus";
	settings.Add("split_MonsterSpecific_Octopus_CutAnEye", true, "Cut an Eye");
	
	settings.CurrentDefaultParent = "split_MonsterSpecific_Mike";
	settings.Add("split_MonsterSpecific_Mike_BreakAFace", true, "Break a Face");
	
	settings.CurrentDefaultParent = "split_MonsterSpecific_TheEye";
	settings.Add("split_MonsterSpecific_TheEye_LoseShield", true, "Lose Shield");
	settings.Add("split_MonsterSpecific_TheEye_StartDroppingOil", true, "Start Dropping Oil");
	settings.Add("split_MonsterSpecific_TheEye_BreakGlass", true, "Break Glass");
	
	settings.CurrentDefaultParent = "split_MonsterSpecific_Ghost";
	settings.Add("split_MonsterSpecific_Ghost_LoseThirdOfHealth", true, "Lose Third of Health");

	settings.CurrentDefaultParent = "split_MonsterSpecific_PuppetMaster";
	settings.Add("split_MonsterSpecific_PuppetMaster_LoseThirdOfHealth", true, "Lose Third of Health");
	
	settings.CurrentDefaultParent = "split_MonsterSpecific_Peacekeeper";
	settings.Add("split_MonsterSpecific_Peacekeeper_DestroyGatlingGun", true, "Destroy Gatling Gun");
	settings.Add("split_MonsterSpecific_Peacekeeper_LoseThirdOfHealth", true, "Lose Third of Health");

	settings.CurrentDefaultParent = null;

	// Reset settings.
	settings.Add("reset", false, "Reset Settings");
	
	settings.CurrentDefaultParent = "reset";
	settings.Add("reset_GoToLobby", false, "Go To Lobby");
	
	settings.CurrentDefaultParent = null;
	
	/* Information settings.
	settings.Add("info", false, "Information Settings");
	
	settings.CurrentDefaultParent = "info";
	settings.Add("info_ShowMonsterComponent", false, "Show Monster Component");
	
	settings.CurrentDefaultParent = null;*/
}

init
{
	// Offsets of classes possible to change with updates. The value of PARENT_CHILD is the offset of CHILD from PARENT.
	// Update when possible to make the autosplitter more resilient to updates.

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

	vars.BASEMONSTER_HEALTH = 0xD00;
	vars.BASEMONSTER_MAXHEALTH = 0xD08;

	vars.MONSTERPOULPI_EYERIGHTCUT = 0x1398;
	vars.MONSTERPOULPI_EYELEFTCUT = 0x1399;
	
	vars.MONSTERMIKE_HEADBREAKLEFT = 0x1308;
	vars.MONSTERMIKE_HEADBREAKRIGHT = 0x1309;
	
	vars.MONSTEREYE_HAVESHIELD = 0x13B8;
	vars.MONSTEREYE_DROPOIL = 0x1438;
	vars.MONSTEREYE_BREAKGLASS = 0x1439;
	
	vars.MONSTERPEACEKEEPER_GATLING = 0x13A0;

	vars.GATLING_CANFIRE = 0x889;
	vars.GATLING_LIFEVALUE = 0x8F0;

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
	
	// Credit to Micrologist and Meta, this func was found in the Stray asl.
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
		vars.FNamePoolBase = (IntPtr)(sigLocation + 6) + disp;
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
		output += "\nMonster: 0x " + monsterAddress.ToString("X") + "\n" + vars.getFNameToString(monsterAddress);
	}
	if (interactingActorAddress != IntPtr.Zero)
	{
		output += "\nInteracting Actor: 0x " + interactingActorAddress.ToString("X") + "\n" + vars.getFNameToString(interactingActorAddress);
	}
	if (interactingWidgetAddress != IntPtr.Zero)
	{
		output += "\nInteracting Widget: 0x " + interactingWidgetAddress.ToString("X") + "\n" + vars.getFNameToString(interactingWidgetAddress);
	}

	if (output != "") print(output.Trim());

	// Initialize certain variables.

	vars.importantActors = new Dictionary<string, IntPtr> {};

}

update
{
	vars.watchers.UpdateAll(game);

	// Check levels for important actors and add their addresses to the importantActors dictionary.

	// Clear the importantActors if the world changes.
	if (vars.watchers["UWorld"].Changed) vars.importantActors.Clear();

	vars.scanForActorIfNeeded = (Func<string, string, bool>)((actorName_i, levelName_i) => {

		if (!vars.importantActors.ContainsKey(actorName_i))
		{
			IntPtr actor = vars.getActorInLevel(actorName_i, levelName_i);
			if (actor != IntPtr.Zero)
			{
				vars.importantActors[actorName_i] = actor;
				print("Scanned for and found:\n" + actorName_i + " at 0x" + actor.ToString("X") + " in " + levelName_i);
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
	
	/*
	if (vars.watchers["MonsterEnum"].Changed && vars.watchers["MonsterEnum"].Current != IntPtr.Zero)
	{
		// Monster component.

		byte monsterEnum = vars.watchers["MonsterEnum"].Current;

		string monsterName = ((Func<string>)(() => {
			switch (monsterEnum) {
				default:
					return "";
				case 2:
					return "Octopus";
				case 3:
					return "Mike";
				case 4:
					return "The Eye";
				case 5:
					return "Ghost";
				case 6:
					return "Puppet Master";
				case 7:
					return "Peacekeeper";
			}
		}))();

	}
	*/

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
				print("start_OpenShipDoor");
				return true;
			}
		}
	}
}

onStart
{
	// Global variables used in code. Here for reference and resetting at the start of a run.
	vars.completedSectionGoals = new List<string>();
	vars.monsterPhase = 0;
}

reset
{
	if(settings["reset_GoToLobby"])
	{
		if (vars.watchers["UWorld"].Changed)
		{
			print("reset_GoToLobby");
			return true;
		}
	}
}

split
{
	if (vars.watchers["Monster"].Current == IntPtr.Zero) return false; // Disallows weird splitting mishaps in lobby and potentally other areas of the game.


	if (settings["split_CompleteLastObjective"])
	{
		if (vars.watchers["PlayerOldObjective"].Changed && vars.watchers["PlayerOldObjective"].Current == vars.watchers["PlayerObjectiveCount"].Current)
		{
			print("split_CompleteLastObjective");
			return true;
		}
	}

	if (settings["split_CompleteAnyObjective"])
	{
		if (vars.watchers["PlayerOldObjective"].Current > vars.watchers["PlayerOldObjective"].Old)
		{
			print("split_CompleteAnyObjective");
			return true;
		}
	}

	if (settings["split_CompleteSectionGoal"])
	{
		foreach (string actorFName in vars.importantActors.Keys)
		{
			if (vars.completedSectionGoals.Contains(actorFName)) continue;

			bool completed = false;
			IntPtr actor = vars.importantActors[actorFName];

			switch (actorFName)
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
				vars.completedSectionGoals.Add(actorFName);
				print("split_CompleteSectionGoal");
				return true;
			}
		}
	}

	if (settings["split_MonsterSpecific"])
	{
		IntPtr monster = vars.watchers["Monster"].Current;
		byte monsterEnum = vars.watchers["MonsterEnum"].Current;

		switch (monsterEnum)
		{
			default:
				break;
			case 2: // Octopus
				if (settings["split_MonsterSpecific_Octopus_CutAnEye"])
				{
					bool eyeRightCut = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.MONSTERPOULPI_EYERIGHTCUT));
					bool eyeLeftCut = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.MONSTERPOULPI_EYELEFTCUT));
					int eyeCutCount = 0;
					if (eyeRightCut) eyeCutCount++;
					if (eyeLeftCut) eyeCutCount++;
					if (vars.monsterPhase < eyeCutCount)
					{
						vars.monsterPhase = eyeCutCount;
						print("split_MonsterSpecific_Octopus_CutAnEye");
						return true;
					}
				}
				break;
			case 3: // Mike
				if (settings["split_MonsterSpecific_Mike_BreakAFace"])
				{
					bool headBreakLeft = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.MONSTERMIKE_HEADBREAKLEFT));
					bool headBreakRight = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.MONSTERMIKE_HEADBREAKRIGHT));
					int headBreakCount = 0;
					if (headBreakLeft) headBreakCount++;
					if (headBreakRight) headBreakCount++;
					if (vars.monsterPhase < headBreakCount)
					{
						vars.monsterPhase = headBreakCount;
						print("split_MonsterSpecific_Mike_BreakAFace");
						return true;
					}
				}
				break;
			case 4: // The Eye
				if (settings["split_MonsterSpecific_TheEye_LoseShield"])
				{
					bool haveShield = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.MONSTEREYE_HAVESHIELD));
					if (vars.monsterPhase < 1 && !haveShield)
					{
						vars.monsterPhase = 1;
						print("split_MonsterSpecific_TheEye_LoseShield");
						return true;
					}
				}
				if (settings["split_MonsterSpecific_TheEye_StartDroppingOil"])
				{
					bool dropOil = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.MONSTEREYE_DROPOIL));
					if (vars.monsterPhase < 2 && dropOil)
					{
						vars.monsterPhase = 2;
						print("split_MonsterSpecific_TheEye_StartDroppingOil");
						return true;
					}
				}
				if (settings["split_MonsterSpecific_TheEye_BreakGlass"])
				{
					bool breakGlass = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.MONSTEREYE_BREAKGLASS));
					if (vars.monsterPhase < 3 && breakGlass)
					{
						vars.monsterPhase = 3;
						print("split_MonsterSpecific_TheEye_BreakGlass");
						return true;
					}
				}
				break;
			case 5: // Ghost
				if (settings["split_MonsterSpecific_Ghost_LoseThirdOfHealth"])
				{
					double health = memory.ReadValue<double>((IntPtr)IntPtr.Add(monster, vars.BASEMONSTER_HEALTH));
					double maxHealth = memory.ReadValue<double>((IntPtr)IntPtr.Add(monster, vars.BASEMONSTER_MAXHEALTH));
					if (vars.monsterPhase < 1 && health <= maxHealth * (2d/3d))
					{
						vars.monsterPhase = 1;
						print("split_MonsterSpecific_Ghost_LoseThirdOfHealth");
						return true;
					}
					if (vars.monsterPhase < 2 && health <= maxHealth * (1d/3d))
					{
						vars.monsterPhase = 2;
						print("split_MonsterSpecific_Ghost_LoseThirdOfHealth");
						return true;
					}
				}
				break;
			case 6: // Puppet Master
				if (settings["split_MonsterSpecific_PuppetMaster_LoseThirdOfHealth"])
				{
					double health = memory.ReadValue<double>((IntPtr)IntPtr.Add(monster, vars.BASEMONSTER_HEALTH));
					double maxHealth = memory.ReadValue<double>((IntPtr)IntPtr.Add(monster, vars.BASEMONSTER_MAXHEALTH));
					if (vars.monsterPhase < 1 && health <= maxHealth * (2d/3d))
					{
						vars.monsterPhase = 1;
						print("split_MonsterSpecific_PuppetMaster_LoseThirdOfHealth");
						return true;
					}
					if (vars.monsterPhase < 2 && health <= maxHealth * (1d/3d))
					{
						vars.monsterPhase = 2;
						print("split_MonsterSpecific_PuppetMaster_LoseThirdOfHealth");
						return true;
					}
				}
				break;
			case 7: // Peacekeeper
				if (settings["split_MonsterSpecific_Peacekeeper_DestroyGatlingGun"])
				{
					IntPtr gatlingGun = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(monster, vars.MONSTERPEACEKEEPER_GATLING));
					if (gatlingGun != IntPtr.Zero)
					{
						bool canFire = memory.ReadValue<bool>((IntPtr)IntPtr.Add(gatlingGun, vars.GATLING_CANFIRE));
						double lifeValue = memory.ReadValue<double>((IntPtr)IntPtr.Add(gatlingGun, vars.GATLING_LIFEVALUE));
						if (vars.monsterPhase < 1 && !canFire && lifeValue > 0d)
						{
							vars.monsterPhase = 1;
							print("split_MonsterSpecific_Peacekeeper_DestroyGatlingGun");
							return true;
						}
					}
				}
				if (settings["split_MonsterSpecific_Peacekeeper_LoseThirdOfHealth"])
				{
					double health = memory.ReadValue<double>((IntPtr)IntPtr.Add(monster, vars.BASEMONSTER_HEALTH));
					double maxHealth = memory.ReadValue<double>((IntPtr)IntPtr.Add(monster, vars.BASEMONSTER_MAXHEALTH));
					if (vars.monsterPhase < 2 && health <= maxHealth * (2d/3d))
					{
						vars.monsterPhase = 2;
						print("split_MonsterSpecific_Peacekeeper_LoseThirdOfHealth");
						return true;
					}
					if (vars.monsterPhase < 3 && health <= maxHealth * (1d/3d))
					{
						vars.monsterPhase = 3;
						print("split_MonsterSpecific_Peacekeeper_LoseThirdOfHealth");
						return true;
					}
				}
				break;
		}
	}
}
