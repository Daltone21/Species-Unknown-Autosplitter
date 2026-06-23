/*
	Autosplitter for Species Unknown.
	Includes the ability to automatically start, split, and reset.
	Configurable settings.

	By daltone_21 on Discord.

	Todo:
		- Add splitting support for enemy phase changes
		- Fix splitting support for reactor and GAZ terminals
		- Add component support for enemy on beginning a mission
*/

state("SpeciesUnknown-Win64-Shipping")
{
	//ulong GEngine:	0x08E44360;
	//ulong UWorld:	0x08E41410;
	
	//ulong Character:	0x08E44360, 0x12C8, 0x38, 0x0, 0x30, 0x300;
	//ulong CharacterInteractingActor:	0x08E44360, 0x12C8, 0x38, 0x0, 0x30, 0x300, 0xC28;
	//ulong CharacterFocusedWidget:	0x08E44360, 0x12C8, 0x38, 0x0, 0x30, 0x300, 0xC30, 0x7D8;
	//ulong WeaponOut:	0x08E44360, 0x12C8, 0x38, 0x0, 0x30, 0x300, 0xA70;
	//bool WeaponOutIsReloading:	0x08E44360, 0x12C8, 0x38, 0x0, 0x30, 0x300, 0xA70, 0x52C;
	//ulong WeaponInventory:	0x08E44360, 0x12C8, 0x38, 0x0, 0x30, 0x300, 0xC48;
	//uint WeaponCount:	0x08E44360, 0x12C8, 0x38, 0x0, 0x30, 0x300, 0xC50;
	
	//uint MissionTimerSec:	0x08E41410, 0x1B0, 0x46C;
	//ulong GameManager:	0x08E41410, 0x1B0, 0x350;
	//byte MonsterEnum:	0x08E41410, 0x1B0, 0x5B9;
	//ulong Monster:	0x08E41410, 0x1B0, 0x350, 0x2D0;
	//double MonsterHealth:	0x08E41410, 0x1B0, 0x350, 0x2D0, 0xD00;
	//ulong LoadedLevel:	0x08E41410, 0x8A8, 0x350;
	//uint SecondsSinceLeftShip:	0x08E41410, 0x1B0, 0x350, 0x2F8;

	//bool PlayerIsDead:	0x08E41410, 0x1B0, 0x430, 0x0, 0x38C;
	//ulong ObjectiveArray:	0x08E41410, 0x1B0, 0x430, 0x0, 0x408;
	//int ObjectiveCount:	0x08E41410, 0x1B0, 0x430, 0x0, 0x410;

	//bool ShipDoorOpen:	0x08E41410, 0x1B0, 0x3B8, 0xA88;
}

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
	settings.Add("split_CompleteFinalObjective", true, "Complete Final Objective");
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

	// Print the game information.

	print("UWorldOffset:\n0x" + UWorldOffset.ToString("X") + "\nFNamePoolOffset:\n0x" + FNamePoolOffset.ToString("X"));;
	
	// Watcher variables used in code.

	vars.watchers = new MemoryWatcherList {

		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer)) {Name = "UWorld" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer, 0x1B0, 0x350, 0x2D0)) {Name = "Monster" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer, 0x1B0, 0x350, 0x2D8)) {Name = "PlayerArray" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer, 0x1B0, 0x350, 0x2D8, 0x0, 0xC28)) {Name = "Player1InteractingActor" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<uint>(new DeepPointer(vars.UWorldPointer, 0x1B0, 0x350, 0x2E0)) {Name = "PlayerCount" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<byte>(new DeepPointer(vars.UWorldPointer, 0x1B0, 0x5B9)) {Name = "MonsterEnum" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},

	};

	//return false;
}

