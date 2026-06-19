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
	settings.Add("reset_GoToLobby", true, "Go To Lobby");
	
	settings.CurrentDefaultParent = null;
}

init
{
	// Function declarations.

	vars.getFNameToString = (Func<ulong, string>)((UObjectAddress) => {

		if (UObjectAddress == (ulong)0) return null;

		ulong FName = UObjectAddress + 0x18;
		ushort blockKey = memory.ReadValue<ushort>((IntPtr)(FName + 0x02));
		ushort innerKey = memory.ReadValue<ushort>((IntPtr)FName);

		ulong FNamePool = (ulong)modules.First().BaseAddress + (ulong)vars.FNamePoolOffset;
		ulong blockAddress = memory.ReadValue<ulong>((IntPtr)(FNamePool + (ulong)vars.FNamePoolModBase + (ulong)(0x08 * blockKey)));
		ulong FNameEntryAddress = blockAddress + (ulong)(0x02 * innerKey);

		ushort stringLength = (ushort)(memory.ReadValue<ushort>((IntPtr)FNameEntryAddress) >> 6);
		ulong FNameStringStartAddress = FNameEntryAddress + 0x02;

		string FNameString = memory.ReadString((IntPtr)FNameStringStartAddress, stringLength);

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
	int insOffset = 236;

	IntPtr UWorld = vars.GetStaticPointerFromSig(sig, insOffset);
	IntPtr UWorldOffset = (IntPtr)((ulong)UWorld - (ulong)modules.First().BaseAddress);

	if (UWorld == IntPtr.Zero)
	{
		throw new System.Exception("ERROR: UWorld could not be found via given signature\n	" + sig);
	}
	print(UWorld.ToString("X"));
	print(UWorldOffset.ToString("X"));

	//print("Game Detected!\nGEngine Address: " + current.GEngine.ToString("X") + "\nUWorld Address: " + current.UWorld.ToString("X"));
	
	// Certain variables.

	vars.completedSectionGoals = new List<string>();

	// Defined data structures and offsets.

	vars.FNamePoolOffset =	0x8BE8618;
	vars.FNamePoolModBase =	-0x09 * 0x08;

	vars.objectiveStructDict = new Dictionary<string, uint>
	{
		{"size",		0x20},
		{"FName",		0x00},
		{"FText",		0x08},
		{"isActual",	0x18},
		{"isComplete",	0x19},
		{"isCancel",	0x1A},
	};
	
	vars.weaponStructDict = new Dictionary<string, uint>
	{
		{"fireRate",				0x478},
		{"reloadAnim",				0x4D8},
		{"isAuto",					0x523},
		{"ammoMax",					0x528},
		{"isReloading",				0x522},
		{"distanceMax",				0x548},
		{"invAmmoMax",				0x988},
		{"damage",					0x998},
		{"pelletNum",				0xA2C},
		{"shootMultiplePellets",	0xA30},
	};

}

update
{
	return false;
	// Create debug/coding tools.

	if (current.CharacterInteractingActor != old.CharacterInteractingActor && current.CharacterInteractingActor != 0)
	{
		// Actors.

		ulong objectAddress = current.CharacterInteractingActor;
		string objectString = vars.getFNameToString(objectAddress);

		print(objectAddress.ToString("X") + ": ACTOR\nPlayer interacted with actor " + objectString);
	}
	
	if (current.CharacterFocusedWidget != old.CharacterFocusedWidget && current.CharacterFocusedWidget != 0)
	{
		// Widgets.

		ulong widgetAddress = current.CharacterFocusedWidget;
		string widgetString = vars.getFNameToString(widgetAddress);

		print(widgetAddress.ToString("X") + ": WIDGET\nPlayer interacted with widget " + widgetString);
	}

	if (current.Monster != old.Monster && current.Monster != 0)
	{
		// Monster.

		ulong monsterAddress = current.Monster;
		string monsterString = vars.getFNameToString(monsterAddress);
		string monsterEnumString = current.MonsterEnum.ToString();

		print(monsterAddress.ToString("X") + ": MONSTER\nMonster is " + monsterString + " (Enum " + monsterEnumString + ")");
	}
	
	if (current.WeaponOut != old.WeaponOut && current.WeaponOut != 0)
	{
		// Weapons.

		ulong weaponAddress = current.WeaponOut;
		string weaponString = vars.getFNameToString(weaponAddress);

		double fireRate = memory.ReadValue<double>((IntPtr)(weaponAddress + vars.weaponStructDict["fireRate"]));
		bool isAuto = memory.ReadValue<bool>((IntPtr)(weaponAddress + vars.weaponStructDict["isAuto"]));
		float reloadTime = memory.ReadValue<float>(memory.ReadValue<IntPtr>((IntPtr)(weaponAddress + vars.weaponStructDict["reloadAnim"])) + 0x90);
		int ammoMax = memory.ReadValue<int>((IntPtr)(weaponAddress + vars.weaponStructDict["ammoMax"]));
		double distanceMax = memory.ReadValue<double>((IntPtr)(weaponAddress + vars.weaponStructDict["distanceMax"]));
		int invAmmoMax = memory.ReadValue<int>((IntPtr)(weaponAddress + vars.weaponStructDict["invAmmoMax"]));
		double dmg = memory.ReadValue<double>((IntPtr)(weaponAddress + vars.weaponStructDict["damage"]));
		int pelletNum = memory.ReadValue<int>((IntPtr)(weaponAddress + vars.weaponStructDict["pelletNum"]));
		bool shootMultiplePellets = memory.ReadValue<bool>((IntPtr)(weaponAddress + vars.weaponStructDict["shootMultiplePellets"]));

		double dmgPerShot = dmg * ((shootMultiplePellets) ? pelletNum : 1);

		double dmgPerSecond_NoReload = dmgPerShot / fireRate;

		string statsString = "Stats:\n	Fire Rate: " + fireRate.ToString() + "\n	Automatic: " + isAuto.ToString() + "\n	Ammo Max: " + ammoMax.ToString() + "\n	Distance Max: " + distanceMax.ToString() + "\n	Inv Ammo Max: " + invAmmoMax.ToString() + "\n	Damage: " + dmg.ToString() + "\n	Pellet Num: " + pelletNum.ToString() + "\n	Shoots Multiple Pellets: " + shootMultiplePellets.ToString() + "\n	Estimated dmg/s (no reload): " + dmgPerSecond_NoReload.ToString();

		print(weaponAddress.ToString("X") + ": WEAPON\nPlayer took out " + weaponString + "\n" + statsString);
	}

	if (current.WeaponOutIsReloading && !old.WeaponOutIsReloading)
	{
		vars.startReloadTime = DateTime.UtcNow;
	}

	if (!current.WeaponOutIsReloading && old.WeaponOutIsReloading)
	{
		vars.endReloadTime = DateTime.UtcNow;

		vars.reloadTimeElapsed = vars.endReloadTime - vars.startReloadTime;
		
		ulong weaponAddress = current.WeaponOut;
		string weaponString = vars.getFNameToString(weaponAddress);

		double fireRate = memory.ReadValue<double>((IntPtr)(weaponAddress + vars.weaponStructDict["fireRate"]));
		bool isAuto = memory.ReadValue<bool>((IntPtr)(weaponAddress + vars.weaponStructDict["isAuto"]));
		float reloadTime = memory.ReadValue<float>(memory.ReadValue<IntPtr>((IntPtr)(weaponAddress + vars.weaponStructDict["reloadAnim"])) + 0x90);
		int ammoMax = memory.ReadValue<int>((IntPtr)(weaponAddress + vars.weaponStructDict["ammoMax"]));
		double distanceMax = memory.ReadValue<double>((IntPtr)(weaponAddress + vars.weaponStructDict["distanceMax"]));
		int invAmmoMax = memory.ReadValue<int>((IntPtr)(weaponAddress + vars.weaponStructDict["invAmmoMax"]));
		double dmg = memory.ReadValue<double>((IntPtr)(weaponAddress + vars.weaponStructDict["damage"]));
		int pelletNum = memory.ReadValue<int>((IntPtr)(weaponAddress + vars.weaponStructDict["pelletNum"]));
		bool shootMultiplePellets = memory.ReadValue<bool>((IntPtr)(weaponAddress + vars.weaponStructDict["shootMultiplePellets"]));

		double dmgPerShot = dmg * ((shootMultiplePellets) ? pelletNum : 1);

		double dmgPerSecond_Reload = (dmgPerShot * ammoMax) / (fireRate * ammoMax + vars.reloadTimeElapsed.TotalSeconds);

		print("Reload took " + vars.reloadTimeElapsed.TotalSeconds.ToString() + " seconds!\n	Estimated dmg/s (reload): " + dmgPerSecond_Reload.ToString());
	}
}

start
{
	if (settings["start_OpenShipDoor"])
	{
		if (current.CharacterInteractingActor != old.CharacterInteractingActor && vars.getFNameToString(current.CharacterInteractingActor) == "BP_LeverShip_C")
		{
			return true;
		}
	}
}

onStart
{
	// Global variables used in code. Here for reference and resetting at the start of a run.
	vars.indexOfLastCompletedObjective = -1;
	vars.completedSectionGoals.Clear();
}

reset
{
	if(settings["reset_GoToLobby"])
	{
		if (current.GameManager == 0 && old.GameManager != 0)
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
