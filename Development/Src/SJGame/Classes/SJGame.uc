/**
 *	SJGame
 *
 *	Creation date: 29/06/2011 22:42
 */
class SJGame extends UTGame;

event PostLogin( PlayerController NewPlayer )
{
    super.PostLogin(NewPlayer);
    NewPlayer.ClientMessage("SJGame starting up...");
}

/**
  * Allows overriding of which gameinfo class to use.
  * Called on the DefaultGameType from the ini, or the one specified on the command line (?game=xxx)
  */
static event class<GameInfo> SetGameType(string MapName, string Options, string Portal)
{
	local string ThisMapPrefix;
	local int i,pos;
	local class<GameInfo> NewGameType;
	local string GameOption;


	if (Left(MapName, 9) ~= "EnvyEntry" || Left(MapName, 14) ~= "UDKFrontEndMap" )
	{
		return class'UTEntryGame';
	}

	// allow commandline to override game type setting
	GameOption = ParseOption( Options, "Game");
	if ( GameOption != "" )
	{
		return Default.class;
	}

	// strip the UEDPIE_ from the filename, if it exists (meaning this is a Play in Editor game)
	if (Left(MapName, 6) ~= "UEDPIE")
	{
		MapName = Right(MapName, Len(MapName) - 6);
	}
	else if ( Left(MapName, 5) ~= "UEDPC" )
	{
		MapName = Right(MapName, Len(MapName) - 5);
	}
	else if (Left(MapName, 6) ~= "UEDPS3")
	{
		MapName = Right(MapName, Len(MapName) - 6);
	}
	else if (Left(MapName, 6) ~= "UED360")
	{
		MapName = Right(MapName, Len(MapName) - 6);
	}

	// replace self with appropriate gametype if no game specified
	pos = InStr(MapName,"-");
	ThisMapPrefix = left(MapName,pos);
	for (i = 0; i < default.MapPrefixes.length; i++)
	{
		if (default.MapPrefixes[i] ~= ThisMapPrefix)
		{
			return Default.class;
		}
	}

	// change game type
	for ( i=0; i<Default.DefaultMapPrefixes.Length; i++ )
	{
		if ( Default.DefaultMapPrefixes[i].Prefix ~= ThisMapPrefix )
		{
			NewGameType = class<GameInfo>(DynamicLoadObject(Default.DefaultMapPrefixes[i].GameType,class'Class'));
			if ( NewGameType != None )
			{
				return NewGameType;
			}
		}
	}
	for ( i=0; i<Default.CustomMapPrefixes.Length; i++ )
	{
		if ( Default.CustomMapPrefixes[i].Prefix ~= ThisMapPrefix )
		{
			NewGameType = class<GameInfo>(DynamicLoadObject(Default.CustomMapPrefixes[i].GameType,class'Class'));
			if ( NewGameType != None )
			{
				return NewGameType;
			}
		}
	}

    return class'SJGame';
}


defaultproperties
{
	PlayerControllerClass=class'SJGame.SJPlayerController'
	ConsolePlayerControllerClass=class'SJGame.SJPlayerController'
	DefaultPawnClass=class'SJPawn'
}
