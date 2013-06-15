/**
 *	SJPlayerController
 *
 *	Creation date: 29/06/2011 22:40
 */
class SJPlayerController extends UTPlayerController
	dependson(SJPawn)
	config(Game);
	
function static float UnitsToMetres(float units)
{
	return units / 50.0;
}
function static float MetresToUnits(float units)
{
	return units * 50.0;
}

state PlayerWalking
{
ignores SeePlayer, HearNoise;


	event BeginState(Name PreviousStateName)
	{
		GotoState('CustomMovement');
	}
}

state CustomMovement
{
ignores SeePlayer, HearNoise, Bump;


	event BeginState(Name PreviousStateName)
	{
		GroundPitch = 0;
		Pawn.SetPhysics(PHYS_none); //PHYS_CUSTOM says: don't do anything natively for movement; this lets me handle it all
	}

	function PlayerMove( float DeltaTime )
	{
		local vector			X,Y,Z, NewAccel;
		local eDoubleClickDir	DoubleClickMove;
		local rotator			OldRotation;
		
		local SJPawn jPawn;
		local float maxSpeed, forwardSpeed, sideSpeed;
		
		jPawn = SJPawn(Pawn);

		if( Pawn == None )
		{
			GotoState('Dead');
		}
		else
		{
			GetAxes(Pawn.Rotation,X,Y,Z);
			  

			// Update acceleration.
			
			maxSpeed = MetresToUnits(jPawn.WALKSPEED);
			forwardSpeed = MetresToUnits(jPawn.WALKSPEED);
			sideSpeed = MetresToUnits(jPawn.WALKSPEED - 1);
			
			NewAccel = PlayerInput.aForward*forwardSpeed*X + PlayerInput.aStrafe*sideSpeed*Y;
			
			NewAccel.Z	= 0;
			
			if ( VSize(NewAccel) > maxSpeed )  
				NewAccel = NewAccel * ( maxSpeed / VSize(NewAccel) );


			DoubleClickMove = PlayerInput.CheckForDoubleClickMove( DeltaTime/WorldInfo.TimeDilation );
			// Update rotation.
			OldRotation = Rotation;
			UpdateRotation( DeltaTime );

			if( Role < ROLE_Authority ) // then save this move and replicate it
			{
				ReplicateMove(DeltaTime, NewAccel, DoubleClickMove, OldRotation - Rotation);
			}
			else
			{
				ProcessMove(DeltaTime, NewAccel, DoubleClickMove, OldRotation - Rotation);
			}
		}
	}

	function ProcessMove(float DeltaTime, vector NewAccel, eDoubleClickDir DoubleClickMove, rotator DeltaRot)
	{
		local bool isJetting, isJumping;
		local SJPawn jPawn;
		local Vector accel;
		
		jPawn = SJPawn(Pawn);
	
		if( jPawn == None )
		{
			return;
		}

		if (Role == ROLE_Authority)
		{
			// Update ViewPitch for remote clients
			jPawn.SetRemoteViewPitch( Rotation.Pitch );
		}
		
		// The magic
		
		isJetting = jPawn.bJetsOn && ( jPawn.energy > 0 );
		isJumping = jPawn.bSkiOn && ( jPawn.lastJumpableNormalTimestamp < jPawn.MAXJUMPTICKS )  ;
		
		
		// jump   
		if ( isJumping )
		{
			jPawn.velocity += jPawn.Jump( Normal(NewAccel));
		}
			
		jPawn.bCrawledToStop = (VSize(velocity) < MetresToUnits(jPawn.CRAWLTOSTOP ));
	  
		// jets and acceleration
		accel = jPawn.GForce;
		jPawn.energy += ( jPawn.JETENERGY_CHARGE * DeltaTime );
		if ( isJetting ) 
		{  
			accel += jPawn.Jet( Normal(NewAccel), DeltaTime );
			jPawn.energy -= ( jPawn.JETENERGY_DRAIN * DeltaTime );
		}  
		//jPawn.energy = FClamp(jPawn.energy, 0.0, jPawn.MAXENERGY);
		jPawn.energy = FClamp(jPawn.energy, jPawn.MAXENERGY, jPawn.MAXENERGY); //TEMPORARY: infinite energy
		
		//jPawn.acceleration = NewAccel;
		jPawn.velocity += (accel * DeltaTime);
		//jPawn.acceleration = accel;
		
		if (jPawn.bCollisionLastTick)
		{
			jPawn.velocity += jPawn.Friction( NewAccel, DeltaTime );
		}
	  
		// update jumpableNormal timestamp (milliseconds)
		jPawn.lastJumpableNormalTimestamp += (DeltaTime*1000);
		
		//and try to move
		jPawn.UpdatePosition(DeltaTime); //custom movement code
	}
}

/**
 * PlayerTick is only called if the PlayerController has a PlayerInput object.  Therefore, it will not be called on servers for non-locally controlled playercontrollers
 */
event PlayerTick( float DeltaTime )
{
	if ( !bShortConnectTimeOut )
	{
		bShortConnectTimeOut = true;
		ServerShortTimeout();
	}

	if ( Pawn != AcknowledgedPawn )
	{
		if ( Role < ROLE_Authority )
		{
			// make sure old pawn controller is right
			if ( (AcknowledgedPawn != None) && (AcknowledgedPawn.Controller == self) )
				AcknowledgedPawn.Controller = None;
		}
		AcknowledgePossession(Pawn);
	}

	PlayerInput.PlayerInput(DeltaTime);
	
	if ( bUpdatePosition )
	{
		ClientUpdatePosition();
	}
	PlayerMove(DeltaTime); //Overridden movement handling

	AdjustFOV(DeltaTime);
}

// This is where it gets hairy

/* Override: we want to handle jumping, not the UT code */
function CheckJumpOrDuck()
{
	return;
}

/* Input */
exec function StartJet()
{
	local SJPawn jPawn;
	jPawn = SJPawn(Pawn);
	if ( jPawn != None )
	{
		jPawn.StartJetting();
	}
}

exec function StopJet()
{
	local SJPawn jPawn;
	jPawn = SJPawn(Pawn);
	if ( jPawn != None )
	{
		jPawn.StopJetting();
	}
}

exec function StartSki()
{
	local SJPawn jPawn;
	jPawn = SJPawn(Pawn);
	if ( jPawn != None )
	{
		jPawn.StartSkiing();
	}
}

exec function StopSki()
{
	local SJPawn jPawn;
	jPawn = SJPawn(Pawn);
	if ( jPawn != None )
	{
		jPawn.StopSkiing();
	}
}

defaultproperties
{
}
