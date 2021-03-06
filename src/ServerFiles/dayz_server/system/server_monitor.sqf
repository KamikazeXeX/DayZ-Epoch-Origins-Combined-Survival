private ["_nul","_result","_pos","_wsDone","_dir","_isOK","_countr","_objWpnTypes","_objWpnQty","_dam","_selection","_totalvehicles","_object","_idKey","_type","_ownerID","_worldspace","_intentory","_hitPoints","_fuel","_damage","_key","_vehLimit","_hiveResponse","_objectCount","_codeCount","_data","_status","_val","_traderid","_retrader","_traderData","_id","_lockable","_debugMarkerPosition","_vehicle_0","_bQty","_vQty","_BuildingQueue","_objectQueue","_superkey","_shutdown","_res","_hiveLoaded"];

dayz_versionNo = 		getText(configFile >> "CfgMods" >> "DayZ" >> "version");
dayz_hiveVersionNo = 	getNumber(configFile >> "CfgMods" >> "DayZ" >> "hiveVersion");

_hiveLoaded = false;

waitUntil{initialized}; //means all the functions are now defined

diag_log "HIVE: Starting";

waituntil{isNil "sm_done"}; // prevent server_monitor be called twice (bug during login of the first player)
	
// Custom Configs
if(isnil "MaxVehicleLimit") then {
	MaxVehicleLimit = 50;
};

if(isnil "MaxDynamicDebris") then {
	MaxDynamicDebris = 100;
};
if(isnil "MaxAmmoBoxes") then {
	MaxAmmoBoxes = 3;
};
if(isnil "MaxMineVeins") then {
	MaxMineVeins = 50;
};
// Custon Configs End

