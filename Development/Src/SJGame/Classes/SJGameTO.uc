/**
 *	SJGame
 *
 *	Creation date: 29/06/2011 22:42
 */
class SJGameTO extends AOCTeamObjective;

event PostLogin( PlayerController NewPlayer )
{
    super.PostLogin(NewPlayer);
    NewPlayer.ClientMessage("SJGame starting up...");
}

/**
  * Override GameType so that I start, not AOCGame
  */
static event class<GameInfo> SetGameType(string MapName, string Options, string Portal)
{
	return class'SJGame';
}


defaultproperties
{
	PlayerControllerClass=class'SJGame.SJPlayerController'
	ConsolePlayerControllerClass=class'SJGame.SJPlayerController'
	DefaultPawnClass=class'SJPawn'
}
