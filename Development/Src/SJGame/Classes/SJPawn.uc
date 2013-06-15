/**
 *	SJPawn
 *
 *	Creation date: 30/06/2011 17:00
 */
class SJPawn extends UTPawn;

//Gravity

var Vector GForce;
var Vector GUpNormal;
var Vector GDownNormal;


//Physics things

var int MAXJUMPTICKS;
var float TICKBASE;
var float ELASTICITY;
var float CRAWLTOSTOP;
var float MINSPEED;
var float FRICTIONDECAY;

//e

var float MMASS;
var float GROUNDFORCE;
var float GROUNDTRACTION;
var float WALKSPEED;
var float JUMPIMPULSE;
var float JUMPSURFACE_MINDOT;

var float MINDAMAGESPEED;
var float DAMAGESCALE;

var float JETFORCE;
var float JETSIDEFORCE;
var float JETFORWARD;
var float MAXENERGY;
var float JETENERGY_DRAIN;
var float JETENERGY_CHARGE;

var float BOX_WIDTH;
var float BOX_DEPTH;
var float BOX_HEIGHT;

var float energy;

var bool bCrawledToStop;
var bool bCollisionLastTick;
var Vector lastJumpableNormal;
var int lastJumpableNormalTimestamp;
var float currentFriction;

var bool bJetsOn;
var bool bSkiOn;


//Scale factor: 50 unreal units = 1 metre
function static float UnitsToMetres(float units)
{
	return units / 50.0;
}

function static float MetresToUnits(float units)
{
	return units * 50.0;
}

function Vector Jump( Vector moveDirection ) {
	local Vector			X,Y,Z;
	local float surfaceDirection;
	local float impulse;
	local Vector jump;
	local float orientation;
	GetAxes(Rotation,X,Y,Z);

    // need another ground contact before we can jump again
    lastJumpableNormalTimestamp = MAXJUMPTICKS;

    // jump up
    surfaceDirection = Floor dot GUpNormal ;
    impulse = MetresToUnits(JUMPIMPULSE / MMASS);
    jump = ( surfaceDirection * impulse ) * GUpNormal;

    // if we're moving away from the surface, jump away
    orientation = Floor dot moveDirection;
    if ( orientation > 0 ) 
	{
        jump += ( impulse * orientation ) * moveDirection;
	}

    return jump;
}

function Vector Jet( Vector moveDirection, float DeltaTime ) {
	local float forwardVelocity, tickJetForce;
	local float sidePower, orientation;
	local Vector sideForce, upForce;
	
    forwardVelocity = MetresToUnits(JETFORWARD);
    tickJetForce = MetresToUnits(JETFORCE / MMASS);

    if ( ( lastJumpableNormalTimestamp >= MAXJUMPTICKS ) && ( VSize(moveDirection) != 0 ) ) {
        orientation = velocity dot moveDirection;
        if ( orientation > forwardVelocity )
            sidePower = 0;
        else if ( orientation < 0 )
            sidePower = JETSIDEFORCE;
        else
            sidePower = ( 1 - ( orientation / forwardVelocity ) );

        sidePower = FMin( sidePower, JETSIDEFORCE );
        sideForce = ( sidePower * tickJetForce ) * moveDirection;
        upForce = ( ( 1 - sidePower ) * tickJetForce ) * GUpNormal;
        return ( upForce + sideForce );
    } else {
        // straight up, full jets
        return ( tickJetForce * GUpNormal ); 
    }
}

function Vector ProjectOntoPlane( Vector a, Vector normal ) {
    return a - ( (a dot normal ) * normal );
}

// Walking and friction damping
function Vector Friction( Vector moveSpeed, float tickLen)
{
    local Vector dampen;
	local float traction;
	local float force;
	
	dampen = ( moveSpeed - velocity );
	
	dampen = ProjectOntoPlane(dampen, GDownNormal );

    traction = fmin( currentFriction * GROUNDTRACTION, 1.0 );
	
	
    force = ( MetresToUnits( GROUNDFORCE / MMASS ) * traction * tickLen * 50); // m/s
	
    if ( VSize(dampen) > force )
        dampen *= ( force / VSize(dampen) );
    else
        bCrawledToStop = true;
		
    return ( dampen );
}