if (isServer && isNil "sm_done") then {

	serverVehicleCounter = [];
	_hiveResponse = [];

	for "_i" from 1 to 5 do {
		diag_log "HIVE: trying to get objects";
		_key = format["CHILD:302:%1:", dayZ_instance];
		_hiveResponse = _key call server_hiveReadWrite;  
		if ((((isnil "_hiveResponse") || {(typeName _hiveResponse != "ARRAY")}) || {((typeName (_hiveResponse select 1)) != "SCALAR")})) then {
			if ((_hiveResponse select 1) == "Instance already initialized") then {
				_superkey = profileNamespace getVariable "SUPERKEY";
				_shutdown = format["CHILD:400:%1:", _superkey];
				_res = _shutdown call server_hiveReadWrite;
				diag_log ("HIVE: attempt to kill.. HiveExt response:"+str(_res));
			} else {
				diag_log ("HIVE: connection problem... HiveExt response:"+str(_hiveResponse));
			
			};
			_hiveResponse = ["",0];
		} 
		else {
			diag_log ("HIVE: found "+str(_hiveResponse select 1)+" objects" );
			_i = 99; // break
		};
	};
	
	_BuildingQueue = [];
	_objectQueue = [];
	
	if ((_hiveResponse select 0) == "ObjectStreamStart") then {
	
		// save superkey
		profileNamespace setVariable ["SUPERKEY",(_hiveResponse select 2)];
		
		_hiveLoaded = true;
	
		diag_log ("HIVE: Commence Object Streaming...");
		_key = format["CHILD:302:%1:", dayZ_instance];
		_objectCount = _hiveResponse select 1;
		_bQty = 0;
		_vQty = 0;
		for "_i" from 1 to _objectCount do {
			_hiveResponse = _key call server_hiveReadWriteLarge;
			//diag_log (format["HIVE dbg %1 %2", typeName _hiveResponse, _hiveResponse]);
			if ((_hiveResponse select 2) isKindOf "ModularItems") then {
				_BuildingQueue set [_bQty,_hiveResponse];
				_bQty = _bQty + 1;
			} else {
				_objectQueue set [_vQty,_hiveResponse];
				_vQty = _vQty + 1;
			};
		};
		diag_log ("HIVE: got " + str(_bQty) + " Epoch Objects and " + str(_vQty) + " Vehicles");
	};
	
	// # NOW SPAWN OBJECTS #
	_totalvehicles = 0;
	{
		_idKey = 		_x select 1;
		_type =			_x select 2;
		_ownerID = 		_x select 3;

		_worldspace = 	_x select 4;
		_intentory =	_x select 5;
		_hitPoints =	_x select 6;
		_fuel =			_x select 7;
		_damage = 		_x select 8;
		
		_dir = 0;
		_pos = [0,0,0];
		_extendedPos = "";
		_vector = [];
		_ownerPUID = "";

		_vehicleLock = "LOCKED";
		_buildStage = 0;
		_skinFiles = [];
		_animationStates = [];
		
		_wsDone = false;
		_worldspaceLength = count _worldspace;
		if (_worldspaceLength >= 2) then {
			_dir = _worldspace select 0;
			_pos = _worldspace select 1;
			// convert precise base building position string to position
			// do not expect precise direction, because it is not needed if using build vectors
			if (typeName (_pos) == "STRING") then {
				_extendedPos = _pos;
				_pos = call compile _pos;
			};
			_wsDone = true;
		};

		if (_worldspaceLength >= 3) then {
			// parse build vectors and owner steamid
			if (_worldspaceLength >= 5) then {
				/*
				_vector = _worldspace select 2;
				_ownerPUID = _worldspace select 3;
				*/
				_tmp = _worldspace select 2;
				if (count _tmp == 2) then {
					if (((count (_tmp select 0)) == 3) && ((count (_tmp select 1)) == 3)) then {
                        _vector = _tmp;
                    };
                };
			
				_tmp = _worldspace select 3;
				if (typeName(_tmp) == "STRING") then {
					_ownerPUID = _tmp;
				};
			};
			// the extended Attributes are in the last array
			_exAttr = _worldspace select (_worldspaceLength - 1);

			if ((typeName(_exAttr)) == "ARRAY") then {
				if (count _exAttr == 5) then {
					if ((typeName(_exAttr select 0)) == "SCALAR" && 
						(typeName(_exAttr select 1)) == "SCALAR" && 
						(typeName(_exAttr select 2)) == "ARRAY" && 
						(typeName(_exAttr select 3)) == "ARRAY" && 
						(typeName(_exAttr select 4)) == "ARRAY") then 
					{
						if (_exAttr select 0 == 0) then {
							_vehicleLock = "UNLOCKED"; 
						} else {
							_vehicleLock = "LOCKED";
						};
						_buildStage = _exAttr select 1;
						_skinFiles = _exAttr select 2;
						_animationStates = _exAttr select 3;
					} else {
						if ((typeName(_exAttr select 0)) == "STRING" && 
							(typeName(_exAttr select 1)) == "SCALAR" && 
							(typeName(_exAttr select 2)) == "ARRAY" && 
							(typeName(_exAttr select 3)) == "ARRAY" && 
							(typeName(_exAttr select 4)) == "ARRAY") then 
							{
									_vehicleLock = _exAttr select 0;
									_buildStage = _exAttr select 1;
									_skinFiles = _exAttr select 2;
									_animationStates = _exAttr select 3;
							};
						diag_log format["%1 does not look like the extended Attributes format", _exAttr];
						diag_log format["%1,%2,%3,%4,%5 should be SCALAR,SCALAR,SCALAR,ARRAY,ARRAY,ARRAY", typeName(_exAttr select 0), typeName(_exAttr select 1), typeName(_exAttr select 2), typeName(_exAttr select 3), typeName(_exAttr select 4)];
					};
				} else {
					diag_log format["%1 does not match the length of the extended Attributes format", _exAttr];
				};
			};
		};
		
		if (count (_animationStates) == 0) then {
			// Init default values for Origins Vehicles
			// Plow = pluhPredni
			// Wheel Guards = kolaOchrana
			// Sideglass Guards = oknaOchrana
			// Windscreen Guard = predniOknoOchrana
			_validAnimationSources = [["pluhPredni", 1],["kolaOchrana", 1],["oknaOchrana", 1],["predniOknoOchrana", 1]];
			_animationStates = [];
			{
				if (isClass (configFile >> "CfgVehicles" >> _type >> "AnimationSources" >> (_x select 0))) then {
					_animationStates set [count _animationStates,_x];
					diag_log format["Added %1 to Vehicle %2 (%3)", _x, _idKey, _type];
				};
			} forEach _validAnimationSources;
		};

		if (!_wsDone) then {
			if (count _worldspace >= 1) then { _dir = _worldspace select 0; };
			_pos = [getMarkerPos "center",0,4000,10,0,2000,0] call BIS_fnc_findSafePos;
			if (count _pos < 3) then { _pos = [_pos select 0,_pos select 1,0]; };
			diag_log ("MOVED OBJ: " + str(_idKey) + " of class " + _type + " to pos: " + str(_pos));
		};
		

		if (_damage < 1) then {
			//diag_log format["OBJ: %1 - %2", _idKey,_type];
			
			//Create it
			_object = createVehicle [_type, _pos, [], 0, "CAN_COLLIDE"];
			_object setVariable ["lastUpdate",time];
			_object setVariable ["ObjectID", _idKey, true];
			if (typeOf (_object) == "Plastic_Pole_EP1_DZ") then {
				_object setVariable ["AddedPUIDS", _intentory, true];
			};

			_lockable = 0;
			if(isNumber (configFile >> "CfgVehicles" >> _type >> "lockable")) then {
				_lockable = getNumber(configFile >> "CfgVehicles" >> _type >> "lockable");
			};

			// fix for leading zero issues on safe codes after restart
			if (_lockable == 4) then {
				_codeCount = (count (toArray _ownerID));
				if(_codeCount == 3) then {
					_ownerID = format["0%1", _ownerID];
				};
				if(_codeCount == 2) then {
					_ownerID = format["00%1", _ownerID];
				};
				if(_codeCount == 1) then {
					_ownerID = format["000%1", _ownerID];
				};
			};

			if (_lockable == 3) then {
				_codeCount = (count (toArray _ownerID));
				if(_codeCount == 2) then {
					_ownerID = format["0%1", _ownerID];
				};
				if(_codeCount == 1) then {
					_ownerID = format["00%1", _ownerID];
				};
			};

			_object setVariable ["CharacterID", _ownerID, true];
			if (_ownerPUID != "") then {
				_object setVariable ["ownerPUID", _ownerPUID, true];
			};
			
			clearWeaponCargoGlobal  _object;
			clearMagazineCargoGlobal  _object;
			// _object setVehicleAmmo DZE_vehicleAmmo;
			
			_object setdir _dir;
			_object setposATL _pos;
			_object setDamage _damage;

			if (_buildStage > 0) then {
				{
					_object animate _x;
				} forEach getArray (configFile >> "CfgBuildingReceipt" >> _type >> format["Stage%1", _buildStage] >> "animationStates");
				_object setVariable ["buildStage", _buildStage,true];
			};
			
			if ((typeOf _object) in dayz_allowedObjects) then {
				if (DZE_GodModeBase) then {
					_object addEventHandler ["HandleDamage", {false}];
				} else {
					_object addMPEventHandler ["MPKilled",{_this call object_handleServerKilled;}];
				};
				// Test disabling simulation server side on buildables only.
				_object enableSimulation false;
				// used for inplace upgrades && lock/unlock of safe
				_object setVariable ["OEMPos", _pos, true];
				if (_extendedPos != "") then {
					_object setVariable["extendedPos",_extendedPos,true];
				};
				if (count _vector > 0) then {
					_object setVectorDirAndUp _vector;
					_object setVariable["vector",_vector,true];
				};
			};

			if ((count _intentory > 0) && !(typeOf( _object) == "Plastic_Pole_EP1_DZ")) then {
				if (_type in DZE_LockedStorage) then {
					// Fill variables with loot
					_object setVariable ["WeaponCargo", (_intentory select 0),true];
					_object setVariable ["MagazineCargo", (_intentory select 1),true];
					_object setVariable ["BackpackCargo", (_intentory select 2),true];
				} else {

					//Add weapons
					_objWpnTypes = (_intentory select 0) select 0;
					_objWpnQty = (_intentory select 0) select 1;
					_countr = 0;					
					{
						if(_x in (DZE_REPLACE_WEAPONS select 0)) then {
							_x = (DZE_REPLACE_WEAPONS select 1) select ((DZE_REPLACE_WEAPONS select 0) find _x);
						};
						_isOK = 	isClass(configFile >> "CfgWeapons" >> _x);
						if (_isOK) then {
							_object addWeaponCargoGlobal [_x,(_objWpnQty select _countr)];
						};
						_countr = _countr + 1;
					} count _objWpnTypes; 
				
					//Add Magazines
					_objWpnTypes = (_intentory select 1) select 0;
					_objWpnQty = (_intentory select 1) select 1;
					_countr = 0;
					{
						if (_x == "BoltSteel") then { _x = "WoodenArrow" }; // Convert BoltSteel to WoodenArrow
						if (_x == "ItemTent") then { _x = "ItemTentOld" };
						_isOK = 	isClass(configFile >> "CfgMagazines" >> _x);
						if (_isOK) then {
							_object addMagazineCargoGlobal [_x,(_objWpnQty select _countr)];
						};
						_countr = _countr + 1;
					} count _objWpnTypes;

					//Add Backpacks
					_objWpnTypes = (_intentory select 2) select 0;
					_objWpnQty = (_intentory select 2) select 1;
					_countr = 0;
					{
						_isOK = 	isClass(configFile >> "CfgVehicles" >> _x);
						if (_isOK) then {
							_object addBackpackCargoGlobal [_x,(_objWpnQty select _countr)];
						};
						_countr = _countr + 1;
					} count _objWpnTypes;
				};
			};	
			
			if (_object isKindOf "AllVehicles") then {
				{
					_selection = _x select 0;
					_dam = _x select 1;
					if (_selection in dayZ_explosiveParts && _dam > 0.8) then {_dam = 0.8};
					[_object,_selection,_dam] call object_setFixServer;
				} count _hitpoints;

				_object setFuel _fuel;

				if (!((typeOf _object) in dayz_allowedObjects)) then {
					//_object setvelocity [0,0,1];
					_object call fnc_veh_ResetEH;

					if ((count _skinFiles) > 0) then {
						_vehicleInit = "";
						{
							_appendVehicleInit = "";
							if (typeName(_x) == "STRING") then {
								_appendVehicleInit = format ["this setObjectTexture [%1, ""\origins_pack\vehicles\skins\%2""]; ", _forEachIndex, _x];
								_skinFiles set [_forEachIndex,[1,_x]];
							} else {
								_skinLocation = _x select 0;
								_skinFile = _x select 1;
								_skinPath = "";
								switch (_skinLocation) do {
									case 1: {
											_skinPath = "\origins_pack\vehicles\skins\";
										};
								};
								_appendVehicleInit = format ["this setObjectTexture [%1, ""%2%3""]; ", _forEachIndex, _skinPath, _skinFile];
							};
							_vehicleInit = _vehicleInit + _appendVehicleInit;
						} forEach _skinFiles;

						diag_log format["setVehicleInit: %1", _vehicleInit];

						_object setVehicleInit _vehicleInit;
						_object setVariable["skinFiles",_skinFiles,true];
					};

					if ((count _animationStates) > 0) then {
						{ 
							_object animate _x;
						} forEach _animationStates;
						_object setVariable["animationStates",_animationStates,true];
					};

					if(_ownerID != "0" && !(_object isKindOf "Bicycle")) then {
						_object setvehiclelock _vehicleLock;
					};

					_totalvehicles = _totalvehicles + 1;

					// total each vehicle
					serverVehicleCounter set [count serverVehicleCounter,_type];
				};
			};

			//Monitor the object
			PVDZE_serverObjectMonitor set [count PVDZE_serverObjectMonitor,_object];
		};
	} count (_BuildingQueue + _objectQueue);
	// # END SPAWN OBJECTS #

	// preload server traders menu data into cache
	if !(DZE_ConfigTrader) then {
		{
			// get tids
			_traderData = call compile format["menu_%1;",_x];
			if(!isNil "_traderData") then {
				{
					_traderid = _x select 1;

					_retrader = [];

					_key = format["CHILD:399:%1:",_traderid];
					_data = "HiveEXT" callExtension _key;

					//diag_log "HIVE: Request sent";
			
					//Process result
					_result = call compile format ["%1",_data];
					_status = _result select 0;
			
					if (_status == "ObjectStreamStart") then {
						_val = _result select 1;
						//Stream Objects
						//diag_log ("HIVE: Commence Menu Streaming...");
						call compile format["ServerTcache_%1 = [];",_traderid];
						for "_i" from 1 to _val do {
							_data = "HiveEXT" callExtension _key;
							_result = call compile format ["%1",_data];
							call compile format["ServerTcache_%1 set [count ServerTcache_%1,%2]",_traderid,_result];
							_retrader set [count _retrader,_result];
						};
						//diag_log ("HIVE: Streamed " + str(_val) + " objects");
					};

				} forEach (_traderData select 0);
			};
		} forEach serverTraders;
	};

	if (_hiveLoaded) then {
		//  spawn_vehicles
		_vehLimit = MaxVehicleLimit - _totalvehicles;
		if(_vehLimit > 0) then {
			diag_log ("HIVE: Spawning # of Vehicles: " + str(_vehLimit));
			for "_x" from 1 to _vehLimit do {
				[] spawn spawn_vehicles;
			};
		} else {
			diag_log "HIVE: Vehicle Spawn limit reached!";
		};
	};
	
	//  spawn_roadblocks
	diag_log ("HIVE: Spawning # of Debris: " + str(MaxDynamicDebris));
	for "_x" from 1 to MaxDynamicDebris do {
		[] spawn spawn_roadblocks;
	};
	//  spawn_ammosupply at server start 1% of roadblocks
	diag_log ("HIVE: Spawning # of Ammo Boxes: " + str(MaxAmmoBoxes));
	for "_x" from 1 to MaxAmmoBoxes do {
		[] spawn spawn_ammosupply;
	};
	// call spawning mining veins
	diag_log ("HIVE: Spawning # of Veins: " + str(MaxMineVeins));
	for "_x" from 1 to MaxMineVeins do {
		[] spawn spawn_mineveins;
	};

	if(isnil "dayz_MapArea") then {
		dayz_MapArea = 10000;
	};
	if(isnil "HeliCrashArea") then {
		HeliCrashArea = dayz_MapArea / 2;
	};
	if(isnil "OldHeliCrash") then {
		OldHeliCrash = false;
	};
	
	[] ExecVM "\z\addons\dayz_server\WAI\init.sqf";

	// [_guaranteedLoot, _randomizedLoot, _frequency, _variance, _spawnChance, _spawnMarker, _spawnRadius, _spawnFire, _fadeFire]
	if(OldHeliCrash) then {
		_nul = [3, 4, (50 * 60), (15 * 60), 0.75, 'center', HeliCrashArea, true, false] spawn server_spawnCrashSite;
	};
	if (isDedicated) then {
		// Epoch Events
		_id = [] spawn server_spawnEvents;
		// server cleanup
		[] spawn {
			private ["_id"];
			sleep 200; //Sleep Lootcleanup, don't need directly cleanup on startup + fix some performance issues on serverstart
			waitUntil {!isNil "server_spawnCleanAnimals"};
			_id = [] execFSM "\z\addons\dayz_server\system\server_cleanup.fsm";
		};

		// spawn debug box
		_debugMarkerPosition = getMarkerPos "respawn_west";
		_debugMarkerPosition = [(_debugMarkerPosition select 0),(_debugMarkerPosition select 1),1];
		_vehicle_0 = createVehicle ["DebugBox_DZ", _debugMarkerPosition, [], 0, "CAN_COLLIDE"];
		_vehicle_0 setPos _debugMarkerPosition;
		_vehicle_0 setVariable ["ObjectID","1",true];

		// max number of spawn markers
		if(isnil "spawnMarkerCount") then {
			spawnMarkerCount = 10;
		};
		actualSpawnMarkerCount = 0;
		// count valid spawn marker positions
		for "_i" from 0 to spawnMarkerCount do {
			if (!([(getMarkerPos format["spawn%1", _i]), [0,0,0]] call BIS_fnc_areEqual)) then {
				actualSpawnMarkerCount = actualSpawnMarkerCount + 1;
			} else {
				// exit since we did not find any further markers
				_i = spawnMarkerCount + 99;
			};
			
		};
		diag_log format["Total Number of spawn locations %1", actualSpawnMarkerCount];
		
		endLoadingScreen;
	};

	allowConnection = true;	
	sm_done = true;
	publicVariable "sm_done";
};
