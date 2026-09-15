// Zeus Enhanced context menu: the same reins as the modules, one right-click away
class ZEN_context_menu_actions {
    class ADDON {
        displayName = CSTRING(Context_Main);
        condition = QUOTE(true);
        priority = 6;
        class Intent {
            displayName = CSTRING(Context_Intent);
            statement = QUOTE([ARR_3(_groups,_objects,_position)] call FUNC(setIntent));
            condition = QUOTE((_groups isNotEqualTo []) || (_objects isNotEqualTo []));
            icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\defend_ca.paa";
        };
        class Release {
            displayName = CSTRING(Context_Release);
            statement = QUOTE([_position] call FUNC(setRelease));
            icon = "\a3\ui_f\data\GUI\Cfg\CommunicationMenu\attack_ca.paa";
        };
        class FireMission {
            displayName = CSTRING(Context_FireMission);
            statement = QUOTE([_position] call FUNC(setFireMission));
            icon = "\a3\ui_f\data\IGUI\Cfg\simpleTasks\types\destroy_ca.paa";
        };
        class Director {
            displayName = CSTRING(Context_Director);
            statement = QUOTE([_position] call FUNC(setDirector));
            icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\intel_ca.paa";
        };
        class Pause {
            displayName = CSTRING(Context_Pause);
            statement = QUOTE([_args] call FUNC(setPause));
            condition = QUOTE([_args] call FUNC(showPause));
            icon = "\a3\3DEN\Data\CfgWaypoints\Hold_ca.paa";
            args = 1;
        };
        class Resume: Pause {
            displayName = CSTRING(Context_Resume);
            args = 0;
        };
        class Overlay {
            displayName = CSTRING(Context_Overlay);
            statement = QUOTE(call FUNC(overlay));
            icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\intel_ca.paa";
        };
    };
};
