/*=======================================================//
// rtd.QC - for Shaka CustomTF 2009                       //
// by Jordan Siegler / iKiltMyself / ]STALLION[           //
=========================================================//
  Roll the Dice - as seen in many Source games and MC mods
  
 Implements the "cmd rtd" client command. Clients can also
 simply use "rtd" in console (alias set in this source's 
 `tforthlp.qc` file). The player sees an animated dice 
 rolling in their centerprint area, and when it lands a 
 random status effect is applied to them.
=========================================================*/

#define RTD_COOLDOWN     30    // seconds between rolls (default if rtd_cool serverinfo unset)
#define RTD_ANIM_FRAMES  10    // number of dice "flips" before landing
#define RTD_ANIM_DELAY   0.2   // seconds between flips

// Number of distinct effects available. Update this if
// you add or remove cases in RTD_DoEffect below.
#define RTD_NUM_EFFECTS  25

// Entity mode tunables. Used when `localinfo rtd_entmode`
// is "on" - dice spawn around the map and force a roll on
// pickup.
//
// RTD_DIE_COUNT  - how many dice exist on the map at
//                  once. After a pickup, a new one
//                  spawns elsewhere after the cooldown
//                  (localinfo rtd_cool [int]) so the
//                  count stays constant.
// RTD_WATCH_TICK - how often the entity-mode watcher
//                  timer checks `localinfo rtd_entmode`.
//                  A few seconds is plenty - this isn't
//                  a hot path.
// RTD_DIE_MDL    - the .mdl file used for the dice.
//                  Custom 6-sided die model. Note: this
//                  model must NOT have the Rotate flag set
//                  in its .mdl header. The Rotate flag is
//                  a client-side baseline yaw rotation the
//                  engine adds automatically; it can't be
//                  disabled server-side and would fight
//                  with the bounce/settle code in
//                  RTD_Die_Think/RTD_Die_Settle. As long
//                  as the model doesn't have that flag,
//                  the server-driven spin handles
//                  everything.
#define RTD_DIE_MDL      "progs/red_6sd.mdl"
#define RTD_DIE_COUNT    2
#define RTD_WATCH_TICK   3

// Local state constants for entity-mode dice. Same
// shape as runes.qc's RUNESTATE_*
#define RTD_DIESTATE_READY    1
#define RTD_DIESTATE_WRONG    2
#define RTD_DIESTATE_RESPAWN  3

/*=========================================================
// LOCALINFO ACCESSORS
//
// Admin-tunable settings
// All can be set via `localinfo`
//
//   rtd          [on/off] - master toggle. Default on.
//   rtd_anim     [on/off] - dice animation toggle. Default on.
//   rtd_cool     [int]    - cooldown seconds. Default 30.
//   rtd_entmode  [on/off] - entity mode (future feature -
//                           scaffolded here, not yet wired
//                           into any behavior). Default off.
//=========================================================*/

float() RTD_Enabled =
{
    if (infokey(world, "rtd") == "off")
        return #FALSE;
    return #TRUE;
};

float() RTD_AnimEnabled =
{
    if (infokey(world, "rtd_anim") == "off")
        return #FALSE;
    return #TRUE;
};

float() RTD_Cooldown =
{
    local string st;
    local float v;

    st = infokey(world, "rtd_cool");
    if (st == "")
        return #RTD_COOLDOWN;

    v = stof(st);
    if (v <= 0)
        return #RTD_COOLDOWN;
    return v;
};

float() RTD_EntMode =
{
    if (infokey(world, "rtd_entmode") == "on")
        return #TRUE;
    return #FALSE;
};

// Forward declarations of functions from other files
// already in the CustomTF source code
void() ConcussionGrenadeTimer;
void() HallucinationTimer;
void() TranquiliserTimer;
void() AntiGravGrenadeTimer;         // sbitems.qc - per-player antigrav timer
void() TeamFortress_DetpackExplode;
void() PsionicGrenadeExplode;        // scout.qc - psionic effect in radius
void(float type) TeamFortress_SpyFeignDeath; // spy.qc - toggles feign on self
void() custom_lay;                   // custom.qc - "cmd lay", breaks own legs
void() ThrowC4Det;                   // sbitems.qc - tossable detpack throw
void() W_SetCurrentAmmo;             // weapons.qc - needed after un-feign
void() TeamFortress_SaveMe;          // actions.qc - the "saveme" command
void() lvl3_sentry_stand;            // sentry.qc - lvl 3 sentry idle animation
void() SUB_Null;                     // subs.qc - empty think
void(vector org, entity shooter) CreateCaltrop; // scout.qc - spawn one caltrop
void(entity bastard, float threshold) createBastard; // custom.qc - apply teamkill curse
float(float teamNo) TeamFortress_TeamGetColor; // tfort.qc - team color
string(float teamNo) TeamGetNiceColor;          // tfort.qc - nicecolors variant
float(entity targ, entity attacker) Teammate;   // tfort.qc - team check

// Forward declarations for new status effects
void() RTD_ChainLightningEnd;
void(entity p) TeamFortress_SetSpeed;
void(entity targ, entity inflictor, entity attacker, float damage,
     float T_flags, float T_AttackType) TF_T_Damage;
float() crandom;                     // weapons.qc - signed random

//=========================================================
// Dice face artwork. Each string is 5 lines tall and
// roughly square so it sits nicely in the centerprint.
// Placed a "Rolling..." caption above the face so the
// animation reads as intended.
//
// Swiped from this short by @computerknowledge4217 on
// Youtube: https://www.youtube.com/shorts/TDdTLwzvBn0

string(float face) RTD_DiceFace =
{
    if (face == 1)
        return " ----- \n|     |\n|  *  |\n|     |\n ----- \n";
    if (face == 2)
        return " ----- \n| *   |\n|     |\n|   * |\n ----- \n";
    if (face == 3)
        return " ----- \n| *   |\n|  *  |\n|   * |\n ----- \n";
    if (face == 4)
        return " ----- \n| * * |\n|     |\n| * * |\n ----- \n";
    if (face == 5)
        return " ----- \n| * * |\n|  *  |\n| * * |\n ----- \n";
    return     " ----- \n| * * |\n| * * |\n| * * |\n ----- \n";
};

//=========================================================
// EFFECTS
//=========================================================

// --- Effect helpers -------------------------------------

// Spawn a fresh concussion timer on the player. Modelled
// after the concussion-grenade code in scout.qc.
void(entity p) RTD_GiveConcussion =
{
    local entity te;

    stuffcmd(p, "v_idlescale 100\n");
    stuffcmd(p, "bf\n");
    p.tfstate = p.tfstate | #TFSTATE_CONCUSSIONED;

    te = spawn();
    te.classname = "timer";
    te.owner = p;
    te.team_no = p.team_no;
    te.health = 100;
    te.think = ConcussionGrenadeTimer;
    te.nextthink = time + #GR_CONCUSS_TIME;
};

// Spawn a hallucination timer on the player. Modelled
// after the gas-grenade code in spy.qc.
void(entity p) RTD_GiveHallucination =
{
    local entity te;

    p.tfstate = p.tfstate | #TFSTATE_HALLUCINATING;

    te = spawn();
    te.classname = "timer";
    te.owner = p;
    te.team_no = p.team_no;
    // HallucinationTimer ticks every 0.1s and decrements
    // health by GR_HALLU_DEC (2.5) each tick. To get ~10s
    // of hallucinations: 10 / 0.1 = 100 ticks * 2.5 = 250.
    te.health = 250;
    te.think = HallucinationTimer;
    te.nextthink = time + #GR_HALLU_TIME;
};

