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
	settings.Add("split_MonsterSpecific_TheEye_BreakGlass", true, "Break Glass");
	settings.Add("split_MonsterSpecific_TheEye_StartDroppingOil", true, "Start Dropping Oil");
	
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
}

init
{
	// The below dictionary has already been populated with offsets that are engine offsets, thus unlikely to change between updates.
	vars.offsets = new Dictionary<string, Dictionary<string, int>> {
		{"UWorld", new Dictionary<string, int> {
			{"GameState", 0x1B0},
			{"Levels", 0x1C8},
			{"OwningGameInstance", 0x228},
		}},
		{"ULevel", new Dictionary<string, int> {
			{"Actors", 0xA0},
		}},
		{"UObject", new Dictionary<string, int> {
			{"Index", 0x0C},
			{"Class", 0x10},
			{"Name", 0x18},
			{"Outer", 0x20},
		}},
		{"UGameInstance", new Dictionary<string, int> {
			{"LocalPlayers", 0x38},
		}},
		{"UPlayer", new Dictionary<string, int> {
			{"PlayerController", 0x30},
		}},
		{"AController", new Dictionary<string, int> {
			{"Character", 0x300},
		}},
		{"FName", new Dictionary<string, int> {
			{"ComparisonIndex", 0x00},
			{"Number", 0x04},
		}},
		{"UStruct", new Dictionary<string, int> {
			{"SuperStruct", 0x40},
			{"Offset", 0x44},
			{"ChildProperties", 0x50},
		}},
		{"FField", new Dictionary<string, int> {
			{"ClassPrivate", 0x08},
			{"Next", 0x18},
			{"Name", 0x20},
		}},
		{"FFieldClass", new Dictionary<string, int> {
			{"Name", 0x00},
		}},
		{"TUObjectArray", new Dictionary<string, int> {
			{"Objects", 0x00},
			{"MaxElements", 0x10},
			{"NumElements", 0x14},
			{"MaxChunks", 0x18},
			{"NumChunks", 0x1C},
		}},
		{"Pawn", new Dictionary<string, int> {
			{"PlayerState", 0x2D0},
			{"Controller", 0x2E0}
		}},
	};

	#region Functions

	vars.FNameToString = (Func<IntPtr, string>)((FName_i) => {

		if (FName_i == IntPtr.Zero) return null;

		uint comparisonID = memory.ReadValue<uint>(FName_i);

		ushort blockKey = (ushort)(comparisonID >> 16);
		ushort innerKey = (ushort)comparisonID;
		int blockStartOffset = 0x30;
		
		IntPtr blockPtr = IntPtr.Add(vars.FNamePoolBase, ((int)(blockKey) + 2) * 8 + blockStartOffset);
		ulong FNameEntryAddress = memory.ReadValue<ulong>(blockPtr) + 2 * (ulong)innerKey;

		ushort Header = memory.ReadValue<ushort>((IntPtr)FNameEntryAddress);
		IntPtr FNameStringStartAddress = (IntPtr)(FNameEntryAddress + 2);

		short stringLength = (short)(Header >> 6);

		if (stringLength <= 0) return "";

		string FNameString = memory.ReadString(FNameStringStartAddress, stringLength);

		return FNameString;
	});

	vars.objectToString = (Func<IntPtr, string>)((object_i) => {

		if (object_i == IntPtr.Zero) return null;
		
		IntPtr FName = IntPtr.Add(object_i, vars.offsets["UObject"]["Name"]);

		return vars.FNameToString(FName);
	});
	
	vars.getObjectOfTArrayByIndex = (Func<IntPtr, int, IntPtr>)((TArray_i, index_i) => {

		IntPtr TArrayObject = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(TArray_i, 0x08 * index_i));
		return TArrayObject;
	});

	// Loop through a specific loaded level and find the actor's address. Returns the first instance of the actor.
	vars.getActorInLevel = (Func<string, string, IntPtr>)((actorString_i, levelString_i) => {
		
		uint numOfLevels = memory.ReadValue<uint>((IntPtr)IntPtr.Add(vars.watchers["UWorld"].Current, vars.offsets["UWorld"]["Levels"] + 0x08));
		IntPtr levelTArray = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(vars.watchers["UWorld"].Current, vars.offsets["UWorld"]["Levels"]));

		IntPtr levelAddress = IntPtr.Zero;
		string levelString = "";
		
		for (int index = 0; index < numOfLevels; index++)
		{
			levelAddress = vars.getObjectOfTArrayByIndex(levelTArray, index);
			if (levelAddress == IntPtr.Zero) continue;
			IntPtr outer = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(levelAddress, vars.offsets["UObject"]["Outer"]));
			levelString = vars.objectToString(outer);
			if (levelString == levelString_i) break;
		}

		if (levelString != levelString_i) return IntPtr.Zero;

		uint numOfActors = memory.ReadValue<uint>((IntPtr)IntPtr.Add(levelAddress, vars.offsets["ULevel"]["Actors"] + 0x08));
		IntPtr actorTArray = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(levelAddress, vars.offsets["ULevel"]["Actors"]));

		for (int index = 0; index < numOfActors; index++)
		{
			IntPtr actorAddress = vars.getObjectOfTArrayByIndex(actorTArray, index);
			if (actorAddress == IntPtr.Zero) continue;
			string actorString = vars.objectToString(actorAddress);
			if (actorString == actorString_i) return actorAddress;
		}

		return IntPtr.Zero;
	});

	// Dump the currently loaded level names.
	vars.dumpLevelNames = (Func<bool>)(() => {
		
		IntPtr levelTArrayAddress = (IntPtr)IntPtr.Add(vars.watchers["UWorld"].Current, vars.offsets["UWorld"]["Levels"]);
		IntPtr levelCountAddress = levelTArrayAddress + 0x08;

		uint numOfLevels = memory.ReadValue<uint>(levelCountAddress);
		IntPtr levelTArray = memory.ReadValue<IntPtr>(levelTArrayAddress);

		string message = "";
		
		for (int index = 0; index < numOfLevels; index++)
		{
			IntPtr levelAddress = vars.getObjectOfTArrayByIndex(levelTArray, index);
			if (levelAddress == IntPtr.Zero) continue;
			IntPtr outer = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(levelAddress, vars.offsets["UObject"]["Outer"]));
			string levelString = vars.objectToString(outer);

			message += "Level " + index.ToString() + ":\n" + levelString + "\n";
		}

		print(message.Trim());
		return true;
	});

	// Looks through the GObjects array to look for classes according to the offsetsToFind dictionary.
	vars.searchForOffsets_GObjects = (Func<bool>)(() => {

		if (vars.offsetsToFind.Count == 0) return true;

		List<string> classesFound = new List<string> {};

		IntPtr GObjects = memory.ReadValue<IntPtr>((IntPtr)vars.GObjectsPointer);

		int numChunks = memory.ReadValue<int>((IntPtr)IntPtr.Add(GObjects, vars.offsets["TUObjectArray"]["NumChunks"]));
		int numElements = memory.ReadValue<int>((IntPtr)IntPtr.Add(GObjects, vars.offsets["TUObjectArray"]["NumElements"]));

		int elementsPerChunk = 0x10000;

		IntPtr chunkArray = memory.ReadValue<IntPtr>(GObjects);

		// Start going through each object in each object chunk and look for class definitions.
		for (int chunk = 0; chunk < numChunks; chunk++)
		{
			int maxInChunkIndex = (chunk != numChunks - 1) ? elementsPerChunk : numElements % elementsPerChunk;

			IntPtr inChunkAddress = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(chunkArray, 0x08 * chunk));

			if (inChunkAddress == IntPtr.Zero) continue;

			for (int inChunk = 0; inChunk < maxInChunkIndex; inChunk++)
			{
				int chunkOffset = 0x18 * inChunk + 0x08;

				IntPtr thisObj = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(inChunkAddress, chunkOffset));

				if (thisObj == IntPtr.Zero) continue;

				string objName = vars.objectToString(thisObj);
				string classNameOfObj = vars.objectToString(memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(thisObj, vars.offsets["UObject"]["Class"])));

				// Look into a class declaration.
				if (classNameOfObj == "BlueprintGeneratedClass")
				{
					// Search through the vars.offsetsToFind dictionary to see if the FName matches any entry.
					foreach (string parent in vars.offsetsToFind.Keys)
					{
						if (parent != objName) continue;

						classesFound.Add(parent);
						vars.offsets[parent] = new Dictionary<string, int>{};

						List<string> propertiesFound = new List<string> {};
						IntPtr currentProperty = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(thisObj, vars.offsets["UStruct"]["ChildProperties"]));

						int maxSearchableProperties = 1000;
						for (int propertyCount = 1; currentProperty != IntPtr.Zero; propertyCount++)
						{
							if (propertyCount > maxSearchableProperties)
							{
								print("WARNING: currentProperty in searchForOffsets_GObjects exceeded maxSearchableProperties for " + parent);
								break;
							}

							IntPtr currentPropertyFName = IntPtr.Add(currentProperty, vars.offsets["FField"]["Name"]);
							string currentPropertyNameStr = vars.FNameToString(currentPropertyFName);

							// Search through the vars.offsetsToFind dictionary to see if the propertyNames of parent match any entry.
							foreach (string child in vars.offsetsToFind[parent])
							{
								if (child.ToLower() != currentPropertyNameStr.ToLower()) continue;
								
								int propertyOffset = memory.ReadValue<int>((IntPtr)IntPtr.Add(currentProperty, vars.offsets["UStruct"]["Offset"]));
								vars.offsets[parent][child] = propertyOffset;
								print(parent + "." + child + ": 0x" + propertyOffset.ToString("X"));
								propertiesFound.Add(child);
							}

							currentProperty = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(currentProperty, vars.offsets["FField"]["Next"]));
						}

						// Remove found properties from offsetsToFind[parent]
						foreach (string property in propertiesFound)
						{
							vars.offsetsToFind[parent].Remove(property);
						}

						if (vars.offsetsToFind[parent].Count > 0)
						{
							string propertyList = "";
							foreach (string child in vars.offsetsToFind[parent])
							{
								propertyList += "\n" + child;
							}
							string message = parent + " class's properties were not all found. Autosplitter may not work.\nRemaining properties:" + propertyList;
							print(message);
							MessageBox.Show(message, "WARNING: Autosplitter May Not Work", MessageBoxButtons.OK, MessageBoxIcon.Warning);
						}
					}
				}
			}
		}

		// Remove found classes from offsetsToFind if it has no other properties to find.
		foreach (string parent in classesFound)
		{
			if (vars.offsetsToFind[parent].Count == 0) vars.offsetsToFind.Remove(parent);
		}

		if (vars.offsetsToFind.Count > 0)
		{
			string classList = "";
			foreach (string parent in vars.offsetsToFind.Keys)
			{
				classList += "\n" + parent;
			}
			string message = "Some classes were not found yet.\nRemaining classes:" + classList;
			print(message);
		}
		else
		{
			print("All classes were found!");
		}

		return true;
	});

	// Looks through the instance's class and finds property offsets according to the offsetsToFind dictionary.
	vars.searchForOffsets_Instance = (Func<IntPtr, bool>)((objectInstance_i) => {

		if (objectInstance_i == IntPtr.Zero) return false;

		IntPtr classObj = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(objectInstance_i, vars.offsets["UObject"]["Class"]));
		string classNameOfObj = vars.objectToString(classObj);

		// Search through the vars.offsetsToFind dictionary to see if the FName matches any entry.
		foreach (string parent in vars.offsetsToFind.Keys)
		{
			if (parent != classNameOfObj) continue;

			vars.offsets[parent] = new Dictionary<string, int>{};

			List<string> propertiesFound = new List<string> {};
			IntPtr currentProperty = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(classObj, vars.offsets["UStruct"]["ChildProperties"]));

			int maxSearchableProperties = 1000;
			for (int propertyCount = 1; currentProperty != IntPtr.Zero; propertyCount++)
			{
				if (propertyCount >= maxSearchableProperties)
				{
					print("WARNING: currentProperty in searchForOffsets_Instance exceeded maxSearchableProperties for " + parent);
					break;
				}

				IntPtr currentPropertyFName = IntPtr.Add(currentProperty, vars.offsets["FField"]["Name"]);
				string currentPropertyNameStr = vars.FNameToString(currentPropertyFName);

				if (currentPropertyNameStr == "None" || currentPropertyNameStr == "") break;

				// Search through the vars.offsetsToFind dictionary to see if the propertyNames of parent match any entry.
				foreach (string child in vars.offsetsToFind[parent])
				{
					if (child != currentPropertyNameStr) continue;

					int propertyOffset = memory.ReadValue<int>((IntPtr)IntPtr.Add(currentProperty, vars.offsets["UStruct"]["Offset"]));
					vars.offsets[parent][child] = propertyOffset;
					print(parent + "." + child + ": 0x" + propertyOffset.ToString("X"));
					propertiesFound.Add(child);
				}

				currentProperty = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(currentProperty, vars.offsets["FField"]["Next"]));
			}

			// Remove found properties from offsetsToFind[parent]
			foreach (string property in propertiesFound)
			{
				vars.offsetsToFind[parent].Remove(property);
			}

			if (vars.offsetsToFind[parent].Count > 0)
			{
				string propertyList = "";
				foreach (string child in vars.offsetsToFind[parent])
				{
					propertyList += "\n" + child;
				}
				string message = parent + " class's properties were not all found. Autosplitter may not work.\nRemaining properties:" + propertyList;
				print(message);
				MessageBox.Show(message, "WARNING: Autosplitter May Not Work", MessageBoxButtons.OK, MessageBoxIcon.Warning);
			}

			// Remove the class from offsetsToFind if it has no other properties to find.
			if (vars.offsetsToFind[parent].Count == 0) vars.offsetsToFind.Remove(parent);

			return true; // Early return since we already found the class we wanted; helps to not break the foreach.
		}

		return false;
	});

	// Scans for the first instance of an object given its FName string and what map it's located in.
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
	
	// Credit to Micrologist and Meta, this func was found in the Stray asl.
	vars.GetStaticPointerFromSig = (Func<string, int, IntPtr>) ( (signature, instructionOffset) => {
		var scanner = new SignatureScanner(game, modules.First().BaseAddress, (int)modules.First().ModuleMemorySize);
		var pattern = new SigScanTarget(signature);
		var location = scanner.Scan(pattern);
		if (location == IntPtr.Zero) return IntPtr.Zero;
		int offset = game.ReadValue<int>((IntPtr)location + instructionOffset);
		return (IntPtr)location + offset + instructionOffset + 0x4;
	});

	// Returns a dictionary of the current completed objectives. Entries: MostCompleted, LeastCompleted, CountTotal.
	vars.getPlayersObjectiveInfo = (Func<Dictionary<string, int>>)(() => {

		IntPtr playerStateTArray = vars.watchers["PlayerStateArray"].Current;
		int playerCount = vars.watchers["PlayerCount"].Current;
		
		int mostObjectiveIndex = 0;
		int leastObjectiveIndex = 255;
		int totalObjectives = 0;
		for (int index = 0; index < playerCount; index++)
		{
			IntPtr playerState = vars.getObjectOfTArrayByIndex(playerStateTArray, index);
			bool playerDead = memory.ReadValue<bool>((IntPtr)IntPtr.Add(playerState, vars.offsets["BP_MyPlayerState_C"]["IsDead"]));
			if (playerDead) continue;
			int playerObjectivesComplete = memory.ReadValue<int>((IntPtr)IntPtr.Add(playerState, vars.offsets["BP_MyPlayerState_C"]["OldObjective"]));
			if (playerObjectivesComplete > mostObjectiveIndex) mostObjectiveIndex = playerObjectivesComplete;
			if (playerObjectivesComplete < leastObjectiveIndex) leastObjectiveIndex = playerObjectivesComplete;
			int playerObjectiveTotal = memory.ReadValue<int>((IntPtr)IntPtr.Add(playerState, vars.offsets["BP_MyPlayerState_C"]["ObjectiveList"] + 0x08));
			if (playerObjectiveTotal > totalObjectives) totalObjectives = playerObjectiveTotal;
		}

		var retDict = new Dictionary<string, int> {
			{"MostCompleted", mostObjectiveIndex},
			{"LeastCompleted", leastObjectiveIndex},
			{"CountTotal", totalObjectives},
		};
		return retDict;
	});
	
	vars.areAllPlayersDead = (Func<bool>)(() => {

		IntPtr playerStateTArray = vars.watchers["PlayerStateArray"].Current;
		int playerCount = vars.watchers["PlayerCount"].Current;

		for (int index = 0; index < playerCount; index++)
		{
			IntPtr playerState = vars.getObjectOfTArrayByIndex(playerStateTArray, index);
			bool isDead = memory.ReadValue<bool>((IntPtr)IntPtr.Add(playerState, vars.offsets["BP_MyPlayerState_C"]["IsDead"]));
			if (!isDead) return false;
		}
		return true;
	});

	vars.areAllPlayersSitting = (Func<bool>)(() => {

		IntPtr playerTArray = vars.watchers["PlayerArray"].Current;
		int playerCount = vars.watchers["PlayerCount"].Current;
		
		for (int index = 0; index < playerCount; index++)
		{
			IntPtr player = vars.getObjectOfTArrayByIndex(playerTArray, index);
			bool isSitting = memory.ReadValue<bool>((IntPtr)IntPtr.Add(player, vars.offsets["BP_Character_C"]["IsSitting"]));
			if (!isSitting) return false;
		}
		return true;
	});

	#endregion Functions
	#region SigScanning

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
		vars.FNamePoolBase = (IntPtr)(sigLocation + 6 + disp);
	}

	if (vars.FNamePoolBase == IntPtr.Zero)
	{
		MessageBox.Show("FNamePool could not be found via given signature\n" + sig, "ERROR: Autosplitter Will Not Work", MessageBoxButtons.OK, MessageBoxIcon.Error);
	}

	ulong FNamePoolOffset = (ulong)((ulong)vars.FNamePoolBase - (ulong)modules.First().BaseAddress);

	// Find GUObjects via sigscan.

	sig = "48 89 5C 24 08 57 48 83 EC 20 33 FF C7 41 04 FF FF FF FF";
	insOffset = 0x8C;
	
	vars.GObjectsPointer = vars.GetStaticPointerFromSig(sig, insOffset);

	ulong GObjectsOffset = (ulong)((ulong)vars.GObjectsPointer - (ulong)modules.First().BaseAddress);

	#endregion SigScanning

	// Initialize certain variables.

	// Used for in-contract actor accessing (ConsoleKeypass, ReactorControl Terminal, etc.)
	vars.importantActors = new Dictionary<string, IntPtr> {};

	// Dictionary of necessary offsets to find via the vars.searchForOffsets_GObjects or vars.searchForObjects_Instace function.
	vars.offsetsToFind = new Dictionary<string, List<string>> {
		{"BP_ParentCharacter_C", new List<string> {
			"Health",
		}},
		{"BP_MyGameState_C", new List<string> {
			"In Game Player State ",
			"GameManager",
			"ActualMonster",
		}},
		{"BP_GameManager_C", new List<string> {
			"Monster",
			"Players",
		}},
		{"BP_MyPlayerState_C", new List<string> {
			"ObjectiveList",
			"OldObjective",
			"IsDead",
		}},
		{"BP_Character_C", new List<string> {
			"LastInteract Actor",
			"IsSitting",
		}},
		{"BP_MyPlayerController_C", new List<string> {
			"In Widget to Focus",
		}},
		{"BP_LeverShip_C", new List<string> {
			"IsUsed",
			"ActivatedOnce",
		}},
		{"BP_ConsoleKeypass_C", new List<string> {
			"max",
			"Current",
		}},
		{"BP_ReactorControl_Terminal_REFACT_C", new List<string> {
			"Finished",
		}},
		{"BP_GAZ_Control_Terminal_REFACT_C", new List<string> {
			"BP_Puzzle",
		}},
		{"BP_Laboratory_PuzzleContainer_C", new List<string> {
			"Purge",
		}},
		{"BP_BaseMonster_C", new List<string> {
			"Health",
			"MaxHealth",
		}},
		{"BP_Monster_Poulpi_C", new List<string> {
			"EyeRightCut",
			"EyeLeftCut",
			"BreakHead",
		}},
		{"BP_Monster_Michel_C", new List<string> {
			"HeadBreak_Left",
			"HeadBreak_Right",
		}},
		{"BP_Monster_Eye_C", new List<string> {
			"HaveShield",
			"DropOil",
			"BreakGlass",
		}},
		{"BP_BigRobot_C", new List<string> {
			"Gatling",
		}},
		{"BP_Gatling_C", new List<string> {
			"CanFire",
			"LifeValue",
		}},
	};

	vars.searchForOffsets_GObjects();
	
	// Watcher variables used in code.

	vars.watchers = new MemoryWatcherList {

		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer)) {Name = "UWorld" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer, vars.offsets["UWorld"]["GameState"], vars.offsets["BP_MyGameState_C"]["GameManager"], vars.offsets["BP_GameManager_C"]["Monster"])) {Name = "Monster" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer, vars.offsets["UWorld"]["GameState"], vars.offsets["BP_MyGameState_C"]["GameManager"], vars.offsets["BP_GameManager_C"]["Players"])) {Name = "PlayerArray" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer, vars.offsets["UWorld"]["GameState"], vars.offsets["BP_MyGameState_C"]["In Game Player State "])) {Name = "PlayerStateArray" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<int>(new DeepPointer(vars.UWorldPointer, vars.offsets["UWorld"]["GameState"], vars.offsets["BP_MyGameState_C"]["In Game Player State "] + 0x08)) {Name = "PlayerCount" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer, vars.offsets["UWorld"]["OwningGameInstance"], vars.offsets["UGameInstance"]["LocalPlayers"], 0x0, vars.offsets["UPlayer"]["PlayerController"], vars.offsets["AController"]["Character"], vars.offsets["BP_Character_C"]["LastInteract Actor"])) {Name = "LocalPlayer_InteractingActor" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorldPointer, vars.offsets["UWorld"]["OwningGameInstance"], vars.offsets["UGameInstance"]["LocalPlayers"], 0x0, vars.offsets["UPlayer"]["PlayerController"], vars.offsets["BP_MyPlayerController_C"]["In Widget to Focus"])) {Name = "LocalPlayer_FocusedWidget" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<byte>(new DeepPointer(vars.UWorldPointer, vars.offsets["UWorld"]["GameState"], vars.offsets["BP_MyGameState_C"]["ActualMonster"])) {Name = "MonsterEnum" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},

	};

	// Print the game information.

	vars.watchers.UpdateAll(game);

	print("UWorldOffset:\n0x" + UWorldOffset.ToString("X") + "\nFNamePoolOffset:\n0x" + FNamePoolOffset.ToString("X") + "\nGObjectsOffset:\n0x" + GObjectsOffset.ToString("X"));

	vars.dumpLevelNames();

	IntPtr monsterAddress = vars.watchers["Monster"].Current;
	IntPtr interactingActorAddress = vars.watchers["LocalPlayer_InteractingActor"].Current;
	IntPtr interactingWidgetAddress = vars.watchers["LocalPlayer_FocusedWidget"].Current;

	string output = "";

	if (monsterAddress != IntPtr.Zero)
	{
		output += "\nMonster: 0x" + monsterAddress.ToString("X") + "\n" + vars.objectToString(monsterAddress);
	}
	if (interactingActorAddress != IntPtr.Zero)
	{
		output += "\nInteracting Actor: 0x" + interactingActorAddress.ToString("X") + "\n" + vars.objectToString(interactingActorAddress);
	}
	if (interactingWidgetAddress != IntPtr.Zero)
	{
		output += "\nInteracting Widget: 0x" + interactingWidgetAddress.ToString("X") + "\n" + vars.objectToString(interactingWidgetAddress);
	}

	if (output != "") print(output.Trim());
}