update
{
	vars.watchers.UpdateAll(game);

	// Create debug/coding tools.

	if (vars.watchers["Player1InteractingActor"].Changed && vars.watchers["Player1InteractingActor"].Current != IntPtr.Zero)
	{
		// Actors.

		IntPtr objectAddress = vars.watchers["Player1InteractingActor"].Current;
		string objectString = vars.getFNameToString(objectAddress);

		print("0x" + objectAddress.ToString("X") + ": ACTOR\nPlayer interacted with actor " + objectString);
	}
	
	/*
	if (vars.watchers["Player1FocusedWidget"].Changed && vars.watchers["Player1FocusedWidget"].Current != IntPtr.Zero)
	{
		// Widgets.

		IntPtr widgetAddress = vars.watchers["Player1FocusedWidget"].Current;
		string widgetString = vars.getFNameToString(widgetAddress);

		print("0x" + widgetAddress.ToString("X") + ": WIDGET\nPlayer interacted with widget " + widgetString);
	}*/

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
		/*
		vars.doFuncForAllPlayers((Func<IntPtr, bool>)((playerAddress) => {
			IntPtr characterInteractingActor = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(playerAddress, 0xC28));
print("Checking player at address 0x" + playerAddress.ToString("X") + " for ship door interaction...");
			if (characterInteractingActor != IntPtr.Zero)
			{
				print("Player is interacting with actor at address 0x" + characterInteractingActor.ToString("X"));
				//startRun = true;
			}
			return true;
		}));
		*/

		if (vars.watchers["Player1InteractingActor"].Changed && vars.getFNameToString(vars.watchers["Player1InteractingActor"].Current) == "BP_LeverShip_C")
		{
			return true;
		}
	}
}

onStart
{
	// Global variables used in code. Here for reference and resetting at the start of a run.
	vars.indexOfLastCompletedObjective = -1;
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
	if (current.GameManager == 0) return false; // Disallows weird splitting mishaps in lobby.
	
	if (settings["split_CompleteAnyObjective"] || settings["split_CompleteFinalObjective"])
	{
		/*
			If split_CompleteAnyObjective, then check if any new objectives are complete and set indexOfLastCompletedObjective to the last complete objective.
			Else, check only the last objective for completion and set indexOfLastCompletedObjective to the last complete objective.
		*/
		int objectiveIndexLowerBound = (settings["split_CompleteAnyObjective"]) ? vars.indexOfLastCompletedObjective + 1 : current.ObjectiveCount - 1;

		for (int i = current.ObjectiveCount - 1; i >= objectiveIndexLowerBound; i--)
		{
			ulong objectiveArrayOffset = (ulong)(vars.objectiveStructDict["size"] * i + vars.objectiveStructDict["isComplete"]);
			bool iObjectiveIsComplete = memory.ReadValue<bool>((IntPtr)(current.ObjectiveArray + objectiveArrayOffset));

			if (iObjectiveIsComplete)
			{
				vars.indexOfLastCompletedObjective = i;
				return true;
			}
		}
	}

	if (settings["split_CompleteSectionGoal"])
	{
		string interactingFNameString = "";
		bool sectionComplete = false;

		if (current.CharacterFocusedWidget != 0)
		{
			interactingFNameString = vars.getFNameToString(current.CharacterFocusedWidget);
		}
		else if (current.CharacterInteractingActor != 0)
		{
			interactingFNameString = vars.getFNameToString(current.CharacterInteractingActor);
		}

		if (!vars.completedSectionGoals.Contains(interactingFNameString))
		{
			ulong widget = current.CharacterFocusedWidget;
			ulong actor = current.CharacterInteractingActor;

			switch (interactingFNameString)
			{
				default:
				{
					break;
				}
				case "BP_ConsoleKeypass_C":
				{
					int keypassMax = memory.ReadValue<int>((IntPtr)(actor + 0x4B8));
					int keypasses = memory.ReadValue<int>((IntPtr)(actor + 0x4BC));
					sectionComplete = (keypasses >= keypassMax);
					break;
				}
				case "UMG_Reactor_REFACT_C":
				{
					IntPtr terminal = memory.ReadValue<IntPtr>((IntPtr)(widget + 0x460));
					bool storeOpened = memory.ReadValue<bool>(terminal + 0x4A8);
					sectionComplete = storeOpened;
					break;
				}
				case "UMG_GAZ_REFACT_C":
				{
					IntPtr terminal = memory.ReadValue<IntPtr>((IntPtr)(widget + 0x478));
					bool storeOpened = memory.ReadValue<bool>(terminal + 0x488);
					sectionComplete = storeOpened;
					break;
				}
			}

			if (sectionComplete)
			{
				vars.completedSectionGoals.Add(interactingFNameString);
				print(vars.completedSectionGoals.ToString());
				return true;
			}
		}
	}
}