// Spawn an antigrav timer on the player only. Mirrors
// the per-player branch inside T_RadiusAntiGrav, without
// the radius scan that would catch nearby players too.
// I don't have a bounce-up effect here (radius antigrav
// throws targets based on distance from the explosion);
// instead I give the roller a small launch directly.
void(entity p) RTD_GiveAntiGrav =
{
    local entity te;

    // Light bounce + clear ground flag, so they feel the
    // gravity drop right away.
    p.velocity_z = p.velocity_z + 200;
    if (p.flags & #FL_ONGROUND)
        p.flags = p.flags - #FL_ONGROUND;

    p.gravity = 0.3 * random();
    stuffcmd(p, "bf\n");

    // Look for an existing antigrav timer on this player
    // to refresh, otherwise spawn a fresh one. Mirrors
    // the find-or-spawn pattern in T_RadiusAntiGrav.
    te = find(world, classname, "timer");
    while (te != world && (te.owner != p || te.think != AntiGravGrenadeTimer))
        te = find(te, classname, "timer");

    if (te != world)
    {
        te.health = 100;
        te.nextthink = time + #GR_CONCUSS_TIME;
    }
    else
    {
        te = spawn();
        te.classname = "timer";
        te.owner = p;
        te.team_no = p.team_no;
        te.health = 100;
        te.think = AntiGravGrenadeTimer;
        te.nextthink = time + #GR_CONCUSS_TIME;
    }
};

// Spawn a tranquiliser timer on the player. Modelled
// after the tranq-dart code in spy.qc.
void(entity p) RTD_GiveTranq =
{
    local entity te;

    p.tfstate = p.tfstate | #TFSTATE_TRANQUILISED;

    te = spawn();
    te.classname = "timer";
    te.owner = p;
    te.team_no = p.team_no;
    te.think = TranquiliserTimer;
    te.nextthink = time + #TRANQ_TIME;

    TeamFortress_SetSpeed(p);
};

// Fire a self-removing grenade-style explode function
// at the player's location". The four grenade explode
// functions in CustomTF (detpack, conc, antigrav, psion)
// all share the same shape: they read self for origin
// and self.owner for the attacker, and will then call
// BecomeExplosion() (which dremove's self) in the QW
// build. So this helper:
//   - spawns a stand-in ent at the player's origin
//   - sets .owner to the player (so kill attribution works)
//   - swaps self in for the call
//   - does NOT dremove the stand-in afterwards - the
//     explode function already removed it.
//
// The `mode` param picks which explode function runs:
//   0 = detpack, 1 = concussion, 2 = antigrav, 3 = psionic
//
// DO NOT fold this into a function-pointer style; the
// codebase's cpqccx is touchy about function pointers
// passed across files, and an if/else ladder is just as
// fast at runtime and easier to debug. Ask me how I know.

#define RTD_BOOM_DETPACK   0
#define RTD_BOOM_PSIONIC   1

void(entity p, float mode) RTD_BoomAtPlayer =
{
    local entity boom;
    local entity oself;

    boom = spawn();
    boom.classname = "rtd_boom";
    boom.owner = p;
    boom.movetype = #MOVETYPE_NONE;
    boom.solid = #SOLID_NOT;
    // PsionicGrenadeExplode checks self.netname to decide
    // between "mine" and "grenade" timing; empty string
    // (the default) is the grenade path, which is what we
    // want. Setting it explicitly here documents the
    // intent.
    boom.netname = "";
    setorigin(boom, p.origin);

    oself = self;
    self = boom;

    if (mode == #RTD_BOOM_DETPACK)
        TeamFortress_DetpackExplode();
    else
        PsionicGrenadeExplode();

    self = oself;

    // NOTE: do NOT dremove(boom) here. In the QUAKE_WORLD
    // build, each of these explode functions ends with
    // dremove(self) (directly, or via BecomeExplosion).
    // The previous version of this helper did dremove the
    // stand-in afterwards and it was a latent double-free
    // - it just happened not to crash visibly because the
    // engine often tolerates dremoving a stale edict
    // reference. I trust the explode function to clean
    // up.
};

//=========================================================
// SPY SLIDE - feign death but the player can still move.
//
// Simply toggle the spy feign-death state on the player
// and then fix up the movement constraints so they can
// move around while looking like a corpse. After 15s a
// follow-up timer un-feigns them. This was fun to force
// as a status effect, given it was actually a "cheat"
// back in the early QWTF days. This was the best stand-in
// I could think of to replace the "Spy Crab" status effect
// in TF2's RTD.
//
// The CustomTF authors patched out spy-sliding bugs by
// adding this to TeamFortress_SetSpeed (tfort.qc around
// line 1681):
//
//     if (p.is_feigning || ...)
//         p.tfstate |= TFSTATE_CANT_MOVE;
//
// That means anything that touches the player and calls
// SetSpeed (damage, picking up items, jumping, etc.) will
// re-assert CANT_MOVE on a feigning player. So clearing
// CANT_MOVE once is not enough; it WILL come back on
// the next SetSpeed call, and the player gets stuck.
//
// The fix: let the feign function do all the visual setup
// (low view_ofs, flat hitbox, death animation, hidden
// weapon), then CLEAR is_feigning just to solely maintain
// the visual markers via a fast tick. The player no
// longer counts as feigning for SetSpeed's check, so
// movement stays unlocked. The dead look stays because
// I keep re-asserting view_ofs and size each tick.
//
// Possible side effects of "not really feigning":
//   - other players see them as a corpse model but can
//     interact with them like a live player
//   - the player can shoot if they get a weapon back
//     (current_weapon was zeroed by the feign call; I
//     don't restore it during the slide for the visual)
//   - the spy-revealer / psionic checks won't find them
//     (since is_feigning is false) - acceptable for a
//     status effect.

void() RTD_SpySlideTick;
void() RTD_SpySlideEnd;

void(entity p) RTD_SpySlideBegin =
{
    local entity oself;
    local entity timer;
    local float saved_effects;
    local float saved_flags;

    // TeamFortress_SpyFeignDeath has several gate checks
    // that block the feign in states that are valid for
    // a roll-the-dice effect (Can't feign while glowing,
    // can't feign in the air)
    //
    // Temporarily clearing the glow flags and forcing
    // FL_ONGROUND for the feign call, then let the
    // normal engine state machine restore everything.
    //
    // Save and restore the originals so anything else
    // that reads .effects / .flags between now and the
    // next physics tick sees a consistent state.
    saved_effects = p.effects;
    saved_flags = p.flags;
    p.effects = p.effects - (p.effects & (#EF_DIMLIGHT | #EF_BRIGHTLIGHT));
    p.flags = p.flags | #FL_ONGROUND;

    // Run the feign function for visual setup. If the
    // function refuses (e.g. user is grapple hooking)
    // the slide just doesn't take and the cooldown still
    // applies.
    oself = self;
    self = p;
    TeamFortress_SpyFeignDeath(1);
    self = oself;

    // Restore the original effects bitfield. PlayerPostThink
    // will re-validate it on its next tick - if the glow
    // sources are gone (e.g., player dropped the flag mid-
    // animation, somehow), it'll clear cleanly; if still
    // active, it'll re-light.
    p.effects = saved_effects;
    // Don't restore flags - let the engine recompute
    // FL_ONGROUND naturally next physics tick. If we
    // weren't really on ground, gravity will sort it.

    if (!p.is_feigning)
        return;

    // Now disconnect from is_feigning so SetSpeed stops
    // re-asserting CANT_MOVE.
    p.is_feigning = #FALSE;

    // Clear the movement lock and put them back on
    // walking movetype.
    p.tfstate = p.tfstate - (p.tfstate & #TFSTATE_CANT_MOVE);
    p.movetype = #MOVETYPE_WALK;

    // Restore client input speeds. The feign call's
    // SetSpeed already stuffcmd'd these to 0; I put
    // them back to a higher value (1000) so cl_*speed
    // input actually moves the player.
    stuffcmd(p, "cl_backspeed 1000\n");
    stuffcmd(p, "cl_forwardspeed 1000\n");
    stuffcmd(p, "cl_sidespeed 1000\n");

    // Recompute maxspeed from the player's class.
    TeamFortress_SetSpeed(p);

    // Maintenance tick keeps the visual state pinned and
    // re-clears CANT_MOVE in case some other code path
    // sneaks it back on. 0.1s = 10Hz; plenty fast for the
    // visual; light on stuffcmds.
    timer = spawn();
    timer.classname = "rtd_slide";
    timer.owner = p;
    timer.ltime = time + 15;
    timer.think = RTD_SpySlideTick;
    timer.nextthink = time + 0.1;
};

void() RTD_SpySlideTick =
{
    local entity p;

    p = self.owner;

    if (p == world || !p.is_connected || p.health <= 0)
    {
        dremove(self);
        return;
    }

    if (time >= self.ltime)
    {
        // Hand off to the end function for cleanup.
        self.think = RTD_SpySlideEnd;
        self.nextthink = time;
        return;
    }

    // Maintain the dead look. setsize and view_ofs are
    // idempotent so they can be re-applied each tick. I'm
    // NOT calling setsize every tick because it triggers
    // a collision recheck; only re-apply if it drifted.
    if (p.view_ofs != '0 0 4')
        p.view_ofs = '0 0 4';

    // If anything (damage, item touch, etc.) re-asserted
    // CANT_MOVE, knock it back off.
    if (p.tfstate & #TFSTATE_CANT_MOVE)
    {
        p.tfstate = p.tfstate - (p.tfstate & #TFSTATE_CANT_MOVE);
        TeamFortress_SetSpeed(p);
    }

    self.nextthink = time + 0.1;
};

void() RTD_SpySlideEnd =
{
    local entity p;
    local entity oself;

    p = self.owner;

    if (p == world || !p.is_connected || p.health <= 0)
    {
        dremove(self);
        return;
    }

    // Manual un-feign. Restores the visual state (hitbox,
    // view_ofs, model, weapon viewmodel) without going
    // through TeamFortress_SpyFeignDeath because
    // is_feigning is already FALSE.
    setsize(p, #VEC_HULL_MIN, #VEC_HULL_MAX);
    p.view_ofs = '0 0 22';
    p.modelindex = modelindex_player;
    p.current_weapon = p.weapon;

    oself = self;
    self = p;
    W_SetCurrentAmmo();
    self = oself;

    TeamFortress_SetSpeed(p);

    dremove(self);
};

//=========================================================
// LEG BREAKER - run the "lay" command on the player, then
// undo it after 5s.

void() RTD_LegBreakerEnd;

void(entity p) RTD_LegBreakerBegin =
{
    local entity oself;
    local entity timer;

    // custom_lay sets leg_damage=8, clamps hp to 50 and
    // armor to 10, calls TeamFortress_SetSpeed (which
    // reads leg_damage), and sets suicide_time to time+60.
    // Here I'm undoing all of that in 5s.
    oself = self;
    self = p;
    custom_lay();
    self = oself;

    timer = spawn();
    timer.classname = "rtd_legbreak";
    timer.owner = p;
    timer.think = RTD_LegBreakerEnd;
    timer.nextthink = time + 5;
};

void() RTD_LegBreakerEnd =
{
    local entity p;

    p = self.owner;

    if (p == world || !p.is_connected || p.health <= 0)
    {
        dremove(self);
        return;
    }

    // Undo the leg damage and reset speed.
    p.leg_damage = 0;
    // Clear the auto-suicide that custom_lay armed.
    p.suicide_time = 0;
    TeamFortress_SetSpeed(p);

    sprint(p, #PRINT_HIGH, "Your legs feel better.\n");

    dremove(self);
};

//=========================================================
// GEARHEAD - spawn a fully-upgraded (level 3) sentry gun
// head that floats above the player, follows them, and
// shoots enemies. Cannot be destroyed while player lives.
//
// I spawn a real "building_sentrygun" entity with the
// same field setup an engineer would build, then force
// it to level 3 by setting .weapon = 3 and pointing its
// think at lvl3_sentry_stand. The sentry's own AI takes
// over from there (Sentry_Rotate, Sentry_FindTarget,
// Sentry_Fire, etc.).
//
// A separate tracker entity (.classname "rtd_gearhead")
// is the parent I use to reposition the sentry above
// the player each tick and to handle the 7s expiry.
//
// NIT_TURRET is set on the sentry so it gets 360-degree
// targeting (the "see in all directions" code path in
// Sentry_FindTarget); without it, the sentry would only
// fire at enemies it happens to be facing.

void() RTD_GearheadTrack;

void(entity p) RTD_GearheadBegin =
{
    local entity gun, tracker;

    // ---- The sentry itself ----
    gun = spawn();
    gun.classname = "building_sentrygun";
    gun.flags = gun.flags | #FL_MACHINE;
    gun.health = #BUILD_HEALTH_SENTRYGUN;
    gun.max_health = gun.health;
    gun.tf_items = #NIT_KEVLAR | #NIT_TURRET; // turret = 360 vision
    gun.armorclass = #AT_SAVESHOT;
    gun.weapon = 3;                            // LEVEL 3 (fully upgraded)
    gun.th_die = SUB_Null;                     // never dies
    gun.th_pain = SUB_Null;
    gun.mdl = "progs/trrgn2.mdl";
    setmodel(gun, gun.mdl);
    setsize(gun, '-16 -16 0', '16 16 48');
    gun.real_owner = p;                        // owner for team/Pharse checks
    gun.owner = p;                             // also used by some helpers
    gun.colormap = p.colormap;
    gun.team_no = p.team_no;
    if (p.team_no >= 1)
        gun.skin = p.team_no - 1;

    // Indestructible: takedamage off, no touch handler
    // (Sentry_Touch can call Sentry_Die if the sentry
    // ends up in a bad spot - I don't want that). Make
    // it intangible too so players don't collide with it.
    gun.takedamage = #DAMAGE_NO;
    gun.solid = #SOLID_NOT;
    gun.touch = SUB_Null;
    gun.movetype = #MOVETYPE_NONE;             // move it manually
    gun.velocity = '0 0 0';
    gun.flags = gun.flags - (gun.flags & #FL_ONGROUND);

    // Rotation state - same as engineer.qc
    // waitmin/waitmax bracket the idle scan arc; the
    // sentry sweeps between them when no target is in
    // sight. Gave it a full 360 sweep.
    gun.yaw_speed = 10;
    gun.heat = 0;
    gun.angles_x = 0;
    gun.angles_y = ceil(p.angles_y);
    gun.angles_z = 0;
    gun.waitmin = 0;
    gun.waitmax = 360;

    // Ammo - plenty so it doesn't run dry in 7s.
    gun.ammo_shells = 999;
    gun.maxammo_shells = 999;
    gun.ammo_rockets = 999;
    gun.maxammo_rockets = 999;

    // Reset state fields the sentry logic uses.
    gun.all_active = 0;
    gun.is_malfunctioning = 0;
    gun.attack_finished = time;
    gun.has_holo = 0;
    gun.has_fieldgen = time;
    gun.frags = 0;
    gun.money = 0;
    gun.demon_blood = 0;
    gun.enemy = world;

    // Position above the player's head and start the
    // sentry's native logic think chain.
    setorigin(gun, p.origin + '0 0 36');
    gun.think = lvl3_sentry_stand;
    gun.nextthink = time + 0.1;

    sound(p, #CHAN_ITEM, "weapons/turrset.wav", 1, #ATTN_NORM);

    // ---- The tracker ----
    // .enemy = the parent sentry
    // .ltime = expiry
    tracker = spawn();
    tracker.classname = "rtd_gearhead";
    tracker.owner = p;
    tracker.enemy = gun;
    tracker.ltime = time + 7;
    tracker.think = RTD_GearheadTrack;
    tracker.nextthink = time + 0.05;
};

void() RTD_GearheadTrack =
{
    local entity p, gun;

    p = self.owner;
    gun = self.enemy;

    // Player vanished or sentry already removed - tear
    // everything down.
    if (p == world || !p.is_connected || p.health <= 0 ||
        gun == world || gun.classname != "building_sentrygun" ||
        time >= self.ltime)
    {
        if (gun != world && gun.classname == "building_sentrygun")
            dremove(gun);
        dremove(self);
        return;
    }

    // Park the gun just above the player's head. 36 above
    // the player's origin (the player's feet) puts the
    // gun's base at chest height and the gun-head model
    // floats above their head.
    setorigin(gun, p.origin + '0 0 36');

    self.nextthink = time + 0.05;
};

//=========================================================
// NEED A MEDIC - spam the "saveme" sound on the player
// with no flood protection, so the sound interrupts
// itself constantly. Using CHAN_VOICE means each new
// sound truncates the previous one.

void() RTD_MedicSpamThink;

void(entity p) RTD_NeedAMedicBegin =
{
    local entity timer;

    timer = spawn();
    timer.classname = "rtd_medic";
    timer.owner = p;
    timer.ltime = time + 10;
    timer.think = RTD_MedicSpamThink;
    timer.nextthink = time + 0.05;
};

void() RTD_MedicSpamThink =
{
    local entity p;
    local entity oself;
    local float r;

    p = self.owner;

    if (p == world || !p.is_connected || p.health <= 0 || time >= self.ltime)
    {
        dremove(self);
        return;
    }

    // Fire the full saveme command so nearby medics see
    // the lightning bolt pointing at this player. Zero
    // out the throttle field first so the call's internal
    // gate doesn't short-circuit.
    p.last_saveme_sound = 0;
    oself = self;
    self = p;
    TeamFortress_SaveMe();
    self = oself;

    // ALSO play the saveme sound on CHAN_VOICE so it
    // interrupts itself - the saveme function plays on
    // CHAN_WEAPON which doesn't reliably overlap. Picking
    // randomly between the two clips makes the spam less
    // monotone.
    r = random();
    if (r < 0.5)
        sound(p, #CHAN_VOICE, "speech/saveme1.wav", 1, #ATTN_NORM);
    else
        sound(p, #CHAN_VOICE, "speech/saveme2.wav", 1, #ATTN_NORM);

    // Random short interval so the interruption pattern
    // sounds chaotic instead of metronomic. 0.05-0.30s.
    self.nextthink = time + 0.05 + random() * 0.25;
};

//=========================================================
// DET VOMIT - throw a tossable C4 detpack every 0.5s for
// 5 seconds (10 detpacks total). ThrowC4Det reads self
// (a thrower stand-in) and self.owner (the player); it
// also decrements .ammo_c4det, so it's topped up each tick
// to keep it from going negative, and restore the
// original count when the effect ends.

void() RTD_DetVomitThink;

void(entity p) RTD_DetVomitBegin =
{
    local entity timer;

    timer = spawn();
    timer.classname = "rtd_detvomit";
    timer.owner = p;
    // .cnt = remaining throws
    timer.cnt = 10;
    // .health = ammo to restore at the end (save it
    // here so the player ends up exactly where they
    // started ammo-wise, even though they "fired" 10
    // detpacks).
    timer.health = p.ammo_c4det;
    timer.think = RTD_DetVomitThink;
    // Fire the first detpack on the next think rather
    // than instantly - keeps the visual rhythm consistent.
    timer.nextthink = time + 0.1;
};

void() RTD_DetVomitThink =
{
    local entity p;
    local entity thrower;
    local entity oself;

    p = self.owner;

    if (p == world || !p.is_connected || p.health <= 0 || self.cnt <= 0)
    {
        // Restore the player's c4 det ammo to where they
        // started, if they're still alive to care.
        if (p != world && p.is_connected && p.health > 0)
            p.ammo_c4det = self.health;
        dremove(self);
        return;
    }

    // Make sure ammo_c4det stays positive across the
    // throw (ThrowC4Det decrements it).
    p.ammo_c4det = 99;

    // Build a thrower stand-in. ThrowC4Det reads
    // self.owner; everything else gets set up inside.
    thrower = spawn();
    thrower.classname = "rtd_detthrower";
    thrower.owner = p;

    oself = self;
    self = thrower;
    ThrowC4Det();
    self = oself;

    // ThrowC4Det doesn't dremove the thrower (it spawns a
    // separate newmis for the actual detpack), so clean
    // up the stand-in here.
    if (thrower != world)
        dremove(thrower);

    self.cnt = self.cnt - 1;
    self.nextthink = time + 0.5;
};

//=========================================================
// SPILLING SPIKES - throw 2 caltrop grenades per second
// for 5 seconds. Same structure as DET VOMIT but with
// CreateCaltrop instead of ThrowC4Det. CreateCaltrop
// takes args directly (no self-swap needed), so this is
// a much simpler loop than DET VOMIT.

void() RTD_SpikesThink;

void(entity p) RTD_SpikesBegin =
{
    local entity timer;

    timer = spawn();
    timer.classname = "rtd_spikes";
    timer.owner = p;
    timer.cnt = 10;             // 10 throws @ 0.5s = 5s
    timer.think = RTD_SpikesThink;
    timer.nextthink = time + 0.1;
};

void() RTD_SpikesThink =
{
    local entity p;

    p = self.owner;

    if (p == world || !p.is_connected || p.health <= 0 || self.cnt <= 0)
    {
        dremove(self);
        return;
    }

    // CreateCaltrop spawns ONE caltrop. Each call randomises
    // its scatter, so calling it twice in quick succession
    // produces a small spray. Slight upward offset so the
    // caltrops emerge from the player's feet, not below.
    CreateCaltrop(p.origin + '0 0 16', p);
    CreateCaltrop(p.origin + '0 0 16', p);

    self.cnt = self.cnt - 1;
    self.nextthink = time + 0.5;
};

//=========================================================
// THE CURSED - forces the teamkiller curse on the player
// for 7 seconds.
//
// Why no createBastard / stuffcmd: some newer QW clients
// filter stuffcmd payloads via cl_remote_capabilities and
// block the cl_yawspeed/+left/+right/name commands the
// original TK curse uses. So I drive the spin server-side
// by rotating .angles_y + setting .fixangle = #TRUE,
// which the engine networks via the player-state
// protocol (same path teleporters use). This bypasses
// the capability filter entirely. It's not as smooth of a
// spin, and is actually almost vomit-inducing.... cool!
//
// The "can't shoot / can't throw grenades / can't die /
// can't suicide" behaviors come from existing CustomTF
// guards on .penance_time and .suicide_time:
//   - W_Attack returns early if penance_time > time
//     (weapons.qc:4096)
//   - ImpulseCommands returns early if penance_time > time
//     (weapons.qc:5318)
//   - ClientObituary heals to 50 if penance_time > time
//     (combat.qc:219)
//   - ClientKill returns early if suicide_time > time
//     (client.qc:1922)
// I am pushing both fields well into the future for the
// 7-second window and clearing them at the end.
//
// Tracker fields:
//   .ltime    = expiry deadline
//   .frags    = spin direction (+1 or -1, flipped every
//               2s to mimic BastardTimer's random reverse)
//   .heat     = next direction-flip time
//   .health   = saved penance_time (to restore at end)
//   .weapon   = saved suicide_time (to restore at end)

void() RTD_CursedThink;

void(entity p) RTD_CursedBegin =
{
    local entity timer;

    timer = spawn();
    timer.classname = "rtd_cursed";
    timer.owner = p;
    timer.ltime = time + 7;
    timer.frags = 1;                    // initial spin direction
    timer.heat = time + 2;              // first direction-flip
    // Save the player's existing penance/suicide_time so
    // I don't clobber state from an unrelated source
    // (e.g., a real teamkill curse the player was already
    // serving). On restore, I put them back exactly as
    // they were at the start of the effect.
    timer.health = p.penance_time;
    timer.weapon = p.suicide_time;
    timer.think = RTD_CursedThink;
    timer.nextthink = time + 0.05;

    // Block shooting, grenades, impulse-driven actions,
    // and "dying for real" (target becomes a no-op heal-
    // to-50 in ClientObituary instead of an actual death).
    p.penance_time = time + 9999;
    // Block the `kill` suicide command.
    p.suicide_time = time + 9999;
};

void() RTD_CursedThink =
{
    local entity p;

    p = self.owner;

    if (p == world || !p.is_connected)
    {
        dremove(self);
        return;
    }

    // End of effect: restore the saved field values and
    // clear the timer. I do not gate on p.health <= 0
    // here because the curse explicitly prevents dying;
    // health should never drop below 1 while the effect
    // is active (ClientObituary clamps to 50 each time).
    if (time >= self.ltime)
    {
        p.penance_time = self.health;
        p.suicide_time = self.weapon;
        dremove(self);
        return;
    }

    // Periodically flip spin direction. Mimics
    // BastardTimer's random direction reverse every ~2s
    // and prevents the spin from being a steady rotation
    // the player could compensate for.
    if (time >= self.heat)
    {
        self.frags = 0 - self.frags;
        self.heat = time + 2;
    }

    // Apply spin: rotate angles_y by a chunk each tick
    // and force the client to honor the new angle.
    // 25 degrees per 0.05s = 500 deg/sec, matching the
    // "cl_yawspeed 500" the original curse used.
    p.angles_y = p.angles_y + (self.frags * 25);
    if (p.angles_y >= 360)
        p.angles_y = p.angles_y - 360;
    if (p.angles_y < 0)
        p.angles_y = p.angles_y + 360;
    p.fixangle = #TRUE;

    self.nextthink = time + 0.05;
};

//=========================================================
// INFINITE JUMP - lets the player jump in mid-air for 10
// seconds.
//
// The engine gates jumps on FL_ONGROUND being set
// (client.qc, near line 3065). Rather than patching 
// PlayerJump, poll the player's .button2 (jump) field on a
// fast tick and apply a jump impulse on the rising edge.
//
// Per-tick state on the tracker:
//   .ltime    = expiry deadline
//   .cnt      = previous tick's button2 value (rising-
//               edge detection so player jumps once per
//               press, not every tick the button is held)

void() RTD_InfJumpThink;

void(entity p) RTD_InfJumpBegin =
{
    local entity timer;

    timer = spawn();
    timer.classname = "rtd_infjump";
    timer.owner = p;
    timer.ltime = time + 10;
    timer.cnt = 0;
    timer.think = RTD_InfJumpThink;
    timer.nextthink = time + 0.05;
};

void() RTD_InfJumpThink =
{
    local entity p;

    p = self.owner;

    if (p == world || !p.is_connected || p.health <= 0 || time >= self.ltime)
    {
        dremove(self);
        return;
    }

    // Rising edge of button2: 0 last tick, 1 this tick.
    // Only jump if airborne (engine handles ground jumps
    // normally) and not feigning / in a state where
    // jumping wouldn't make sense.
    if (p.button2 && !self.cnt)
    {
        if (!(p.flags & #FL_ONGROUND) && !p.is_feigning &&
            !(p.flags & #FL_FINALIZED) && p.waterlevel < 2)
        {
            // Match PlayerJump's impulse exactly. Note:
            // PlayerJump zeroes negative velocity_z first
            // (the "Gizmo's jump bug fix"), so do the
            // same here.
            if (p.velocity_z < 0)
                p.velocity_z = 0;
            p.velocity_z = p.velocity_z + 270;

            sound(p, #CHAN_BODY, "player/plyrjmp8.wav", 1, #ATTN_NORM);
        }
    }

    self.cnt = p.button2;
    self.nextthink = time + 0.05;
};

//=========================================================
// LEG HEAD - player is forced upward continuously, and
// pressing jump applies a one-shot downward "upside-down
// jump" impulse. They can only jump-down again after
// their head has touched the ceiling.
//
// Future plan: flip the player model upside down, as well
// as the player viewport... if possible.
//
// Tracker state:
//   .ltime    = expiry deadline
//   .cnt      = previous tick's button2 (rising-edge)
//   .frags    = "armed" flag - 1 means the player is at
//               ceiling and can fire a jump-down impulse;
//               0 means they've already used it and need
//               to re-touch ceiling first.

void() RTD_LegHeadThink;

void(entity p) RTD_LegHeadBegin =
{
    local entity timer;

    // Lift the player off the ground
    p.velocity_z = 500;
    p.gravity = 0;
    if (p.flags & #FL_ONGROUND)
        p.flags = p.flags - (p.flags & #FL_ONGROUND);

    timer = spawn();
    timer.classname = "rtd_leghead";
    timer.owner = p;
    timer.ltime = time + 10;
    timer.cnt = 0;                          // last tick's button2
    timer.frags = 1;                        // start "armed" so the first jump-down works even if the ceiling isn't sensed immediately
    timer.think = RTD_LegHeadThink;
    timer.nextthink = time + 0.05;
};

void() RTD_LegHeadThink =
{
    local entity p;
    local float ceiling_dist;
    local vector head_pos;
    local float at_ceiling;

    p = self.owner;

    if (p == world || !p.is_connected || p.health <= 0 || time >= self.ltime)
    {
        // Restore normal gravity and upright model.
        if (p != world && p.is_connected)
        {
            p.gravity = 1;
            p.angles_z = 0;
            p.fixangle = #TRUE;
        }
        dremove(self);
        return;
    }

    // Anti-gravity.
    p.gravity = 0;
    if (p.flags & #FL_ONGROUND)
        p.flags = p.flags - (p.flags & #FL_ONGROUND);

    // Render the player model upside-down. angles_z is
    // the roll component; setting it to 180 rotates the
    // model 180 degrees around its forward axis. The
    // player.qc movement code resets angles_z to 0 each
    // physics step, so re-assert every tick.
    // 
    // TODO: flip player's own first-person viewport
    // (if possible to do server-side)
    p.angles_z = 180;

    // Trace UPWARD from head level (not feet level) and
    // measure clearance above the player's head rather
    // than from their feet. 
    // Quake's player bbox top is roughly +32 from origin.
    // I'm using +24 to be slightly conservative (close 
    // enough to head, not high enough to trace thru it).
    head_pos = p.origin;
    head_pos_z = head_pos_z + 24;
    traceline(head_pos, head_pos + '0 0 4096', #TRUE, p);
    ceiling_dist = vlen(trace_endpos - head_pos);

    at_ceiling = #FALSE;
    if (ceiling_dist <= 8)
        at_ceiling = #TRUE;

    // Touching ceiling re-arms the "upside down jump" ability.
    if (at_ceiling)
        self.frags = 1;

    // Rising edge of button2: fire one downward impulse
    // IF currently armed. After firing, disarm until the
    // player's head touches the ceiling again. This stops
    // chain-jumps from accelerating downward indefinitely.
    if (p.button2 && !self.cnt)
    {
        if (self.frags)
        {
            p.velocity_z = -500;
            self.frags = 0;
        }
    }
    self.cnt = p.button2;

    // Ascent / hover behavior.
    if (at_ceiling)
    {
        // Pinned at ceiling - hover. Don't push up
        // further (would grind), but don't kill downward
        // velocity from a recent jump-impulse either.
        if (p.velocity_z > 50)
            p.velocity_z = 50;
    }
    else
    {
        // Below ceiling - accelerate upward. +80 per
        // tick capped at +500 produces a quick rise that
        // feels like falling upward.
        if (p.velocity_z < 500)
            p.velocity_z = p.velocity_z + 80;
        if (p.velocity_z > 500)
            p.velocity_z = 500;
    }

    self.nextthink = time + 0.05;
};

//=========================================================
// QUICKSTER - leg speed forced to 630 (the equivalent of
// Cheetah leg speed 430 + Runner sprint bonus +200) AND
// AURA_HASTE applied (0.75x attack delay = ~33% faster
// fire rate). Lasts for 10 seconds.
//
// Deliberately NOT using RUNE_SPEED as that interferes with
// Neo Mode by inadvertently causing the user to drop the
// Speed Rune upon death during testing. As RTD is being
// developed alongside continued Neo Mode development,
// I can't use any of the runes for status effects.
//
// Saved state on the tracker:
//   .ltime    = expiry deadline
//   .cnt      = saved .aura value

void() RTD_QuicksterThink;

void(entity p) RTD_QuicksterBegin =
{
    local entity timer;

    timer = spawn();
    timer.classname = "rtd_quickster";
    timer.owner = p;
    timer.ltime = time + 10;
    timer.cnt = p.aura;                 // save original aura
    timer.think = RTD_QuicksterThink;
    timer.nextthink = time + 0.05;

    // Apply HASTE aura for the faster firing.
    p.aura = #AURA_HASTE;

    // Set initial speed. The tick will keep stomping it.
    TeamFortress_SetSpeed(p);
    p.maxspeed = 630;
};

void() RTD_QuicksterThink =
{
    local entity p;

    p = self.owner;

    if (p == world || !p.is_connected || p.health <= 0 || time >= self.ltime)
    {
        if (p != world && p.is_connected)
        {
            // Restore aura. If the player had AURA_HASTE before rtd... this is a
            // no-op; otherwise put back whatever they had (0, AURA_RESIS, AURA_POWER, w/e)
            p.aura = self.cnt;
            TeamFortress_SetSpeed(p);
        }
        dremove(self);
        return;
    }

    // Re-assert HASTE and stomp maxspeed each tick in
    // case something else (item pickup, damage, etc.)
    // recomputed them. Doesn't need a high tick rate -
    // 0.1s is plenty for visual smoothness.
    p.aura = #AURA_HASTE;
    TeamFortress_SetSpeed(p);
    p.maxspeed = 630;

    self.nextthink = time + 0.1;
};

//=========================================================
// RANDOM WEAPON - replaces the player's current weapon
// with a randomly chosen weapon from the custom menu
// for 10 seconds. After the timer expires the player's
// original weapon and ammo state are restored.
//
// To avoid massive complexity around per-weapon ammo
// types, I've curated a small list of some weapons
// that fire from the simple ammo pools (shells, nails,
// cells, rockets) and top up the matching ammo to a
// generous amount for the duration. On restore, reset
// the weapons_carried bitfield and ammo pools to what
// they were when the effect started.

void() RTD_RandWeapEnd;

// Weapon options for Random Weapon. Each entry pairs a
// WEAP_* bit (added to weapons_carried + made
// current_weapon) with the ammo field to top up. Using
// a function style switch rather than a parallel array
// because QC doesn't have nice array literals.
void(entity p, float pick) RTD_RandWeap_Equip =
{
    if (pick == 0)
    {
        p.weapons_carried = p.weapons_carried | #WEAP_ROCKET_LAUNCHER;
        p.current_weapon = #WEAP_ROCKET_LAUNCHER;
        p.ammo_rockets = 50;
    }
    else if (pick == 1)
    {
        p.weapons_carried = p.weapons_carried | #WEAP_LIGHTNING;
        p.current_weapon = #WEAP_LIGHTNING;
        p.ammo_cells = 200;
    }
    else if (pick == 2)
    {
        p.weapons_carried = p.weapons_carried | #WEAP_RAILGUN;
        p.current_weapon = #WEAP_RAILGUN;
        p.ammo_cells = 200;
    }
    else if (pick == 3)
    {
        p.weapons_carried = p.weapons_carried | #WEAP_ASSAULT_CANNON;
        p.current_weapon = #WEAP_ASSAULT_CANNON;
        p.ammo_shells = 200;
    }
    else if (pick == 4)
    {
        p.weapons_carried = p.weapons_carried | #WEAP_DAEDALUS;
        p.current_weapon = #WEAP_DAEDALUS;
        p.ammo_cells = 200;
    }
    else if (pick == 5)
    {
        p.weapons_carried = p.weapons_carried | #WEAP_LASERCANNON;
        p.current_weapon = #WEAP_LASERCANNON;
        p.ammo_cells = 200;
    }
    else if (pick == 6)
    {
        p.weapons_carried = p.weapons_carried | #WEAP_FLAMETHROWER;
        p.current_weapon = #WEAP_FLAMETHROWER;
        p.ammo_cells = 200;
    }
    else  // pick == 7
    {
        p.weapons_carried = p.weapons_carried | #WEAP_GRENADE_LAUNCHER;
        p.current_weapon = #WEAP_GRENADE_LAUNCHER;
        p.ammo_rockets = 50;
    }
};

void(entity p) RTD_RandWeapBegin =
{
    local entity timer;
    local float pick;
    local entity oself;

    timer = spawn();
    timer.classname = "rtd_randweap";
    timer.owner = p;
    // Save state on the timer entity. .cnt holds the weapons_carried bitfield
    // The other fields use their matching names directly
    timer.cnt = p.weapons_carried;
    timer.weapon = p.current_weapon;
    timer.ammo_shells = p.ammo_shells;
    timer.ammo_nails = p.ammo_nails;
    timer.ammo_rockets = p.ammo_rockets;
    timer.ammo_cells = p.ammo_cells;
    timer.think = RTD_RandWeapEnd;
    timer.nextthink = time + 10;

    pick = floor(random() * 8);
    if (pick >= 8) pick = 7;

    RTD_RandWeap_Equip(p, pick);

    // Push the new weapon viewmodel
    oself = self;
    self = p;
    W_SetCurrentAmmo();
    self = oself;
};

void() RTD_RandWeapEnd =
{
    local entity p;
    local entity oself;

    p = self.owner;

    if (p == world || !p.is_connected)
    {
        dremove(self);
        return;
    }

    if (p.health > 0)
    {
        // Restore saved state
        p.weapons_carried = self.cnt;
        p.current_weapon = self.weapon;
        p.ammo_shells = self.ammo_shells;
        p.ammo_nails = self.ammo_nails;
        p.ammo_rockets = self.ammo_rockets;
        p.ammo_cells = self.ammo_cells;

        // Clear any sticky firing state from the temp
        // weapon. 
        // Ex: Assault Cannon tracks .fire_held_down and
        // then sets TFSTATE_CANT_MOVE while spinning up; 
        // weapons.qc (near line 5933) only releases that
        // state when the player is still holding AC AND
        // releases fire. After the swap of weapon away,
        // that release condition never matches, and the
        // player gets "stuck-firing" in their original
        // weapon until they die. Clear everything here
        // defensively.
        p.fire_held_down = #FALSE;
        p.tfstate = p.tfstate - (p.tfstate & #TFSTATE_CANT_MOVE);
        p.attack_finished = time;
        p.reload_shotgun = 0;
        p.reload_super_shotgun = 0;
        p.reload_grenade_launcher = 0;
        p.reload_rocket_launcher = 0;
        p.reload_daedalus = 0;
        p.reload_light_assault = 0;
        p.reload_laser_cannon = 0;
        TeamFortress_SetSpeed(p);

        oself = self;
        self = p;
        W_SetCurrentAmmo();
        self = oself;
    }

    dremove(self);
};

//=========================================================
// INSTAGIB - any player this player damages drops dead
// instantly, regardless of weapon. Implemented as a 9999x
// damage multiplier in GetDamageOutFactor (cpstuff.qc),
// gated by .rtd_instagib > time.
//
// All the gameplay work happens in the patched
// GetDamageOutFactor; here I'm just flipping on the field
// for the duration & add a tiny cleanup timer that clears
// the visual glow at the end (the .rtd_instagib field
// becomes "stale" on its own once time passes the
// deadline, but the EF_DIMLIGHT halo needs to be cleared
// explicitly).

void() RTD_InstagibEnd;

void(entity p) RTD_InstagibBegin =
{
    local entity timer;

    p.rtd_instagib = time + 7;
    p.effects = p.effects | #EF_DIMLIGHT;
    sound(p, #CHAN_ITEM, "items/protect.wav", 1, #ATTN_NORM);

    timer = spawn();
    timer.classname = "rtd_instagib";
    timer.owner = p;
    timer.think = RTD_InstagibEnd;
    timer.nextthink = time + 7;
};

void() RTD_InstagibEnd =
{
    local entity p;

    p = self.owner;

    if (p == world || !p.is_connected)
    {
        dremove(self);
        return;
    }

    p.rtd_instagib = 0;
    p.effects = p.effects - (p.effects & #EF_DIMLIGHT);
    dremove(self);
};

//=========================================================
// CHAIN LIGHTNING [ALPHA] - when player damages another
// player, nearby players get zapped with a lightning beam
// stemmed from the original target to each nearby player.
//
// Triggered from a hook inside TF_T_Damage (combat.qc).
// When the hook fires, it calls RTD_ChainLightning_Strike
// with (attacker, targ), then findradius from targ and
// damage each nearby player that isn't attacker or a
// teammate.
//
// Strike damage is intentionally small (10 hp) - the
// effect is about disruption/style, not damage stacking.

void(entity attacker, entity origin_targ, entity victim) RTD_ChainLightning_FireBolt =
{
    // Lightning beam from origin_targ to victim. Modeled
    // after the Crusader's aura-bolt code in crusader.qc
    // Broadcast to MSG_ALL so spectators see it too
    WriteByte (#MSG_ALL, #SVC_TEMPENTITY);
    WriteByte (#MSG_ALL, #TE_LIGHTNING2);
    WriteEntity (#MSG_ALL, origin_targ);
    WriteCoord (#MSG_ALL, origin_targ.origin_x);
    WriteCoord (#MSG_ALL, origin_targ.origin_y);
    WriteCoord (#MSG_ALL, origin_targ.origin_z);
    WriteCoord (#MSG_ALL, victim.origin_x);
    WriteCoord (#MSG_ALL, victim.origin_y);
    WriteCoord (#MSG_ALL, victim.origin_z);

    sound(victim, #CHAN_AUTO, "weapons/lhit.wav", 0.5, #ATTN_NORM);
};

// Re-entrancy guard for chain lightning. 
// The Strike helper calls TF_T_Damage, which has a hook
// back to Strike (combat.qc patch). Without this guard,
// a chain bolt's damage event triggers a 2nd Strike from
// the new target, which damages another player, which
// triggers another Strike, etc. until QC's locals stack
// overflows and the server crashes. Setting this to a
// nonzero value while inside Strike makes the nested
// calls early-return. QC is single-threaded so a global
// float should suffice as a lock.
float rtd_chain_in_flight;

void(entity attacker, entity origin_targ) RTD_ChainLightning_Strike =
{
    local entity head;
    local float dist;

    // If already inside a chain Strike higher up the
    // stack, this is a recursive call from one of the
    // chained TF_T_Damage events. Don't chain again.
    if (rtd_chain_in_flight)
        return;

    // Defensive: never chain from an already-dead target.
    if (origin_targ == world || origin_targ.health <= 0)
        return;

    // Lock for the duration of this Strike, including the
    // TF_T_Damage calls below. Unlock before returning so
    // subsequent (non-recursive) damage events from the
    // same attacker still get their chain.
    rtd_chain_in_flight = 1;

    head = findradius(origin_targ.origin, 256);
    while (head)
    {
        if (head.classname == "player" &&
            head != attacker &&
            head != origin_targ &&
            head.health > 0 &&
            !Teammate(head, attacker))
        {
            dist = vlen(head.origin - origin_targ.origin);
            if (dist <= 256)
            {
                RTD_ChainLightning_FireBolt(attacker, origin_targ, head);
                // Small damage to the chained target. Use
                // standard TF_T_Damage so armor and
                // resists apply normally. Pass attacker
                // as the killer for kill credit on a chain
                // KO.
                TF_T_Damage(head, attacker, attacker, 10, #TF_TD_NOTTEAM | #TF_TD_NOKNOCK, 0);
            }
        }
        head = head.chain;
    }

    rtd_chain_in_flight = 0;
};

void(entity p) RTD_ChainLightningBegin =
{
    local entity timer;

    p.rtd_chainlightning = time + 7;
    p.effects = p.effects | #EF_BLUE; // blue glow

    timer = spawn();
    timer.classname = "rtd_chainlight";
    timer.owner = p;
    timer.think = RTD_ChainLightningEnd;
    timer.nextthink = time + 7;
};

void() RTD_ChainLightningEnd =
{
    local entity p;

    p = self.owner;

    if (p == world || !p.is_connected)
    {
        dremove(self);
        return;
    }

    p.rtd_chainlightning = 0;
    p.effects = p.effects - (p.effects & #EF_BLUE);
    dremove(self);
};

//=========================================================
// FROG - the player is locked to a standstill, and any
// movement input forces them into a hop instead of walking.
// On landing, they're frozen for 0.25 seconds before they
// can hop again.
//
// Since I don't have a direct way to read movement keys
// server-side (that I can tell anyway), I decided to try
// detecting "the player is trying to move" by seeing
// nonzero horizontal velocity AFTER the engine applies
// their input. If they pressed WASD, the engine gives
// them velocity_x/velocity_y; frog's tick (which fires
// after engine input processing) sees that and converts
// it into a hop.
//
// Tracker state:
//   .ltime    = expiry deadline
//   .cnt      = previous tick's FL_ONGROUND value, for
//               landing detection
//   .heat     = landing-freeze expiry time

void() RTD_FrogThink;

void(entity p) RTD_FrogBegin =
{
    local entity timer;

    timer = spawn();
    timer.classname = "rtd_frog";
    timer.owner = p;
    timer.ltime = time + 5;
    timer.cnt = #TRUE;          // assume on ground at start
    timer.heat = 0;
    timer.think = RTD_FrogThink;
    timer.nextthink = time + 0.05;
};

void() RTD_FrogThink =
{
    local entity p;
    local float on_ground;
    local float xy_speed;
    local vector hop_dir;

    p = self.owner;

    if (p == world || !p.is_connected || p.health <= 0 || time >= self.ltime)
    {
        dremove(self);
        return;
    }

    on_ground = #FALSE;
    if (p.flags & #FL_ONGROUND)
        on_ground = #TRUE;

    // Detect air-to-ground transition: start landing freeze.
    if (on_ground && !self.cnt)
        self.heat = time + 0.25;

    self.cnt = on_ground;

    if (on_ground)
    {
        if (time < self.heat)
        {
            // In landing freeze: lock them to a standstill.
            p.velocity_x = 0;
            p.velocity_y = 0;
            if (p.velocity_z > 0)
                p.velocity_z = 0;
        }
        else
        {
            // Free to hop. Did they press a movement key?
            // The engine sets velocity_x/y to nonzero if so;
            // sample the magnitudes. Using a flat
            // x*x + y*y comparison (no sqrt needed) -
            // the threshold is squared too.
            xy_speed = p.velocity_x * p.velocity_x + p.velocity_y * p.velocity_y;

            if (xy_speed > 25) // 5*5 = 25
            {
                // Convert ground-walk velocity into a hop.
                // Preserve the player's direction but cap
                // the horizontal speed to a sensible hop
                // distance. 150 gives a hop a couple feet
                // ahead per jump.
                hop_dir_x = p.velocity_x;
                hop_dir_y = p.velocity_y;
                hop_dir_z = 0;
                hop_dir = normalize(hop_dir);

                p.velocity_x = hop_dir_x * 150;
                p.velocity_y = hop_dir_y * 150;
                p.velocity_z = 270;

                // Clear FL_ONGROUND so the engine treats
                // them as airborne immediately.
                p.flags = p.flags - (p.flags & #FL_ONGROUND);
                self.cnt = 0;       // record airborne for next tick

                sound(p, #CHAN_BODY, "player/plyrjmp8.wav", 1, #ATTN_NORM);
            }
            else
            {
                // On ground, no input - enforce standstill.
                p.velocity_x = 0;
                p.velocity_y = 0;
            }
        }
    }
    // If airborne, let physics do its thing. The hop arc
    // plays out naturally under gravity.

    self.nextthink = time + 0.05;
};

//=========================================================
// SLIPPERY - the player has very low friction for 7s,
// so they slide around like they're on ice.
//
// The engine applies friction inside SV_Friction on each
// physics frame, reducing the player's horizontal
// velocity by a percentage. I don't have direct access
// to disable that, so I'm countering it by reasserting 
// the player's previous velocity (slight decay) each
// tick. Effectively, the engine slows them down, but I'm
// putting most of the speed back.
//
// Tracker state:
//   .ltime    = expiry deadline
//   .movedir  = last tick's horizontal velocity (xy)


void() RTD_SlipperyThink;

void(entity p) RTD_SlipperyBegin =
{
    local entity timer;

    timer = spawn();
    timer.classname = "rtd_slippery";
    timer.owner = p;
    timer.ltime = time + 7;
    timer.movedir = '0 0 0';
    timer.think = RTD_SlipperyThink;
    timer.nextthink = time + 0.05;
};

void() RTD_SlipperyThink =
{
    local entity p;
    local float cur_speed, prev_speed;
    local vector prev_vel;

    p = self.owner;

    if (p == world || !p.is_connected || p.health <= 0 || time >= self.ltime)
    {
        dremove(self);
        return;
    }

    // Only apply sliding while on the ground.
    if (p.flags & #FL_ONGROUND)
    {
        prev_vel = self.movedir;
        // Decay previous velocity 3% per tick. Over 1s
        // (20 ticks) that's ~46% retained, so a sliding
        // player gradually comes to rest if they stop
        // inputting movement entirely.
        prev_vel = prev_vel * 0.97;

        // Compare magnitudes (squared, cheaper).
        cur_speed = p.velocity_x * p.velocity_x +
                    p.velocity_y * p.velocity_y;
        prev_speed = prev_vel_x * prev_vel_x +
                     prev_vel_y * prev_vel_y;

        // If the player let off the keys, engine friction
        // dropped current below decayed-previous; restore
        // the slide. If they're actively pushing forward,
        // current dominates and gets let through.
        if (prev_speed > cur_speed)
        {
            p.velocity_x = prev_vel_x;
            p.velocity_y = prev_vel_y;
        }
    }

    // Remember this tick's velocity for next tick's decay
    // comparison. Always update, even airborne - so when
    // they land they have momentum to slide with.
    self.movedir_x = p.velocity_x;
    self.movedir_y = p.velocity_y;
    self.movedir_z = 0;

    self.nextthink = time + 0.05;
};

// --- The main effect dispatch ---------------------------
//
// RTD_DoEffect runs the branch identified by `pick`.
// RTD_ApplyEffect rolls a uniform random pick and calls
// it. The split lets the admin "cmd admin rtd N" path
// force a specific effect by calling RTD_DoEffect
// directly, sharing the same broadcast and effect code
// with the normal random roll.

// RTD_EffectDuration returns the duration (in seconds)
// of each effect's "active period" - how long after the
// roll the player is still under its influence. Used by
// entity-mode pickup to set .rtd_cooldown so the player
// can't grab another die until their current effect ends.
// Instant effects (full heal, fire in the hole, etc.)
// return 2 - a brief lockout so the dice can't all be
// vacuumed up in one frame, but short enough to not get
// in the way.
float(float pick) RTD_EffectDuration =
{
    if (pick == 0)  return 2;     // Full heal - instant
    if (pick == 1)  return 20;    // Dizzy spell (concussion)
    if (pick == 2)  return 10;    // Hallucinations
    if (pick == 3)  return 5;     // Tranquilised
    if (pick == 4)  return 2;     // FIRE IN THE HOLE - instant
    if (pick == 5)  return 2;     // Red armor - persistent, no lockout
    if (pick == 6)  return 2;     // Up up and away - instant
    if (pick == 7)  return 2;     // Antigravity - very short
    if (pick == 8)  return 5;     // Frog
    if (pick == 9)  return 2;     // Mindmelt - instant radius
    if (pick == 10) return 15;    // Spy Slide
    if (pick == 11) return 5;     // Leg Breaker
    if (pick == 12) return 7;     // Gearhead
    if (pick == 13) return 10;    // Need a Medic
    if (pick == 14) return 5;     // Det Vomit
    if (pick == 15) return 5;     // Spilling Spikes
    if (pick == 16) return 7;     // The Cursed
    if (pick == 17) return 10;    // Infinite Jump
    if (pick == 18) return 10;    // Leg Head
    if (pick == 19) return 10;    // Quickster
    if (pick == 20) return 10;    // Random Weapon
    if (pick == 21) return 7;     // Chain Lightning
    if (pick == 22) return 7;     // Instagib
    if (pick == 23) return 7;     // Slippery
    return 2;                      // pick == 24 Chip damage / fall-through
};

void(entity p, float pick) RTD_DoEffect;

void(entity p) RTD_ApplyEffect =
{
    local float pick;

    pick = floor(random() * #RTD_NUM_EFFECTS);
    if (pick >= #RTD_NUM_EFFECTS)
        pick = #RTD_NUM_EFFECTS - 1;
    if (pick < 0)
        pick = 0;

    RTD_DoEffect(p, pick);
};

// Admin entry point: force a specific effect on a player
// without rolling dice. Skips the animation and the
// cooldown. The target's cooldown is NOT updated (so
// they can still roll their next regular dice freely).
// Used by "cmd admin rtd N [player]".
void(entity p, float pick) RTD_ForceEffect =
{
    if (p == world || !p.is_connected || p.classname != "player" || p.health <= 0)
        return;
    if (pick < 0 || pick >= #RTD_NUM_EFFECTS)
        return;
    RTD_DoEffect(p, pick);
};

void(entity p, float pick) RTD_DoEffect =
{
    // CONVENTION: each branch
    //   1) centerprints "You rolled: X!" to the roller, so
    //      they get the dice result clearly
    //   2) bprint's a third-person broadcast to everyone
    //      (PRINT_MEDIUM = top-left kill-feed area)
    //   3) calls the effect helper
    //
    // The bprint uses p.netname as the leading token,
    // matching the kill-feed convention. Multi-arg bprint
    // is the standard pattern in this codebase (see e.g.
    // obits.qc).

    if (pick == 0)
    {
        // Full heal + small armor top-up
        p.health = p.max_health;
        if (p.armorvalue < 100)
            p.armorvalue = 100;
        centerprint(p, "You rolled:\n\nFull heal!\n");
        bprint(#PRINT_MEDIUM, p.netname, " feels completely refreshed.\n");
        return;
    }
    if (pick == 1)
    {
        // Dizzy spell - concussion 
        RTD_GiveConcussion(p);
        centerprint(p, "You rolled:\n\nDizzy spell!\n");
        bprint(#PRINT_MEDIUM, p.netname, " gets a mild concussion.\n");
        return;
    }
    if (pick == 2)
    {
        // Hallucination - gas grenade effects
        RTD_GiveHallucination(p);
        centerprint(p, "You rolled:\n\nHallucinations!\n");
        bprint(#PRINT_MEDIUM, p.netname, " is starting to see things.\n");
        return;
    }
    if (pick == 3)
    {
        // Tranquilised
        RTD_GiveTranq(p);
        centerprint(p, "You rolled:\n\nTranquilised!\n");
        bprint(#PRINT_MEDIUM, p.netname, "'s legs feel heavy.\n");
        return;
    }
    if (pick == 4)
    {
        // Detpack goes off under their feet
        centerprint(p, "You rolled:\n\nFIRE IN THE HOLE!\n");
        bprint(#PRINT_MEDIUM, p.netname, " hears a click. That can't be good.\n");
        RTD_BoomAtPlayer(p, #RTD_BOOM_DETPACK);
        return;
    }
    if (pick == 5)
    {
        // Free max armor
        p.armorvalue = 200;
        p.armortype = 0.8;
        p.items = p.items - (p.items & (#IT_ARMOR1 | #IT_ARMOR2 | #IT_ARMOR3));
        p.items = p.items | #IT_ARMOR3;
        centerprint(p, "You rolled:\n\nRed armor!\n");
        bprint(#PRINT_MEDIUM, p.netname, " has been granted red armor.\n");
        return;
    }
    if (pick == 6)
    {
        // Launched into the air
        p.velocity_z = p.velocity_z + 1200;
        if (p.flags & #FL_ONGROUND)
            p.flags = p.flags - #FL_ONGROUND;
        centerprint(p, "You rolled:\n\nUp, up and away!\n");
        bprint(#PRINT_MEDIUM, p.netname, " goes WHOOOOOSH!\n");
        return;
    }
    if (pick == 7)
    {
        // Antigravity
        RTD_GiveAntiGrav(p);
        centerprint(p, "You rolled:\n\nANTIGRAVITY!\n");
        bprint(#PRINT_MEDIUM, p.netname, " defies gravity!\n");
        return;
    }
    if (pick == 8)
    {
        // Frog movement
        centerprint(p, "You rolled:\n\nFROG!\n");
        bprint(#PRINT_MEDIUM, p.netname, " starts playing Frogger!\n");
        RTD_FrogBegin(p);
        return;
    }
    if (pick == 9)
    {
        // Psionic grenade hit
        centerprint(p, "You rolled:\n\nMINDMELT!\n");
        bprint(#PRINT_MEDIUM, p.netname, "'s thoughts seize up.\n");
        RTD_BoomAtPlayer(p, #RTD_BOOM_PSIONIC);
        return;
    }
    if (pick == 10)
    {
        // Spy slide - feign death and move
        centerprint(p, "You rolled:\n\nSPY SLIDE!\n");
        bprint(#PRINT_MEDIUM, p.netname, " starts spy sliding!\n");
        RTD_SpySlideBegin(p);
        return;
    }
    if (pick == 11)
    {
        // Leg breaker - force player to run `lay` command
        centerprint(p, "You rolled:\n\nLEG BREAKER!\n");
        //bprint(#PRINT_MEDIUM, p.netname, " breaks both legs in spectacular fashion!\n"); - unneeded; running 'lay' generates its own bprint
        RTD_LegBreakerBegin(p);
        return;
    }
    if (pick == 12)
    {
        // Gearhead - level 3 sentry follows the player overhead
        centerprint(p, "You rolled:\n\nGEARHEAD!\n");
        bprint(#PRINT_MEDIUM, p.netname, " sprouts a sentry. Don't ask.\n");
        RTD_GearheadBegin(p);
        return;
    }
    if (pick == 13)
    {
        // Need a medic - saveme spam for 10 seconds
        centerprint(p, "You rolled:\n\nNEED A MEDIC!\n");
        bprint(#PRINT_MEDIUM, p.netname, " desperately needs a medic!\n");
        RTD_NeedAMedicBegin(p);
        return;
    }
    if (pick == 14)
    {
        // Det vomit - spew tossable detpacks for 5s
        centerprint(p, "You rolled:\n\nDET VOMIT!\n");
        bprint(#PRINT_MEDIUM, p.netname, " starts vomiting detpacks. Run!\n");
        RTD_DetVomitBegin(p);
        return;
    }
    if (pick == 15)
    {
        // Spilling Spikes - caltrop spray for 5s
        centerprint(p, "You rolled:\n\nSPILLING SPIKES!\n");
        bprint(#PRINT_MEDIUM, p.netname, " is spilling caltrops everywhere!\n");
        RTD_SpikesBegin(p);
        return;
    }
    if (pick == 16)
    {
        // The Cursed - teamkiller curse
        centerprint(p, "You rolled:\n\nTHE CURSED!\n");
        bprint(#PRINT_MEDIUM, p.netname, "'s head won't stop spinning!\n");
        RTD_CursedBegin(p);
        return;
    }
    if (pick == 17)
    {
        // Infinite Jump - infinite mid-air jump for 10s
        centerprint(p, "You rolled:\n\nINFINITE JUMP!\n");
        bprint(#PRINT_MEDIUM, p.netname, " can jump on air!\n");
        RTD_InfJumpBegin(p);
        return;
    }
    if (pick == 18)
    {
        // Leg Head - stuck to ceiling for 10s
        centerprint(p, "You rolled:\n\nLEG HEAD!\n");
        bprint(#PRINT_MEDIUM, p.netname, " gets stuck on the ceiling!\n");
        RTD_LegHeadBegin(p);
        return;
    }
    if (pick == 19)
    {
        // Quickster - 2x speed + faster firing for 10s
        centerprint(p, "You rolled:\n\nQUICKSTER!\n");
        bprint(#PRINT_MEDIUM, p.netname, " is suddenly very, very fast!\n");
        RTD_QuicksterBegin(p);
        return;
    }
    if (pick == 20)
    {
        // Random Weapon - swap to a random gun for 10s
        centerprint(p, "You rolled:\n\nRANDOM WEAPON!\n");
        bprint(#PRINT_MEDIUM, p.netname, " grabs an unfamiliar weapon.\n");
        RTD_RandWeapBegin(p);
        return;
    }
    if (pick == 21)
    {
        // Chain Lightning - every time the player damages another player, nearby enemies get zapped too
        centerprint(p, "You rolled:\n\nCHAIN LIGHTNING!\n");
        bprint(#PRINT_MEDIUM, p.netname, " is crackling with electricity!\n");
        RTD_ChainLightningBegin(p);
        return;
    }
    if (pick == 22)
    {
        // Instagib - any player they shoot explodes instantly, regardless of weapon
        centerprint(p, "You rolled:\n\nINSTAGIB!\n");
        bprint(#PRINT_MEDIUM, p.netname, " is now playing INSTAGIB!\n");
        RTD_InstagibBegin(p);
        return;
    }
    if (pick == 23)
    {
        // Slippery - low friction for 7s.
        centerprint(p, "You rolled:\n\nSLIPPERY!\n");
        bprint(#PRINT_MEDIUM, p.netname, " just stepped on a banana peel!\n");
        RTD_SlipperyBegin(p);
        return;
    }

    // pick == 24 - chip damage, no knockback
    centerprint(p, "You rolled:\n\nOuch!\n");
    bprint(#PRINT_MEDIUM, p.netname, " stubs a toe. Ouch.\n");
    TF_T_Damage(p, p, p, 25, #TF_TD_IGNOREARMOUR | #TF_TD_NOKNOCK, 0);
};

//=========================================================
// ANIMATION
//
// The animation is driven by a self-thinking entity. Each
// tick it picks a new dice face, centerprints it, and
// either schedules itself again or finishes the roll.
//
// .owner   - the rolling player
// .cnt     - number of frames remaining
// .health  - just used as a non-zero "is rolling" marker

void() RTD_AnimThink;

void() RTD_Finish =
{
    local entity p;
    local entity oself;

    p = self.owner;

    // Defensive: if the player disconnected, gibbed, or
    // changed class mid-roll, bail out silently.
    if (p == world || !p.is_connected || p.classname != "player" || p.health <= 0)
    {
        dremove(self);
        return;
    }

    // Apply with `self` set to the player, so the effect
    // helpers can use either the explicit parameter or
    // self.
    oself = self;
    self = p;
    RTD_ApplyEffect(p);
    self = oself;

    // Record cooldown only after a successful roll lands.
    // Read from serverinfo each time so admin changes
    // mid-game take effect immediately.
    p.rtd_cooldown = time + RTD_Cooldown();

    dremove(self);
};

void() RTD_AnimThink =
{
    local entity p;
    local float face;
    local string faceStr;

    p = self.owner;

    // If the player went away, abort.
    if (p == world || !p.is_connected || p.classname != "player" || p.health <= 0)
    {
        dremove(self);
        return;
    }

    self.cnt = self.cnt - 1;

    if (self.cnt <= 0)
    {
        // Show a final face for the dramatic pause and then resolve
        face = floor(random() * 6) + 1;
        if (face > 6) face = 6;
        faceStr = RTD_DiceFace(face);
        centerprint(p, "Rolling the dice...\n\n", faceStr);
        self.think = RTD_Finish;
        self.nextthink = time + #RTD_ANIM_DELAY * 2;
        return;
    }

    face = floor(random() * 6) + 1;
    if (face > 6) face = 6;
    faceStr = RTD_DiceFace(face);
    centerprint(p, "Rolling the dice...\n\n", faceStr);

    self.nextthink = time + #RTD_ANIM_DELAY;
};

//=========================================================
// ENTITY MODE
//
// With `localinfo rtd_entmode on`, dice spawn at random
// reachable locations around the map. Players pick them
// up to roll, instead of running the `rtd` command
// (which is blocked while entity mode is active).
//
// Architecture mirrors runes.qc's spawn-place-respawn
// pattern:
//   - RTD_GetDieSpot scans random world coordinates for
//     a reachable empty point
//   - RTD_Die_Spawn creates one die entity at world
//     origin, configures touch/think, and returns it.
//   - RTD_Die_Place finds a spot via RTD_GetDieSpot,
//     places the die there, and droptofloor's it.
//   - RTD_Die_Think handles the periodic hop and tumble
//     animation, as well as the ent rotation animation.
//   - RTD_Die_Touch fires when a player touches a die.
//     Validates pickup, broadcasts, calls the effect,
//     removes the die, schedules a replacement.
//   - RTD_Die_RespawnThink fires after the cooldown to
//     spawn a fresh die at a new random location.
//
// A separate "watcher" entity polls localinfo rtd_entmode
// every RTD_WATCH_TICK seconds and starts/stops the dice
// system on toggle change. The watcher is spawned once at
// map start by RTD_Init (called from worldspawn). State
// transitions (off->on, on->off) drive RTD_EntMode_Start
// and RTD_EntMode_Stop.

void() RTD_Die_Think;
void() RTD_Die_Settle;
void() RTD_Die_Touch;
void() RTD_Die_RespawnThink;
void() RTD_Die_Place;
void() RTD_Die_Invalidate;
void() RTD_Die_RetryThink;

// Returns TRUE if the given vector is a reachable empty
// or water spot. Same content checks as runes.qc's
// CheckRuneSpot - rejects solid, sky, slime, and lava.
float(vector spot) RTD_CheckDieSpot =
{
    local float content;

    content = pointcontents(spot);
    if (content != #CONTENT_EMPTY && content != #CONTENT_WATER)
        return #FALSE;

    // Check the 8 corners of the bbox we'll use for the
    // die so it doesn't spawn in a spot that clips a wall.
    content = pointcontents(spot + '-16 -16 -24');
    if (content != #CONTENT_EMPTY && content != #CONTENT_WATER) return #FALSE;
    content = pointcontents(spot + '16 16 32');
    if (content != #CONTENT_EMPTY && content != #CONTENT_WATER) return #FALSE;
    content = pointcontents(spot + '-16 16 32');
    if (content != #CONTENT_EMPTY && content != #CONTENT_WATER) return #FALSE;
    content = pointcontents(spot + '16 -16 32');
    if (content != #CONTENT_EMPTY && content != #CONTENT_WATER) return #FALSE;
    content = pointcontents(spot + '16 16 -24');
    if (content != #CONTENT_EMPTY && content != #CONTENT_WATER) return #FALSE;
    content = pointcontents(spot + '16 -16 -24');
    if (content != #CONTENT_EMPTY && content != #CONTENT_WATER) return #FALSE;
    content = pointcontents(spot + '-16 16 -24');
    if (content != #CONTENT_EMPTY && content != #CONTENT_WATER) return #FALSE;
    content = pointcontents(spot + '-16 -16 32');
    if (content != #CONTENT_EMPTY && content != #CONTENT_WATER) return #FALSE;

    return #TRUE;
};

// Returns a valid random spot in the world bounds, or
// '4096 4096 4096' (a sentinel impossible value) if none
// found in 250 attempts. Matches the rune system's
// RUNESPOT_ATTEMPTS - the search volume is the full
// 8192-unit cube around origin so most random points
// land in solid or outside the map; many attempts are
// needed.
vector() RTD_GetDieSpot =
{
    local vector v;
    local float n;

    n = 250;
    while (n > 0)
    {
        v_x = (random() * 8192) - 4096;
        v_y = (random() * 8192) - 4096;
        v_z = (random() * 8192) - 4096;

        if (RTD_CheckDieSpot(v))
            return v;

        n = n - 1;
    }

    return '4096 4096 4096';
};

// Spawns one fresh die entity. Caller must call
// RTD_Die_Place on it to position it on the map.
entity() RTD_Die_Spawn =
{
    local entity d;

    d = spawn();
    d.classname = "rtd_die";
    d.flags = #FL_ITEM;
    d.movetype = #MOVETYPE_TOSS;
    d.solid = #SOLID_TRIGGER;
    d.takedamage = #DAMAGE_NO;
    d.owner = world;
    d.mdl = #RTD_DIE_MDL;
    setmodel(d, d.mdl);
    setsize(d, '-16 -16 -24', '16 16 32');
    d.netname = "Die";
    d.touch = RTD_Die_Touch;

    // Start in the settle phase rather than waiting for
    // the first bounce. avelocity is left at zero - the
    // settle tick manually rotates angles_y each frame.
    // .cnt is the countdown to the first bounce (20-40
    // ticks at 10Hz = 2-4 seconds). After the die drops
    // to the floor and lands, the spin is immediately
    // visible to the player.
    d.cnt = 20 + floor(random() * 20);
    d.think = RTD_Die_Settle;
    d.nextthink = time + 0.1;
    d.ltime = time;
    d.tfstate = #RTD_DIESTATE_READY;

    return d;
};

// Checks if the given spot is inside (or directly above)
// any trigger_hurt brush. Used to reject placements that
// land in death pits / kill zones below the playable map
// area. Returns TRUE if the spot is unsafe.
//
// Using absmin/absmax (world-space bbox) on each
// trigger_hurt to do an exact "is point inside brush"
// check, with a small vertical fudge so dice resting on
// a floor just outside a trigger_hurt zone don't get
// false-positive flagged. Standing on a floor where a
// trigger_hurt sits 1 unit above is still a death zone -
// the player gets hurt the moment they walk onto the
// die.
float(vector spot) RTD_InDeathZone =
{
    local entity te;

    te = find(world, classname, "trigger_hurt");
    while (te)
    {
        if (spot_x >= te.absmin_x && spot_x <= te.absmax_x &&
            spot_y >= te.absmin_y && spot_y <= te.absmax_y &&
            spot_z >= te.absmin_z - 32 && spot_z <= te.absmax_z + 32)
        {
            return #TRUE;
        }
        te = find(te, classname, "trigger_hurt");
    }

    return #FALSE;
};

// Full validation of a die's current resting spot. Used
// both for initial placement (in RTD_Die_Place) and for
// periodic re-validation (in RTD_Die_Think). Returns
// TRUE if the spot is safe, FALSE if the die needs to
// move.
float(vector spot) RTD_DieSpotValid =
{
    if (!RTD_CheckDieSpot(spot))
        return #FALSE;
    if (pointcontents(spot - '0 0 24.1') == #CONTENT_SKY)
        return #FALSE;
    if (RTD_InDeathZone(spot))
        return #FALSE;
    return #TRUE;
};

// Marks a die as "invalid" instead of removing it. The
// entity stays alive in an inert (invisible, non-solid)
// state, and its think will fire shortly to attempt a
// fresh placement at a new spot. This mirrors the rune
// system's InvalidateRune pattern at runes.qc:582-600.
//
// Why not just dremove? Because retries via dremove are
// SERIAL through the watcher (one per RTD_WATCH_TICK).
// Multiple invalidated dice retry in PARALLEL because
// each has its own think schedule. On a map where the
// random spot-finder has a low hit rate, parallel retry
// converges to "both dice placed" much faster.

void() RTD_Die_Invalidate =
{
    self.tfstate = #RTD_DIESTATE_WRONG;
    self.classname = "rtd_die_wrong";
    self.modelindex = 0;
    self.movetype = #MOVETYPE_NONE;
    self.solid = #SOLID_NOT;
    self.touch = SUB_Null;
    self.velocity = '0 0 0';
    self.avelocity = '0 0 0';
    self.think = RTD_Die_RetryThink;
    self.nextthink = time + 0.3 + random() * 0.4;
};

void() RTD_Die_RetryThink =
{
    // Only retry while entmode is still on.
    if (!RTD_EntMode())
    {
        dremove(self);
        return;
    }

    // Try to spawn a new die at a fresh spot. RTD_Die_Place
    // creates a separate entity for the attempt, so this
    // entity is no longer needed regardless of success.
    RTD_Die_Place();
    dremove(self);
};

// Picks a random spot, drops a fresh die there. If
// placement fails, the die is invalidated rather than
// removed, so it'll retry on its own think cycle.
//
// One case here does NOT create a placeholder for retry:
// when RTD_GetDieSpot itself can't find any valid spot
// in its 250 attempts. In that case no entity gets
// created, and the watcher's count-and-refill will
// retry on its next tick.
void() RTD_Die_Place =
{
    local entity d, oself;
    local vector spot;

    spot = RTD_GetDieSpot();
    if (spot == '4096 4096 4096')
    {
        // No retry placeholder needed - never made
        // an entity. The watcher will refill on its
        // next tick.
        return;
    }

    d = RTD_Die_Spawn();
    setorigin(d, spot);

    oself = self;
    self = d;
    if (!droptofloor())
    {
        RTD_Die_Invalidate();
    }
    else if (!RTD_DieSpotValid(d.origin))
    {
        RTD_Die_Invalidate();
    }
    self = oself;
};

// Bounce phase. Fires the hop, the sound, and a fast
// tumble with pitch as the dominant axis so the die
// reads as "rolled across a table" rather than "spun
// like a top". Schedules RTD_Die_Settle to fire ~1.2s
// later (after the bounce arc completes) which damps
// avelocity down to a gentle background spin.
void() RTD_Die_Think =
{
    // Re-validate the current spot. If invalid (e.g., a
    // death zone missed at placement time, or the
    // surrounding geometry changed), dremove. The
    // watcher will spawn a replacement next tick.
    if (!RTD_DieSpotValid(self.origin))
    {
        dremove(self);
        return;
    }

    if (self.flags & #FL_ONGROUND)
    {
        // Small hop with the "magic" sound so players
        // can find dice by sound when nearby.
        self.velocity_z = 150 + crandom() * 30;
        sound(self, #CHAN_BODY, "player/slimbrn2.wav", 0.7, #ATTN_NORM);

        // Fast tumble during the bounce. Quake's
        // avelocity component mapping:
        //   _x = pitch (end-over-end tumble - the
        //          "rolling die on a table" axis)
        //   _y = yaw (spin in horizontal plane)
        //   _z = roll (sideways rotation)
        // Pitch dominates so the die visually tumbles
        // forward; yaw adds the "rolling sideways"
        // variation that makes it look like a die being
        // thrown rather than a top being spun. Direction
        // randomized per bounce.
        self.avelocity_x = 900 + crandom() * 300;   // ~2.5 rotations/sec, dominant
        self.avelocity_y = 360 + crandom() * 180;   // slight yaw tilt
        self.avelocity_z = 180 + crandom() * 120;   // gentle roll
    }

    // After the bounce, hand off to the settle phase.
    // .cnt counts down "settle ticks until next bounce"
    // (tick at 10Hz during settle for smooth manual
    // rotation, so 20-40 ticks = 2-4 seconds of settled
    // spinning before the next bounce).
    self.cnt = 20 + floor(random() * 20);
    self.think = RTD_Die_Settle;
    self.nextthink = time + 0.6;
};

// Settle phase. Fires at 10Hz to keep the model visibly
// spinning between bounces.
//
// IMPORTANT: avelocity alone DOES NOT WORK for entities
// at rest in Quake/QuakeWorld physics. When the engine
// sees an entity with FL_ONGROUND set and zero velocity,
// it stops running physics on it - that includes the
// avelocity-to-angles update. So while the bounce phase
// gets nice tumble (because the die is moving with
// velocity_z = 150 during the bounce arc), once the die
// lands the engine treats it as static and the spin
// stops. Working around this by manually incrementing
// angles_y each tick, at 100 deg/sec to match the QW
// client's built-in EF_ROTATE behavior.
//
// Runes don't have this issue because their .mdl files
// have the Rotate flag set in the model header (client-
// side rotation, independent of server physics).
//
// State on the die:
//   .cnt = remaining settle ticks before next bounce.
//          Decremented each tick. At 0, switches think
//          to RTD_Die_Think (bounce).
void() RTD_Die_Settle =
{
    if (!RTD_DieSpotValid(self.origin))
    {
        dremove(self);
        return;
    }

    // Manual yaw rotation: 10 deg per tick * 10Hz =
    // 100 deg/sec, matches EF_ROTATE rate. Positive
    // direction (counterclockwise viewed from above)
    // matches engine convention for Rotate-flagged
    // pickups.
    self.angles_y = self.angles_y + 10;
    if (self.angles_y >= 360)
        self.angles_y = self.angles_y - 360;

    // Clear leftover avelocity from the bounce so it
    // doesn't keep applying invisible angle changes if
    // the engine ever does process them.
    self.avelocity = '0 0 0';

    // Count down to next bounce.
    self.cnt = self.cnt - 1;
    if (self.cnt <= 0)
    {
        self.think = RTD_Die_Think;
        self.nextthink = time + 0.05;
        return;
    }

    self.nextthink = time + 0.1;
};

// Player touched a die. Validate, broadcast, apply roll,
// remove die, schedule a replacement.
void() RTD_Die_Touch =
{
    local entity die;
    local float pick;

    // The engine sets self = die, other = whoever
    // touched it. Save the die in a local because we'll
    // swap self to the player for the effect dispatch.
    die = self;

    if (other.classname != "player")
        return;
    if (!other.is_connected)
        return;
    if (other.health <= 0)
        return;
    if (other.flags & #FL_FINALIZED)
        return;
    if (other.playerclass == #PC_UNDEFINED)  // observer
        return;
    if (other.done_custom & #CUSTOM_BUILDING)  // mid-class-build
        return;
    if (intermission_running || ceasefire)
        return;
    if (prematch >= time)
        return;

    // If the player is still under the influence of a
    // previous roll, deflect the pickup. The die stays
    // on the map - other players can grab it. Throttle
    // the warning since the engine fires touch every
    // frame the player is overlapping the die's trigger
    // volume (which can be 50+ msgs/sec without this
    // gate). One centerprint every ~3s is plenty.
    if (other.rtd_cooldown > time)
    {
        if (time >= self.heat)
        {
            local string st;
            st = ftos(ceil(other.rtd_cooldown - time));
            centerprint(other, "Your current roll has ", st, " seconds left.\n");
            self.heat = time + 3;
        }
        return;
    }

    // Pickup broadcast.
    bprint(#PRINT_MEDIUM, other.netname, " rolls the dice!\n");

    // Roll a random effect.
    pick = floor(random() * #RTD_NUM_EFFECTS);
    if (pick >= #RTD_NUM_EFFECTS)
        pick = #RTD_NUM_EFFECTS - 1;
    if (pick < 0)
        pick = 0;

    // Lock the player out of further pickups for as long
    // as their effect runs. RTD_EffectDuration returns
    // the per-effect duration. Set BEFORE running the
    // effect so the effect's own logic doesn't see a
    // stale cooldown.
    other.rtd_cooldown = time + RTD_EffectDuration(pick);

    // Apply the effect with `self` set to the roller, as
    // RTD_Finish does in the normal flow. Some effect
    // helpers read `self` (e.g., the grenade-style ones
    // that swap self for the throw).
    self = other;
    RTD_DoEffect(other, pick);

    // Repurpose the die entity as a respawn timer to
    // avoid spawning a second entity just to count
    // down. Make it inert and schedule the respawn.
    self = die;
    self.classname = "rtd_die_respawn";
    self.solid = #SOLID_NOT;
    self.movetype = #MOVETYPE_NONE;
    self.touch = SUB_Null;
    self.modelindex = 0;
    self.velocity = '0 0 0';
    self.avelocity = '0 0 0';
    self.think = RTD_Die_RespawnThink;
    self.nextthink = time + RTD_Cooldown();
};

void() RTD_Die_RespawnThink =
{
    // Are we still in entity mode? If the admin toggled
    // it off during the cooldown, just disappear quietly
    // without spawning a replacement.
    if (!RTD_EntMode())
    {
        dremove(self);
        return;
    }

    RTD_Die_Place();
    dremove(self);
};

// Spawns the initial set of dice when entity mode turns
// on (either at map start or via admin toggle).
void() RTD_EntMode_Start =
{
    local float n;
    n = #RTD_DIE_COUNT;
    while (n > 0)
    {
        RTD_Die_Place();
        n = n - 1;
    }
    bprint(#PRINT_MEDIUM, "RTD: Entity mode active - dice are scattered across the map!\n");
};

// Removes all dice (both placed and pending-respawn) when
// entity mode turns off.
void() RTD_EntMode_Stop =
{
    local entity te, next;

    // Remove active dice.
    te = find(world, classname, "rtd_die");
    while (te)
    {
        next = find(te, classname, "rtd_die");
        dremove(te);
        te = next;
    }

    // Remove pending-respawn timers to prevent a
    // surprise die appearing after the admin turned the
    // mode off.
    te = find(world, classname, "rtd_die_respawn");
    while (te)
    {
        next = find(te, classname, "rtd_die_respawn");
        dremove(te);
        te = next;
    }

    // Remove invalidated dice (retry placeholders) so
    // their RetryThink doesn't spawn fresh dice into a
    // mode that's been turned off.
    te = find(world, classname, "rtd_die_wrong");
    while (te)
    {
        next = find(te, classname, "rtd_die_wrong");
        dremove(te);
        te = next;
    }

    bprint(#PRINT_MEDIUM, "RTD: Entity mode disabled - dice removed.\n");
};

// Counts existing dice (active, pending-respawn, AND
// invalidated/retrying). Used by the watcher to decide
// whether to add another placement attempt. Invalidated
// dice count toward the cap because they'll respawn
// themselves on their own think - if not counted, then
// the watcher would keep spawning fresh attempts in
// parallel with the retries, and the map could end up
// with more than RTD_DIE_COUNT visible dice once
// retries succeed.
float() RTD_CountDice =
{
    local entity te;
    local float n;

    n = 0;

    te = find(world, classname, "rtd_die");
    while (te)
    {
        n = n + 1;
        te = find(te, classname, "rtd_die");
    }

    te = find(world, classname, "rtd_die_respawn");
    while (te)
    {
        n = n + 1;
        te = find(te, classname, "rtd_die_respawn");
    }

    te = find(world, classname, "rtd_die_wrong");
    while (te)
    {
        n = n + 1;
        te = find(te, classname, "rtd_die_wrong");
    }

    return n;
};

// Watcher entity. Two responsibilities:
//   1. Detect rtd_entmode toggle and call Start/Stop.
//   2. Initiate placements when below count. Failed
//      placements convert themselves into invalidated
//      dice that retry independently (see Die_Invalidate
//      and Die_RetryThink), so the watcher mainly
//      handles the case where RTD_GetDieSpot returned
//      no valid spot at all (no entity to invalidate)
//      and it needs to try again.
//
// Tick rate: fast (0.5s) when below count so retries
// converge quickly on bad maps; slow (RTD_WATCH_TICK)
// when at count for normal localinfo polling.
//
// State on the watcher:
//   .cnt = previous tick's RTD_EntMode() value (0 or 1)
void() RTD_EntMode_Watcher_Think =
{
    local float now_on, have, need;

    now_on = RTD_EntMode();
    need = 0;

    if (now_on && !self.cnt)
    {
        // Off -> On transition.
        RTD_EntMode_Start();
    }
    else if (!now_on && self.cnt)
    {
        // On -> Off transition.
        RTD_EntMode_Stop();
    }

    if (now_on)
    {
        have = RTD_CountDice();
        need = #RTD_DIE_COUNT - have;
        if (need > 0)
            RTD_Die_Place();
    }

    self.cnt = now_on;

    // Fast tick (0.5s) when dice still need to be added -
    // ensures rapid retry. Slow tick (RTD_WATCH_TICK)
    // when at count so we're not wasting cycles on a
    // stable map.
    if (now_on && need > 0)
        self.nextthink = time + 0.5;
    else
        self.nextthink = time + #RTD_WATCH_TICK;
};

// Map-start hook. Called from worldspawn after
// InitEnvironment. Precaches the die model, spawns the
// watcher entity. If rtd_entmode was already "on" in
// localinfo when the map loaded, the watcher's first
// tick (~3 seconds later) will spawn the initial dice.
void() RTD_Init =
{
    local entity watcher;

    precache_model(#RTD_DIE_MDL);

    watcher = spawn();
    watcher.classname = "rtd_entmode_watcher";
    watcher.owner = world;
    watcher.cnt = 0;        // assume off at startup; watcher's
                            // first tick triggers Start if on
    watcher.think = RTD_EntMode_Watcher_Think;
    watcher.nextthink = time + 1;  // first check ASAP
};

//=========================================================
// Public entry point. Called from cmnd.qc when a player
// types "cmd rtd".

void(entity p) RTD_Begin =
{
    local entity te;

    // Master enable check. Admins disable RTD entirely
    // by setting `localinfo rtd off`
    if (!RTD_Enabled())
    {
        sprint(p, #PRINT_HIGH, "The server admin has dice rolls disabled at this time.\n");
        return;
    }

    // When entity mode is enabled, players cannot
    // manually trigger rolls - they have to physically
    // pick up a die spawned around the map. The pickup
    // path (RTD_Die_Touch) bypasses this function
    // entirely.
    if (RTD_EntMode())
    {
        sprint(p, #PRINT_HIGH, "RTD: Entity mode is on. Find a die on the map to roll!\n");
        return;
    }

    // Already rolling?
    te = find(world, classname, "rtd_timer");
    while (te != world)
    {
        if (te.owner == p)
        {
            sprint(p, #PRINT_HIGH, "RTD: The dice are already in the air!\n");
            return;
        }
        te = find(te, classname, "rtd_timer");
    }

    // On cooldown?
    if (p.rtd_cooldown > time)
    {
        local string st;
        st = ftos(ceil(p.rtd_cooldown - time));
        sprint(p, #PRINT_HIGH, "RTD: Wait ", st, " more seconds before rolling again.\n");
        return;
    }

    // No rolling while dead, gibbed, observing, finalising, etc. 
    // The caller should have covered most of this, but being safe.
    if (p.health <= 0 || (p.flags & #FL_FINALIZED) || p.playerclass == #PC_UNDEFINED)
    {
        sprint(p, #PRINT_HIGH, "RTD: You can't roll right now.\n");
        return;
    }

    // Server-wide broadcast that this player is rolling.
    bprint(#PRINT_MEDIUM, p.netname, " rolled the dice!\n");

    // Animation enabled? If the admin disabled the
    // animation via `localinfo rtd_anim off`, skip the
    // dice-flip centerprint and apply the effect
    // immediately. RTD_Finish does its own "You rolled:"
    // centerprint via the dispatch, so the player still
    // sees the result clearly.
    if (!RTD_AnimEnabled())
    {
        local entity oself;
        oself = self;
        self = p;
        RTD_ApplyEffect(p);
        self = oself;
        p.rtd_cooldown = time + RTD_Cooldown();
        return;
    }

    // Kick off the animation
    te = spawn();
    te.classname = "rtd_timer";
    te.owner = p;
    te.cnt = #RTD_ANIM_FRAMES;
    te.health = 1;
    te.think = RTD_AnimThink;
    te.nextthink = time + #RTD_ANIM_DELAY;
};