update
{
	vars.watchers.UpdateAll(game);

	// Search for offsets when the player force looks at the ship screen.
	if (vars.objectToString(vars.watchers["LocalPlayer_FocusedWidget"].Current) == "WBP_Main_ShipScreen_C" && vars.watchers["LocalPlayer_FocusedWidget"].Old == IntPtr.Zero)
	{
		vars.searchForOffsets_GObjects();
	}

	// Clear the importantActors if the world changes.
	if (vars.watchers["UWorld"].Changed)
	{
		vars.importantActors.Clear();
	}

	// Search for importantActors by level.
	Dictionary<string, string> actorMapDict = new Dictionary<string, string> {
		{"BP_LeverShip_C", "SpaceShip"},
		{"BP_ConsoleKeypass_C", "SpaceShip"},
		{"BP_ReactorControl_Terminal_REFACT_C", "Hawking_StaticMap_Enginery"},
		{"BP_GAZ_Control_Terminal_REFACT_C", "Hawking_StaticMap_Laboratory"},
	};
	foreach (string actorName in actorMapDict.Keys)
	{
		string mapName = actorMapDict[actorName];
		vars.scanForActorIfNeeded(actorName, mapName);
	}

	// Create debug/coding tools.

	if (vars.watchers["LocalPlayer_InteractingActor"].Changed && vars.watchers["LocalPlayer_InteractingActor"].Current != IntPtr.Zero)
	{
		// Actors.

		IntPtr objectAddress = vars.watchers["LocalPlayer_InteractingActor"].Current;
		string objectString = vars.objectToString(objectAddress);

		print("0x" + objectAddress.ToString("X") + ": ACTOR\nPlayer interacted with actor " + objectString);
	}
	if (vars.watchers["LocalPlayer_FocusedWidget"].Changed && vars.watchers["LocalPlayer_FocusedWidget"].Current != IntPtr.Zero)
	{
		// Widgets.

		IntPtr widgetAddress = vars.watchers["LocalPlayer_FocusedWidget"].Current;
		string widgetString = vars.objectToString(widgetAddress);

		print("0x" + widgetAddress.ToString("X") + ": WIDGET\nPlayer interacted with widget " + widgetString);
	}
	if (vars.watchers["Monster"].Changed && vars.watchers["Monster"].Current != IntPtr.Zero)
	{
		// Monster.

		IntPtr monsterAddress = vars.watchers["Monster"].Current;
		string monsterString = vars.objectToString(monsterAddress);

		vars.searchForOffsets_Instance(vars.watchers["Monster"].Current);

		if (monsterString == "BP_BigRobot_C" && !vars.offsets.ContainsKey("BP_Gatling_C"))
		{
			IntPtr gatlingInstance = IntPtr.Zero;
			do // A safety since it takes a moment for the gatling to initialize.
			{
				gatlingInstance = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(monsterAddress, vars.offsets["BP_BigRobot_C"]["Gatling"]));
				vars.searchForOffsets_Instance(gatlingInstance);
			} while (gatlingInstance == IntPtr.Zero);
		}

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
			bool isUsed = memory.ReadValue<bool>((IntPtr)IntPtr.Add(vars.importantActors["BP_LeverShip_C"], vars.offsets["BP_LeverShip_C"]["IsUsed"]));
			bool activatedOnce = memory.ReadValue<bool>((IntPtr)IntPtr.Add(vars.importantActors["BP_LeverShip_C"], vars.offsets["BP_LeverShip_C"]["ActivatedOnce"]));
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
	vars.objectivesComplete = 0;
	vars.hasDoneFinalSplit = false;
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

	if (vars.areAllPlayersDead()) return false; // Just a safety in case game does weird things with the game state once everyone is dead.

	if (vars.hasDoneFinalSplit) return false; // If hasDoneFinalSplit is true, we shouldn't need any more splits anyhow.

	// Updates for objectives.
	Dictionary<string, int> objectiveInfo = vars.getPlayersObjectiveInfo();
	bool anObjectiveWasDone = false;
	if (objectiveInfo["MostCompleted"] > vars.objectivesComplete)
	{
		anObjectiveWasDone = true;
		vars.objectivesComplete = objectiveInfo["MostCompleted"];
		print("Objectives Complete: " + objectiveInfo["MostCompleted"] + "/" + objectiveInfo["CountTotal"]);
	}

	if (settings["split_CompleteLastObjective"] || settings["split_CompleteAnyObjective"])
	{
		string printStr = (settings["split_CompleteLastObjective"]) ? "split_CompleteLastObjective" : "split_CompleteAnyObjective";

		bool lastObjectiveWasDoneByAll = (objectiveInfo["LeastCompleted"] == objectiveInfo["CountTotal"]);
		if (lastObjectiveWasDoneByAll)
		{
			vars.hasDoneFinalSplit = true;
			print(printStr);
			return true;
		}
		// For a failsafe that has occured to me a few times, everyone sitting down after the mission also counts for this split.
		if (vars.areAllPlayersSitting())
		{
			vars.hasDoneFinalSplit = true;
			print(printStr + " (areAllPlayersSitting)");
			return true;
		}

		if (settings["split_CompleteAnyObjective"] && anObjectiveWasDone && objectiveInfo["MostCompleted"] < objectiveInfo["CountTotal"])
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
					uint keypassMax = memory.ReadValue<uint>((IntPtr)IntPtr.Add(actor, vars.offsets["BP_ConsoleKeypass_C"]["max"]));
					uint keypassCurrent = memory.ReadValue<uint>((IntPtr)IntPtr.Add(actor, vars.offsets["BP_ConsoleKeypass_C"]["Current"]));
					completed = (keypassCurrent >= keypassMax);
					break;
				case "BP_ReactorControl_Terminal_REFACT_C":
					bool finished = memory.ReadValue<bool>((IntPtr)IntPtr.Add(actor, vars.offsets["BP_ReactorControl_Terminal_REFACT_C"]["Finished"]));
					completed = finished;
					break;
				case "BP_GAZ_Control_Terminal_REFACT_C":
					IntPtr puzzle = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(actor, vars.offsets["BP_GAZ_Control_Terminal_REFACT_C"]["BP_Puzzle"]));
					bool purge = memory.ReadValue<bool>((IntPtr)IntPtr.Add(puzzle, vars.offsets["BP_Laboratory_PuzzleContainer_C"]["Purge"]));
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
		double health = memory.ReadValue<double>((IntPtr)IntPtr.Add(monster, vars.offsets["BP_BaseMonster_C"]["Health"]));
		double maxHealth = memory.ReadValue<double>((IntPtr)IntPtr.Add(monster, vars.offsets["BP_BaseMonster_C"]["MaxHealth"]));

		switch (monsterEnum)
		{
			default:
				break;
			case 2: // Octopus
				bool eyeRightCut = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.offsets["BP_Monster_Poulpi_C"]["EyeRightCut"]));
				bool eyeLeftCut = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.offsets["BP_Monster_Poulpi_C"]["EyeLeftCut"]));
				bool breakHead = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.offsets["BP_Monster_Poulpi_C"]["BreakHead"]));
				if (settings["split_MonsterSpecific_Octopus_CutAnEye"])
				{
					int damageCount = 0;
					if (eyeRightCut) damageCount++;
					if (eyeLeftCut) damageCount++;
					if (breakHead) damageCount++;
					if (vars.monsterPhase < damageCount && damageCount < 3)
					{
						vars.monsterPhase = damageCount;
						print("split_MonsterSpecific_Octopus_CutAnEye");
						return true;
					}
				}
				break;
			case 3: // Mike
				bool headBreakLeft = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.offsets["BP_Monster_Michel_C"]["HeadBreak_Left"]));
				bool headBreakRight = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.offsets["BP_Monster_Michel_C"]["HeadBreak_Right"]));
				if (settings["split_MonsterSpecific_Mike_BreakAFace"])
				{
					int damageCount = 0;
					if (headBreakLeft) damageCount++;
					if (headBreakRight) damageCount++;
					if (vars.monsterPhase < damageCount)
					{
						vars.monsterPhase = damageCount;
						print("split_MonsterSpecific_Mike_BreakAFace");
						return true;
					}
				}
				break;
			case 4: // The Eye
				bool haveShield = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.offsets["BP_Monster_Eye_C"]["HaveShield"]));
				bool dropOil = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.offsets["BP_Monster_Eye_C"]["DropOil"]));
				bool breakGlass = memory.ReadValue<bool>((IntPtr)IntPtr.Add(monster, vars.offsets["BP_Monster_Eye_C"]["BreakGlass"]));
				if (settings["split_MonsterSpecific_TheEye_LoseShield"])
				{
					if (vars.monsterPhase < 1 && !haveShield)
					{
						vars.monsterPhase = 1;
						print("split_MonsterSpecific_TheEye_LoseShield");
						return true;
					}
				}
				if (settings["split_MonsterSpecific_TheEye_BreakGlass"])
				{
					if (vars.monsterPhase < 2 && breakGlass)
					{
						vars.monsterPhase = 2;
						print("split_MonsterSpecific_TheEye_BreakGlass");
						return true;
					}
				}
				if (settings["split_MonsterSpecific_TheEye_StartDroppingOil"])
				{
					if (vars.monsterPhase < 3 && dropOil)
					{
						vars.monsterPhase = 3;
						print("split_MonsterSpecific_TheEye_StartDroppingOil");
						return true;
					}
				}
				break;
			case 5: // Ghost
				if (settings["split_MonsterSpecific_Ghost_LoseThirdOfHealth"])
				{
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
					IntPtr gatlingGun = memory.ReadValue<IntPtr>((IntPtr)IntPtr.Add(monster, vars.offsets["BP_BigRobot_C"]["Gatling"]));
					if (gatlingGun != IntPtr.Zero)
					{
						bool canFire = memory.ReadValue<bool>((IntPtr)IntPtr.Add(gatlingGun, vars.offsets["BP_Gatling_C"]["CanFire"]));
						double lifeValue = memory.ReadValue<double>((IntPtr)IntPtr.Add(gatlingGun, vars.offsets["BP_Gatling_C"]["LifeValue"]));
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
