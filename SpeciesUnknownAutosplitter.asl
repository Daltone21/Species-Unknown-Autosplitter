/*
	Autosplitter for Species Unknown.
	Includes the ability to automatically start, split, and reset.
	Configurable settings.

	By daltone_21 on Discord.

	Todo:
		- Add splitting support for enemy phase changes
		- Add splitting support for terminals
*/

state("SpeciesUnknown-Win64-Shipping")
{
	ulong GEngine:	0x08E44360;
	ulong UWorld:	0x08E41410;
	
	//ulong Character:	0x08E44360, 0x12C8, 0x38, 0x0, 0x30, 0x300;
	ulong CharacterInteractingActor:	0x08E44360, 0x12C8, 0x38, 0x0, 0x30, 0x300, 0xC28;
	ulong CharacterFocusedWidget:	0x08E44360, 0x12C8, 0x38, 0x0, 0x30, 0x300, 0xC30, 0x7D8;
	
	//uint MissionTimerSec:	0x08E41410, 0x1B0, 0x46C;
	ulong GameManager:	0x08E41410, 0x1B0, 0x350;
	byte MonsterEnum:	0x08E41410, 0x1B0, 0x5B9;
	ulong Monster:	0x08E41410, 0x1B0, 0x350, 0x2D0;
	double MonsterHealth:	0x08E41410, 0x1B0, 0x350, 0x2D0, 0xD00;
	//uint SecondsSinceLeftShip:	0x08E41410, 0x1B0, 0x350, 0x2F8;

	//bool PlayerIsDead:	0x08E41410, 0x1B0, 0x430, 0x0, 0x38C;
	ulong ObjectiveArray:	0x08E41410, 0x1B0, 0x430, 0x0, 0x408;
	int ObjectiveCount:	0x08E41410, 0x1B0, 0x430, 0x0, 0x410;

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
	settings.Add("split_ChangeMonsterPhase", true, "Change Monster Phase");
	
	settings.CurrentDefaultParent = null;

	// Reset settings.
	settings.Add("reset", false, "Reset Settings");
	
	settings.CurrentDefaultParent = "reset";
	settings.Add("reset_GoToLobby", true, "Go To Lobby");
	
	settings.CurrentDefaultParent = null;
}

init
{
	print("Game Detected!\nGEngine Address: " + current.GEngine.ToString("X") + "\nUWorld Address: " + current.UWorld.ToString("X"));

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

}

update
{
	// Create a debug/coding tools.

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
		print("Monster " + current.MonsterEnum.ToString() + ":\n" + vars.getFNameToString(current.Monster));
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

	if (settings["split_ChangeMonsterPhase"])
	{
		if (current.MonsterHealth > old.MonsterHealth)
		{
			return true;
		}
	}
}