/* Here we'll update the player's position manually to avoid UDK's player physics */
function bool UpdatePosition(float DeltaTime)
{
	//Locals (so many variables)
	local float decayFriction;
	local float lastSurfDirection;
	local float timeLeft;
	local int maxBumps, bumps;
	
	local Vector maxDistance;
	local int iterations;
	local float sliceTime;
	local Vector originalPos, endPos;
	local Vector contactNormal, contactPos;
	
	local float duration;
	local float surfDirection;
	
	local float impactDot;
	
	local int impactIterations;
	local float fullMotionTime;
	local float fixupTime;
	local Vector bounce;
	
	local Vector noMovement;
	
	// Logic ...
	
	decayFriction = currentFriction * FRICTIONDECAY;
	lastSurfDirection = lastJumpableNormal dot GUpNormal;
	timeLeft = DeltaTime;
	maxBumps = 4;
	currentFriction = 0;
	bCollisionLastTick = false;
	
	for(bumps = 0; (bumps < maxBumps) && (timeLeft > 0); ++bumps)
	{
		//slice fixup values
		maxDistance = velocity * timeleft;
		iterations = FCeil(UnitsToMetres(VSize(maxDistance)));
		sliceTime = timeLeft / iterations;
		
        // attempt to move through the world
        originalPos = Location;

		Move(maxDistance); //attempt to move
		
		endPos = Location;
		
		duration = timeLeft * (VSize(Location - originalPos) / VSize(maxDistance));
		
        timeLeft -= duration;
		
		// did we move the entire distance safely?
		if(timeLeft < 0.001)
		{
			break;
		}
		
		//we didn't make it all the way, and have collided (or "collided" with something
		//do a non-zero-extent trace to find what we've hit
		//(doesn't seem to be any other way of getting a collision hit normal out of the engine; it should
		// be firing off hitwall, touch, or bump when we collide inside the Move(), but doesn't... bug?)
		Trace(contactPos, contactNormal, Location + maxDistance, Location, true, GetCollisionExtent());
		
        // bCollisionLastTick gets set even if we step up and don't have an actual collision
        bCollisionLastTick = true;
        surfDirection = contactNormal dot GUpNormal;
		
		//SJPlayerController(Controller).clientmessage("Surfing: " $ surfDirection);
		if ( surfDirection < JUMPSURFACE_MINDOT && false) {
            // code to handle potentially stepping up sheer surfaces
			SetLocation(originalPos);
			MoveSmooth(maxDistance - (endPos - originalPos));
			if (Location.z - endPos.z > 5)
			{
				setLocation(endPos);
			}
            else if ( abs(VSize(Location - endPos)) > 0.0001 )
                continue;
        }
		
        impactDot = (-velocity) dot contactNormal;
            
        // take damage if needed
        if ( UnitsToMetres(impactDot) > MINDAMAGESPEED )
            TakeDamage( ( UnitsToMetres(impactDot) - MINDAMAGESPEED ) * DAMAGESCALE, Controller, Location, noMovement, class'DmgType_Fell');

        // if we hit a jumpable surface, update the jumpable normal and reset the timestamp
        if ( surfDirection >= JUMPSURFACE_MINDOT ) {
            if ( ( lastJumpableNormalTimestamp > ( TICKBASE * 1000 ) ) ||
                 ( surfDirection < lastSurfDirection ) ) {
                lastSurfDirection = surfDirection;
                lastJumpableNormalTimestamp = 0;
                lastJumpableNormal = contactNormal;
            }
        }
        
        // do some voodoo for collision adjustments and timeslices
        impactIterations = FCeil( duration / sliceTime );
        fullMotionTime = sliceTime * ( impactIterations - 1 ) ;
        fixupTime = duration - fullMotionTime;
        SetLocation(originalPos + (velocity * fullMotionTime));

        // bounce
        bounce = ( contactNormal * ( impactDot + MetresToUnits(ELASTICITY ) ));
        velocity += bounce;

        // readjust position based on bounced velocity
        Move(velocity * fixupTime );

        // only update friction on upward facing surfaces
        if ( surfDirection > 0 ) {
            currentFriction = surfDirection;

            if ( bCrawledToStop && ( VSize(Velocity) < MetresToUnits(MINSPEED) ) ) 
			{
                velocity.x = 0; velocity.y = 0; velocity.z = 0;
                SetLocation(originalPos);
                break;
            }
        }
    }

    if ( bumps >= maxBumps ) {
        // sets the velocity to 0 here, this is where skibugs happen
    }
    
    if ( bCollisionLastTick ) 
        currentFriction = Fmin(1.0, FMax( currentFriction, decayFriction ));
		
    return ( bCollisionLastTick );
}

/* Functions in case I need the pawn to do *something* when these two things start... */
function StartJetting()
{
	bJetsOn = true;
}
function StopJetting()
{
	bJetsOn = false;
}
function StartSkiing()
{
	bSkiOn = true;
}
function StopSkiing()
{
	bSkiOn = false;
}

defaultproperties
{
	//1 UU == 2 CM
	//2 CM = 0.02 M
	//__M * (2 CM / 0.02 M) * (1 UU / 2 CM) = UU
	// __M * 50 = __UU

	GForce = ( X=0, Y=0, Z=-1000 ) 
	GUpNormal = (X=0, Y=0, Z=1)
	GDownNormal = (X=0, Y=0, Z=-1)
	
	MAXJUMPTICKS = 256
	TICKBASE = 0.032
	ELASTICITY = 0.001  
	CRAWLTOSTOP = 0.1  
	MINSPEED = 0.75  
	FRICTIONDECAY = 0.6  

	MASS = 450
	MMASS = 9
	GROUNDFORCE = 9 * 40
	GROUNDTRACTION = 3
	GroundSpeed= 11
	WALKSPEED = 11
	JUMPIMPULSE = 75
	JUMPSURFACE_MINDOT = 0.2

	MINDAMAGESPEED = 25
	DAMAGESCALE = 0.005

	JETFORCE = 236
	JETSIDEFORCE = 0.8
	JETFORWARD = 22
	MAXENERGY = 60
	energy = 60
	JETENERGY_DRAIN = 25
	JETENERGY_CHARGE = 8 + 3

	BOX_WIDTH = 0.5
	BOX_DEPTH = 0.5
	BOX_HEIGHT = 2.3
}
