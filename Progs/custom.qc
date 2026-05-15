/*======================================================
	CUSTOM.QC			Custom TeamFortress v3.2	

	(c) William Kerney			5/21/00
========================================================
All the functions pertaining to custom class generation and 
the miscellanious new features of Custom TF
======================================================*/

void() DropToCustomClassGen; //Called when starting class generation
void() DropFromCustomClassGen; //Called when finished class generation
void() PrintMoney;
void(float in) PrintRefund;
void(float in) PrintNotEnoughMoney;
void(float cost, float type) BuyWeapon;
void(float cost, float type) BuyCuTF;
void(float cost, float type) BuyCuTF2;
void(float cost, float type) BuyItem;
void(float cost, float type) BuyJob;
void(entity tif, float pain) RevealThief;
void() FragGrenadeTouch;
void() FragGrenadeExplode;
void() KracGrenadeTouch;
void() KracGrenadeExplode; 
void(entity bastard,float threshold) createBastard;
void(entity immuner,float timer) makeImmune;
void() UseJobSkill; //Function for handling professions
void() DetonateAllGuns;
//Very useful debug functions
void (string temp) DebugSprint;
void (float temp)  DebugSprintFloat;
float(entity tester) IsBuilding;
void() autoteam_think;
//Extern
void (vector org, entity death_owner) spawn_tdeath;
//void (string gib, float health) ThrowGib;
void(string gibname, float dm, float makecool, float gibskin, float gibkgs, float randorg) ThrowGib;
void() TeamFortress_SetHealth;
void() TeamFortress_SetEquipment;
void() RebuildMaxAmmoFromWeapons; // STAL BACKPORT: defined in client.qc
float() ComputeLoadoutCost;       // STAL: cost of current loadout for `modify`
float() W_BestWeapon;
void() W_SetCurrentAmmo;
void(entity p) TeamFortress_SetSpeed;
void(entity p) TeamFortress_SetSkin;
void(entity Viewer, float pc) TeamFortress_PrintJobName;
void () BecomeExplosion;
void(entity bomb, entity attacker, float rad, entity ignore) T_RadiusDamage;
void() SUB_regen;
float modelindex_eyes, modelindex_player, modelindex_null;
void(float inAuto) W_FireMedikit;
void(float inAuto) TeamFortress_ID;
void(float range,float inAuto) TeamFortress_Scan;
void() kill_my_demons;
void() player_assaultcannondown1;
void (entity rhook) Reset_Grapple;
void() GuerillaExplode;
void(float krac) TeamFortress_DetpackStop;
void(float all, float teamscored, float scorepoints) TeamFortress_TeamShowScores;
void () execute_changelevel;
void(entity Item, entity AP, float method) tfgoalitem_RemoveFromPlayer;
void(entity spy) Spy_RemoveDisguise;

//- OfN
void(entity mine_owner) DetonateMines; //external, job.qc
string (float tno) TeamGetNiceColor;
void(entity player, float start) SetArmyTimer; 
void() RemoveArmyTimer;
entity() SelectSpawnPoint;
void(float full_clean) CleanUpEverything;
//void(entity tfield, vector where, entity thing) FieldExplosion;
void(entity tfield, vector where, entity thing) FieldEvent;
float(entity player) GiveFreeStuff;

void(entity player, float usage) SetMeatUsage;
void(entity player, float usage) SetHeadsUsage;
void(entity player, float soul) SetCurrentSoul;

void(entity player) PlayerDropRunes;
void(entity player) ResetStripedAndGiven;



void (string temp) DebugSprint =
{
	bprint(#PRINT_HIGH,temp);
	bprint(#PRINT_HIGH,"\n");
};

void (float foo)  DebugSprintFloat =
{
	local string temp;
	temp = ftos(foo);
	bprint(#PRINT_HIGH,temp);
	bprint(#PRINT_HIGH,"\n");
};

//================================================
// STAL: ComputeLoadoutCost
//
// Returns the total custom-menu cost of the player's current loadout, summed
// from per-item COST_* values. Used by `modify` to charge the stock-class
// player a deduction equivalent to what a custom-class player would have paid.
//
// If sum exceeds custom_money, the player ends up with negative money and
// must sell items in the menu before finishing.
//
// Cost mapping is the COST_* defines in cutfmenu.qc. Items not in the COST_*
// table (e.g., stock-issue grenades that have no custom equivalent) contribute
// $0. If COST_* or item-bit defines ever change, this function must be updated.
//================================================
float() ComputeLoadoutCost =
{
	local float total;
	total = 0;

	// === Weapons ===
	if (self.weapons_carried & #WEAP_AUTO_RIFLE)
		total = total + #COST_SNIPERRIFLE;
	if (self.weapons_carried & #WEAP_ROCKET_LAUNCHER)
		total = total + #COST_ROCKETLAUNCHER;
	if (self.weapons_carried & #WEAP_DAEDALUS)
		total = total + #COST_DAEDALUS;
	if (self.weapons_carried & #WEAP_ASSAULT_CANNON)
		total = total + #COST_ASSAULTCANNON;
	if (self.weapons_carried & #WEAP_LIGHT_ASSAULT)
		total = total + #COST_LIGHTASSAULT;
	if (self.weapons_carried & #WEAP_SUPER_SHOTGUN)
		total = total + #COST_SUPERSHOTGUN;
	if (self.weapons_carried & #WEAP_SHOTGUN)
		total = total + #COST_SHOTGUN;
	if (self.weapons_carried & #WEAP_GRENADE_LAUNCHER)
		total = total + #COST_GRENADELAUNCHER;
	if (self.weapons_carried & #WEAP_LIGHTNING)
		total = total + #COST_LIGHTNING;
	if (self.weapons_carried & #WEAP_LASERCANNON)
		total = total + #COST_LASERCANNON;
	if (self.weapons_carried & #WEAP_MAUSER)
		total = total + #COST_MAUSER;
	if (self.weapons_carried & #WEAP_SNG)
		total = total + #COST_SNG;
	if (self.weapons_carried & #WEAP_RAILGUN)
		total = total + #COST_RAILGUN;
	if (self.weapons_carried & #WEAP_NAILGUN)
		total = total + #COST_NAILGUN;
	if (self.weapons_carried & #WEAP_TRANQ)
		total = total + #COST_TRANQ;
	if (self.weapons_carried & #WEAP_MEDIKIT)
		total = total + #COST_MEDIKIT;
	if (self.weapons_carried & #WEAP_AIRF)
		total = total + #COST_AIRF;
	if (self.weapons_carried & #WEAP_HOOK)
	{
		if (!allow_hook)
			total = total + #COST_HOOK;
		else if (no_grapple == 1)
			total = total + #COST_HOOK;
	}
	if (self.weapons_carried & #WEAP_INCENDIARY)
		total = total + #COST_PYROTOYS;     // bundle: INCENDIARY|FLAMETHROWER
	if (self.weapons_carried & #WEAP_SPANNER)
		total = total + #COST_SPANNER;

	// === tf_items (NIT_*) ===
	if (self.tf_items & #NIT_RL_LASER_SIGHT)
		total = total + #COST_RLASERGUIDED;
	if (self.tf_items & #NIT_CLUSTER_ROCKETS)
		total = total + #COST_CLUSTER;
	if (self.tf_items & #NIT_SCUBA)
		total = total + #COST_SCUBA;
	if (self.tf_items & #NIT_CERAMIC)
		total = total + #COST_CERAMIC;
	if (self.tf_items & #NIT_GEL)
		total = total + #COST_GEL;
	if (self.tf_items & #NIT_ASBESTOS)
		total = total + #COST_ASBESTOS;
	if (self.tf_items & #NIT_KEVLAR)
		total = total + #COST_KEVLAR;
	if (self.tf_items & #NIT_BLAST)
		total = total + #COST_BLAST;
	if (self.tf_items & #NIT_TURRET)
		total = total + #COST_SENTRYUPGRADE;
	if (self.tf_items & #NIT_TESLA)
		total = total + #COST_TESLACOIL;
	if (self.tf_items & #NIT_DOUBLETESLA)
		total = total + #COST_TESLACOIL;
	if (self.tf_items & #NIT_TESLA_UPGRADE)
		total = total + #COST_TESLAUPGRADE;
	if (self.tf_items & #NIT_TELEPORTER)
		total = total + #COST_TELEPORTER;
	if (self.tf_items & #NIT_AUTOSCANNER)
		total = total + #COST_AUTOSCANNER;
	if (self.tf_items & #NIT_SCANNER)
		total = total + #COST_SCANNER;
	if (self.tf_items & #NIT_SECURITY_CAMERA)
		total = total + #COST_SECURITYCAMERA;
	if (self.tf_items & #NIT_AUTOID)
		total = total + #COST_AUTOID;
	if (self.tf_items & #NIT_RESPAWN_GUARD)
		total = total + #COST_RESPAWNGUARD;
	if (self.tf_items & #NIT_HOVER_BOOTS)
		total = total + #COST_HOVERBOOTS;
	if (self.tf_items & #NIT_HOVER_BOOTS_UPGRADE)
		total = total + #COST_BOOTUPGRADE;
	if (self.tf_items & #NIT_AMMO_BACKPACK)
		total = total + #COST_AMMOBACKPACK;
	if (self.tf_items & #NIT_AMMO_BANDOLIER)
		total = total + #COST_AMMOBANDOLIER;

	// === cutf_items (CUTF_*) ===
	if (self.cutf_items & #CUTF_OTR)
		total = total + #COST_OTR;
	if (self.cutf_items & #CUTF_AIRFISTUPGRADE)
		total = total + #COST_AIRFISTUPGRADE;
	if (self.cutf_items & #CUTF_KNIFE)
		total = total + #COST_KNIFE;
	if (self.cutf_items & #CUTF_FULLARMOUR)
		total = total + #COST_FULLARMOUR;
	if (self.cutf_items & #CUTF_TOSSABLEDET)
		total = total + #COST_TOSSABLEDET;
	if (self.cutf_items & #CUTF_DETPACK)
		total = total + #COST_DETPACK;
	if (self.cutf_items & #CUTF_HOLO)
		total = total + #COST_HOLO;
	if (self.cutf_items & #CUTF_CYBERAUG)
		total = total + #COST_CYBERAUG;
	if (self.cutf_items & #CUTF_SPY_KIT)
		total = total + #COST_SPYKIT;
	if (self.cutf_items & #CUTF_CLIPEXTEND)
		total = total + #COST_CLIPEXTEND;
	if (self.cutf_items & #CUTF_SENTRYGUN)
		total = total + #COST_SENTRYGUN;
	if (self.cutf_items & #CUTF_DOUBLESENTRY)
		total = total + #COST_SENTRYGUN;
	if (self.cutf_items & #CUTF_SENSOR)
		total = total + #COST_SENSOR;
	if (self.cutf_items & #CUTF_JAMMER)
		total = total + #COST_JAMMER;
	if (self.cutf_items & #CUTF_DISPENSER)
		total = total + #COST_DISPENSER;
	if (self.cutf_items & #CUTF_FIELDGEN)
		total = total + #COST_FIELDGEN;
	if (self.cutf_items & #CUTF_STEALTH)
		total = total + #COST_STEALTH;
	if (self.cutf_items & #CUTF_HIGHJUMP)
		total = total + #COST_HIGHJUMP;
	if (self.cutf_items & #CUTF_EXPBODY)
		total = total + #COST_EXPBODY;
	if (self.cutf_items & #CUTF_CLOSECOMBAT)
		total = total + #COST_CLOSECOMBAT;
	if (self.cutf_items & #CUTF_DEMONLORE)
		total = total + #COST_DEMONLORE;
	if (self.cutf_items & #CUTF_HWGUY)
		total = total + #COST_HWGUY;
	if (self.cutf_items & #CUTF_GYMNAST)
		total = total + #COST_GYMNAST;

	// === cutf2_items (CUTF2_*) ===
	if (self.cutf2_items & #CUTF2_SHINIGAMI)
		total = total + #COST_SHINIGAMI;
	if (self.cutf2_items & #CUTF2_CRIPPLER)
		total = total + #COST_CRIPPLER;
	if (self.cutf2_items & #CUTF2_OVERCHARGE)
		total = total + #COST_OVERCHARGE;
	if (self.cutf2_items & #CUTF2_CHARGER)
		total = total + #COST_CHARGER;
	if (self.cutf2_items & #CUTF2_INITIALIZER)
		total = total + #COST_INITIALIZER;
	if (self.cutf2_items & #CUTF2_FASTER_ROX)
		total = total + #COST_FASTER_ROX;
	if (self.cutf2_items & #CUTF2_HEAT_SEEKING)
		total = total + #COST_HEAT_SEEKING;
	if (self.cutf2_items & #CUTF2_LONG_BARREL)
		total = total + #COST_LONG_BARREL;
	if (self.cutf2_items & #CUTF2_EXPLOSIVE_SHOT)
		total = total + #COST_EXPLOSIVE_SHOT;
	if (self.cutf2_items & #CUTF2_ARMOR_PIERCING)
		total = total + #COST_ARMOR_PIERCING;
	if (self.cutf2_items & #CUTF2_CANNIBAL)
		total = total + #COST_CANNIBAL;
	if (self.cutf2_items & #CUTF2_VOID_BODY)
		total = total + #COST_VOID_BODY;
	if (self.cutf2_items & #CUTF2_RECOILLESS_RIFLE)
		total = total + #COST_RECOILLESS;
	if (self.cutf2_items & #CUTF2_MASSIVE_ATTACK)
		total = total + #COST_MASSIVE_ATTACK;
	if (self.cutf2_items & #CUTF2_BLACK_HOLE_GUN)
		total = total + #COST_BLACK_HOLE_GUN;

	// === Job (identity + extras) ===
	if (self.job & #JOB_THIEF)
		total = total + #COST_THIEF;
	if (self.job & #JOB_RUNNER)
		total = total + #COST_RUNNER;
	if (self.job & #JOB_WARLOCK)
		total = total + #COST_WARLOCK;
	if (self.job & #JOB_CHAPLAN)
		total = total + #COST_CHAPLAN;
	if (self.job & #JOB_BERSERKER)
		total = total + #COST_BERSERKER;
	if (self.job & #JOB_GUERILLA)
		total = total + #COST_GUERILLA;
	if (self.job & #JOB_JUDOKA)
		total = total + #COST_JUDOKA;
	if (self.job & #JOB_ARMY)
		total = total + #COST_ARMY;
	if (self.job & #JOB_HACKER)
		total = total + #COST_HACKER;
	if (self.job & #JOB_MARTYR)
		total = total + #COST_MARTYR;
	if (self.job & #JOB_CRUSADER)
		total = total + #COST_CRUSADER;
	if (self.job & #JOB_TKD)
		total = total + #COST_TKD;
	if (self.job & #JOB_PSION)
		total = total + #COST_PSION;

	// Job extras: not all jobs have extras, only those that do are billed.
	// JOB_EXTRA1 / JOB_EXTRA2 cost depends on which job the player has.
	if (self.job & #JOB_EXTRA1)
	{
		if (self.job & #JOB_THIEF)
			total = total + #COST_THIEF_EXTRA1;
		if (self.job & #JOB_WARLOCK)
			total = total + #COST_WARLOCK_EXTRA1;
		if (self.job & #JOB_GUERILLA)
			total = total + #COST_GUERILLA_EXTRA1;
		if (self.job & #JOB_ARMY)
			total = total + #COST_ARMY_EXTRA1;
		if (self.job & #JOB_PSION)
			total = total + #COST_PSION_EXTRA1;
	}
	if (self.job & #JOB_EXTRA2)
	{
		if (self.job & #JOB_THIEF)
			total = total + #COST_THIEF_EXTRA2;
		if (self.job & #JOB_WARLOCK)
			total = total + #COST_WARLOCK_EXTRA2;
		if (self.job & #JOB_GUERILLA)
			total = total + #COST_GUERILLA_EXTRA2;
		if (self.job & #JOB_ARMY)
			total = total + #COST_ARMY_EXTRA2;
		if (self.job & #JOB_PSION)
			total = total + #COST_PSION_EXTRA2;
	}

	// === Speed tier (custom_speed) ===
	// Tier 7 (Imperial Penguin = 250) is free.
	if (self.custom_speed == 430)
		total = total + #COST_SPEED1;
	else if (self.custom_speed == 380)
		total = total + #COST_SPEED2;
	else if (self.custom_speed == 330)
		total = total + #COST_SPEED3;
	else if (self.custom_speed == 310)
		total = total + #COST_SPEED4;
	else if (self.custom_speed == 290)
		total = total + #COST_SPEED5;
	else if (self.custom_speed == 270)
		total = total + #COST_SPEED6;
	// 250 (or 0) -> free.

	// === Health/armor tier ===
	// Tier 0 (50/50 green, maxarmor 0) is free.
	// Tier 1 (50 armor, 75 hp): maxarmor==50 && max_health==75
	// Tier 2 (50 armor, 90 hp): maxarmor==50 && max_health==90
	// Tier 3 (100 armor): maxarmor==100
	// Tier 4 (120 armor): maxarmor==120
	// Tier 5 (150 armor): maxarmor==150
	// Tier 6 (200 armor): maxarmor==200
	// Tier 7 (300 armor): maxarmor==300
	if (self.maxarmor == 300)
		total = total + #COST_HP7;
	else if (self.maxarmor == 200)
		total = total + #COST_HP6;
	else if (self.maxarmor == 150)
		total = total + #COST_HP5;
	else if (self.maxarmor == 120)
		total = total + #COST_HP4;
	else if (self.maxarmor == 100)
		total = total + #COST_HP3;
	else if (self.maxarmor == 50)
	{
		if (self.max_health == 90)
			total = total + #COST_HP2;
		else if (self.max_health == 75)
			total = total + #COST_HP1;
		// max_health == 50 -> tier 0 (free, but encoded as maxarmor==0
		//   normally; the maxarmor==50 && max_health==50 case is unusual).
	}
	// maxarmor == 0 (with maxarmor==50 max_health==50 fallthrough) -> free.

	// === Grenade slots ===
	// tp_grenades_1 and tp_grenades_2 hold the *type*, not the count. Cost
	// is per-slot (one charge per grenade type), regardless of how many
	// grenades the player carries of that type.
	if (self.tp_grenades_1 == #GR_TYPE_NORMAL)
		total = total + #COST_GR_NORMAL;
	else if (self.tp_grenades_1 == #GR_TYPE_FLAME)
		total = total + #COST_GR_NAPALM;
	else if (self.tp_grenades_1 == #GR_TYPE_GAS)
		total = total + #COST_GR_GAS;
	else if (self.tp_grenades_1 == #GR_TYPE_EMP)
		total = total + #COST_GR_EMP;
	else if (self.tp_grenades_1 == #GR_TYPE_FRAG)
		total = total + #COST_GR_FRAG;
	else if (self.tp_grenades_1 == #GR_TYPE_NAIL)
		total = total + #COST_GR_NAIL;
	else if (self.tp_grenades_1 == #GR_TYPE_MIRV)
		total = total + #COST_GR_MIRV;
	else if (self.tp_grenades_1 == #GR_TYPE_FLARE)
		total = total + #COST_GR_FLARE;
	else if (self.tp_grenades_1 == #GR_TYPE_CALTROP)
		total = total + #COST_GR_CALTROP;
	else if (self.tp_grenades_1 == #GR_TYPE_CONCUSSION)
		total = total + #COST_GR_CONCUSSION;
	else if (self.tp_grenades_1 == #GR_TYPE_PSIONIC)
		total = total + #COST_GR_PSIONIC;
	else if (self.tp_grenades_1 == #GR_TYPE_ANTIGRAV)
		total = total + #COST_GR_ANTIGRAV;
	else if (self.tp_grenades_1 == #GR_TYPE_BIO)
		total = total + #COST_GR_BIOLOGICAL;
	else if (self.tp_grenades_1 == #GR_TYPE_KRAC)
		total = total + #COST_GR_KRAC;

	if (self.tp_grenades_2 == #GR_TYPE_NORMAL)
		total = total + #COST_GR_NORMAL;
	else if (self.tp_grenades_2 == #GR_TYPE_FLAME)
		total = total + #COST_GR_NAPALM;
	else if (self.tp_grenades_2 == #GR_TYPE_GAS)
		total = total + #COST_GR_GAS;
	else if (self.tp_grenades_2 == #GR_TYPE_EMP)
		total = total + #COST_GR_EMP;
	else if (self.tp_grenades_2 == #GR_TYPE_FRAG)
		total = total + #COST_GR_FRAG;
	else if (self.tp_grenades_2 == #GR_TYPE_NAIL)
		total = total + #COST_GR_NAIL;
	else if (self.tp_grenades_2 == #GR_TYPE_MIRV)
		total = total + #COST_GR_MIRV;
	else if (self.tp_grenades_2 == #GR_TYPE_FLARE)
		total = total + #COST_GR_FLARE;
	else if (self.tp_grenades_2 == #GR_TYPE_CALTROP)
		total = total + #COST_GR_CALTROP;
	else if (self.tp_grenades_2 == #GR_TYPE_CONCUSSION)
		total = total + #COST_GR_CONCUSSION;
	else if (self.tp_grenades_2 == #GR_TYPE_PSIONIC)
		total = total + #COST_GR_PSIONIC;
	else if (self.tp_grenades_2 == #GR_TYPE_ANTIGRAV)
		total = total + #COST_GR_ANTIGRAV;
	else if (self.tp_grenades_2 == #GR_TYPE_BIO)
		total = total + #COST_GR_BIOLOGICAL;
	else if (self.tp_grenades_2 == #GR_TYPE_KRAC)
		total = total + #COST_GR_KRAC;

	return total;
};

void() DropToCustomClassGen =
{   
	//local entity te;
	local float sell_no;
	//local string st;
	sell_no = 0;

	// STAL BACKPORT: preserve mode fires in two cases:
	//
	// 1. Re-customize after a finished custom build: done_custom & CUSTOM_FINISHED.
	//    Set by DropFromCustomClassGen on menu exit; cleared (done_custom = 0)
	//    when player switches to non-custom class. So if FINISHED is set AND
	//    player is PC_CUSTOM, they just came from a completed custom build.
	//
	// 2. `modify` command from a stock class: done_custom & CUSTOM_MODIFY.
	//    Set by the TF_MODIFY impulse handler in weapons.qc. The stock class's
	//    fields (tf_items/weapons_carried/etc.) are populated equivalently to
	//    a custom class, so preserve mode pre-fills the menu with the stock
	//    loadout, letting the player edit on top of it.
	//
	// Wipe mode covers everything else: first-time custom, stock-class-to-custom
	// via plain `custom` command (no MODIFY flag), etc.
	local float do_preserve;
	do_preserve = 0;
	if (self.playerclass == #PC_CUSTOM)
	if (self.done_custom & #CUSTOM_FINISHED)
		do_preserve = 1;
	if (self.playerclass == #PC_CUSTOM)
	if (self.done_custom & #CUSTOM_MODIFY)
		do_preserve = 1;
    
	// STAL BACKPORT: force wipe-mode (skip preserve) for two cases:
	//
	// 1. CUSTOM_BUILDING set: player typed `custom` from INSIDE the menu to
	//    restart their build. This is the documented "sell everything back,
	//    refund money to max" feature shown on page 1 of the custom menu.
	//    From outside the menu, done_custom is CUSTOM_FINISHED -- BUILDING is
	//    only set while actively inside the menu (see line "done_custom =
	//    CUSTOM_BUILDING" near end of this function).
	//
	// 2. CUSTOM_SELLING set: player typed `upgrade` to convert frags to money.
	//    This explicitly wants the full reset path so frag-bonus money applies
	//    to a fresh custom_money baseline.
	//
	// In both cases, preserve mode would be wrong -- the user explicitly asked
	// to redo their loadout from scratch.
	if (self.done_custom & #CUSTOM_BUILDING)
		do_preserve = 0;
	if (self.done_custom & #CUSTOM_SELLING)
		do_preserve = 0;

	if (do_preserve)
	{
		// === PRESERVE MODE ===
		local float tmpjob;

		// STAL BACKPORT: if this is a `modify` entry (stock-class -> custom),
		// snap the player's stock speed/armor/health to the nearest custom
		// tier values BEFORE preserve mode reads them. Stock classes set
		// these fields to values that don't match the custom-class tier
		// system, which causes the buy menu to show the wrong selection
		// (default-display, e.g. "Imperial Penguin" for speed) and breaks
		// movement on menu exit (custom_speed stays 0 -> maxspeed = 0).
		//
		// Also reset money to custom_money so the player has a real budget.
		// Stock-class money is typically 0, which strands the player.
		if (self.done_custom & #CUSTOM_MODIFY)
		{
			// STAL DEBUG: snap-entry state
/* 			bprint(#PRINT_HIGH, "DEBUG snap-entry: max_health=");
			bprint(#PRINT_HIGH, ftos(self.max_health));
			bprint(#PRINT_HIGH, " maxarmor=");
			bprint(#PRINT_HIGH, ftos(self.maxarmor));
			bprint(#PRINT_HIGH, " maxspeed=");
			bprint(#PRINT_HIGH, ftos(self.maxspeed));
			bprint(#PRINT_HIGH, " money=");
			bprint(#PRINT_HIGH, ftos(self.money));
			bprint(#PRINT_HIGH, " done_custom=");
			bprint(#PRINT_HIGH, ftos(self.done_custom));
			bprint(#PRINT_HIGH, " modify_origin_class=");
			bprint(#PRINT_HIGH, ftos(self.modify_origin_class));
			bprint(#PRINT_HIGH, "\n"); */
			// STAL BACKPORT: populate item bits for the named stock class.
			// Without this, the player's current weapons_carried/tf_items/etc.
			// persist from their previous respawn -- so `modify scout` from
			// a Sniper would show Sniper items (Sniper's bits are still on
			// the entity), not Scout items.
			//
			// We can't call TeamFortress_SetEquipment to do this, because it
			// has side effects unsuitable for menu state (spawns a
			// CheatCheck timer, modifies undercover_team, etc.). Instead,
			// assign the PC_<class>_* constants directly. The snap below
			// then overrides armor/health/speed to menu-tier values.

			// Clear all loadout state first.
			self.weapons_carried = 0;
			self.tf_items = 0;
			self.tf_items_flags = 0;
			self.cutf_items = 0;
			self.cutf2_items = 0;
			self.job = self.job - (self.job & (#JOB_ALL | #JOB_EXTRA1 | #JOB_EXTRA2));

			// Populate from the named class's stock constants.
			if (self.modify_origin_class == #PC_SCOUT)
			{
				self.weapons_carried = #PC_SCOUT_WEAPONS;
				self.tf_items = #PC_SCOUT_TF_ITEMS;
				self.cutf_items = #PC_SCOUT_CUTFITEMS;
				self.job = self.job | #PC_SCOUT_JOB;
				self.tp_grenades_1 = #PC_SCOUT_GRENADE_TYPE_1;
				self.tp_grenades_2 = #PC_SCOUT_GRENADE_TYPE_2;
				self.no_grenades_1 = #PC_SCOUT_GRENADE_INIT_1;
				self.no_grenades_2 = #PC_SCOUT_GRENADE_INIT_2;
			}
			else if (self.modify_origin_class == #PC_SNIPER)
			{
				self.weapons_carried = #PC_SNIPER_WEAPONS;
				self.tf_items = #PC_SNIPER_TF_ITEMS;
				self.cutf_items = #PC_SNIPER_CUTF_ITEMS;   // note: underscore between CUTF and ITEMS, unlike other classes
				self.job = self.job | #PC_SNIPER_JOB;
				self.tp_grenades_1 = #PC_SNIPER_GRENADE_TYPE_1;
				self.tp_grenades_2 = #PC_SNIPER_GRENADE_TYPE_2;
				self.no_grenades_1 = #PC_SNIPER_GRENADE_INIT_1;
				self.no_grenades_2 = #PC_SNIPER_GRENADE_INIT_2;
			}
			else if (self.modify_origin_class == #PC_SOLDIER)
			{
				self.weapons_carried = #PC_SOLDIER_WEAPONS;
				self.tf_items = #PC_SOLDIER_TF_ITEMS;
				// no PC_SOLDIER_CUTFITEMS; Soldier has no cutf items
				self.job = self.job | #PC_SOLDIER_JOB;
				self.tp_grenades_1 = #PC_SOLDIER_GRENADE_TYPE_1;
				self.tp_grenades_2 = #PC_SOLDIER_GRENADE_TYPE_2;
				self.no_grenades_1 = #PC_SOLDIER_GRENADE_INIT_1;
				self.no_grenades_2 = #PC_SOLDIER_GRENADE_INIT_2;
			}
			else if (self.modify_origin_class == #PC_DEMOMAN)
			{
				self.weapons_carried = #PC_DEMOMAN_WEAPONS;
				self.tf_items = #PC_DEMOMAN_TF_ITEMS;
				self.cutf_items = #PC_DEMOMAN_CUTFITEMS;
				self.job = self.job | #PC_DEMOMAN_JOB;
				self.tp_grenades_1 = #PC_DEMOMAN_GRENADE_TYPE_1;
				self.tp_grenades_2 = #PC_DEMOMAN_GRENADE_TYPE_2;
				self.no_grenades_1 = #PC_DEMOMAN_GRENADE_INIT_1;
				self.no_grenades_2 = #PC_DEMOMAN_GRENADE_INIT_2;
			}
			else if (self.modify_origin_class == #PC_MEDIC)
			{
				self.weapons_carried = #PC_MEDIC_WEAPONS;
				self.tf_items = #PC_MEDIC_TF_ITEMS;
				// no PC_MEDIC_CUTFITEMS; Medic has no cutf items
				self.job = self.job | #PC_MEDIC_JOB;
				self.tp_grenades_1 = #PC_MEDIC_GRENADE_TYPE_1;
				self.tp_grenades_2 = #PC_MEDIC_GRENADE_TYPE_2;
				self.no_grenades_1 = #PC_MEDIC_GRENADE_INIT_1;
				self.no_grenades_2 = #PC_MEDIC_GRENADE_INIT_2;
			}
			else if (self.modify_origin_class == #PC_HVYWEAP)
			{
				self.weapons_carried = #PC_HVYWEAP_WEAPONS;
				self.tf_items = #PC_HVYWEAP_TF_ITEMS;
				self.cutf_items = #CUTF_HWGUY;   // HWGuy uses CUTF_HWGUY literal (no PC_HVYWEAP_CUTFITEMS define)
				self.job = self.job | #PC_HVYWEAP_JOB;
				self.tp_grenades_1 = #PC_HVYWEAP_GRENADE_TYPE_1;
				self.tp_grenades_2 = #PC_HVYWEAP_GRENADE_TYPE_2;
				self.no_grenades_1 = #PC_HVYWEAP_GRENADE_INIT_1;
				self.no_grenades_2 = #PC_HVYWEAP_GRENADE_INIT_2;
			}
			else if (self.modify_origin_class == #PC_PYRO)
			{
				self.weapons_carried = #PC_PYRO_WEAPONS;
				self.tf_items = #PC_PYRO_TF_ITEMS;
				// no PC_PYRO_CUTFITEMS; Pyro has no cutf items
				self.job = self.job | #PC_PYRO_JOB;
				self.tp_grenades_1 = #PC_PYRO_GRENADE_TYPE_1;
				self.tp_grenades_2 = #PC_PYRO_GRENADE_TYPE_2;
				self.no_grenades_1 = #PC_PYRO_GRENADE_INIT_1;
				self.no_grenades_2 = #PC_PYRO_GRENADE_INIT_2;
			}
			else if (self.modify_origin_class == #PC_SPY)
			{
				self.weapons_carried = #PC_SPY_WEAPONS;
				self.tf_items = #PC_SPY_TF_ITEMS;
				self.cutf_items = #PC_SPY_CUTFITEMS;
				self.job = self.job | #PC_SPY_JOB;
				self.tp_grenades_1 = #PC_SPY_GRENADE_TYPE_1;
				self.tp_grenades_2 = #PC_SPY_GRENADE_TYPE_2;
				self.no_grenades_1 = #PC_SPY_GRENADE_INIT_1;
				self.no_grenades_2 = #PC_SPY_GRENADE_INIT_2;
			}
			else if (self.modify_origin_class == #PC_ENGINEER)
			{
				self.weapons_carried = #PC_ENGINEER_WEAPONS;
				self.tf_items = #PC_ENGINEER_TF_ITEMS;
				self.cutf_items = #PC_ENGINEER_CUTFITEMS;
				self.job = self.job | #PC_ENGINEER_JOB;
				self.tp_grenades_1 = #PC_ENGINEER_GRENADE_TYPE_1;
				self.tp_grenades_2 = #PC_ENGINEER_GRENADE_TYPE_2;
				self.no_grenades_1 = #PC_ENGINEER_GRENADE_INIT_1;
				self.no_grenades_2 = #PC_ENGINEER_GRENADE_INIT_2;
			}
            
			// STAL BACKPORT: assign tier values from the stock class's PC_* constants.
			// We can't read self.maxspeed / max_health here -- PutClientInServer
			// resets max_health to 100 for non-CUSTOM playerclasses (which the
			// player WAS at line 2424 before being switched to PC_CUSTOM), and
			// stock-class SetHealth/SetSpeed never re-fires because by the time
			// they're called the playerclass is already PC_CUSTOM (they fall
			// through with no branch for PC_CUSTOM). So the values on `self` are
			// stale/uninitialized. Read the class constants directly.
			//
			// modify_origin_class was captured in the TF_MODIFY impulse handler
			// before nextpc was switched to PC_CUSTOM.

			// --- custom_speed: pick from PC_<class>_MAXSPEED snapped to nearest CUSTOM_SPEED tier.
			// Stock speeds: Scout 420, Sniper 320, Soldier 250, Demoman 290,
			//   Medic 340, HWGuy 250, Pyro 290, Spy 320, Engineer 290.
			// Tier values: 430 / 380 / 330 / 310 / 290 / 270 / 250.
			if (self.modify_origin_class == #PC_SCOUT)
				self.custom_speed = 430;    // 420 -> nearest is Cheetah 430
			else if (self.modify_origin_class == #PC_SNIPER)
				self.custom_speed = 330;    // 320 -> White Rhino 330
			else if (self.modify_origin_class == #PC_SOLDIER)
				self.custom_speed = 250;    // 250 -> Imperial Penguin
			else if (self.modify_origin_class == #PC_DEMOMAN)
				self.custom_speed = 290;    // 290 -> KGB Officer
			else if (self.modify_origin_class == #PC_MEDIC)
				self.custom_speed = 330;    // 340 -> White Rhino 330
			else if (self.modify_origin_class == #PC_HVYWEAP)
				self.custom_speed = 250;    // 250 -> Imperial Penguin
			else if (self.modify_origin_class == #PC_PYRO)
				self.custom_speed = 290;    // 290 -> KGB Officer
			else if (self.modify_origin_class == #PC_SPY)
				self.custom_speed = 330;    // 320 -> White Rhino 330
			else if (self.modify_origin_class == #PC_ENGINEER)
				self.custom_speed = 290;    // 290 -> KGB Officer
			else
				self.custom_speed = 250;    // fallback

			// --- maxarmor / max_health: pick from PC_<class>_MAXARMOR/MAXHEALTH
			// snapped to nearest valid menu tier. Menu valid maxarmor values:
			// 0, 50, 100, 120, 150, 200, 300.
			// Stock armor: Scout 50, Sniper 50, Soldier 200, Demoman 120,
			//   Medic 100, HWGuy 300, Pyro 150, Spy 100, Engineer 75.
			// Stock health: Scout 75, Sniper 90, Soldier 100, Demoman 100,
			//   Medic 90, HWGuy 100, Pyro 100, Spy 90, Engineer 100.
			//
			// Tier-display max_health: tier 0 (50 ar) / tier 1 (50/75) /
			//   tier 2 (50/90) / tier 3 (100/80) / tier 4 (120/90) /
			//   tier 5 (150/100) / tier 6 (200/100) / tier 7 (300/100).
			if (self.modify_origin_class == #PC_SCOUT)
			{
				self.maxarmor = 50;
				self.max_health = 75;       // tier 1: 50/75 Green
			}
			else if (self.modify_origin_class == #PC_SNIPER)
			{
				self.maxarmor = 50;
				self.max_health = 90;       // tier 2: 50/90 Green
			}
			else if (self.modify_origin_class == #PC_SOLDIER)
			{
				self.maxarmor = 200;
				self.max_health = 100;      // tier 6: 200/100 Red
			}
			else if (self.modify_origin_class == #PC_DEMOMAN)
			{
				self.maxarmor = 120;
				self.max_health = 90;       // tier 4: 120/90 Yellow
			}
			else if (self.modify_origin_class == #PC_MEDIC)
			{
				self.maxarmor = 100;
				self.max_health = 80;       // tier 3: 100/80 Yellow
			}
			else if (self.modify_origin_class == #PC_HVYWEAP)
			{
				self.maxarmor = 300;
				self.max_health = 100;      // tier 7: 300/100 Red
			}
			else if (self.modify_origin_class == #PC_PYRO)
			{
				self.maxarmor = 150;
				self.max_health = 100;      // tier 5: 150/100 Yellow
			}
			else if (self.modify_origin_class == #PC_SPY)
			{
				self.maxarmor = 100;
				self.max_health = 80;       // tier 3: 100/80 Yellow
			}
			else if (self.modify_origin_class == #PC_ENGINEER)
			{
				// Engineer's stock 75 armor isn't a menu tier; snap to 100.
				self.maxarmor = 100;
				self.max_health = 80;       // tier 3: 100/80 Yellow
			}
			else
			{
				self.maxarmor = 50;
				self.max_health = 50;       // tier 0 fallback
			}

			// Refill armorvalue to the new maxarmor.
			self.armorvalue = self.maxarmor;

			// Give the player custom_money minus the cost of their current
			// stock loadout. The deduction treats stock equipment as if the
			// player had bought it from the custom menu.
			// Result can be negative -- player must sell items in the menu
			// before finishing if so.
			self.money = custom_money - ComputeLoadoutCost();
            
			// STAL DEBUG: snap-exit state
/* 			bprint(#PRINT_HIGH, "DEBUG snap-exit: max_health=");
			bprint(#PRINT_HIGH, ftos(self.max_health));
			bprint(#PRINT_HIGH, " maxarmor=");
			bprint(#PRINT_HIGH, ftos(self.maxarmor));
			bprint(#PRINT_HIGH, " custom_speed=");
			bprint(#PRINT_HIGH, ftos(self.custom_speed));
			bprint(#PRINT_HIGH, " money=");
			bprint(#PRINT_HIGH, ftos(self.money));
			bprint(#PRINT_HIGH, "\n"); */
            
			// Clear modify_origin_class -- it was a one-shot signal.
			self.modify_origin_class = 0;

			// NOTE: don't clear CUSTOM_MODIFY here. DropFromCustomClassGen
			// reads the flag (before its line that overwrites done_custom to
			// CUSTOM_FINISHED) to suppress the bonus_health conversion --
			// leftover money from `modify`'s loadout deduction is a partial
			// refund, not unspent budget, and shouldn't convert to free HP.
		}
        
		// Things that must always reset between menu-open and menu-exit:
		self.gravity = 1;
		self.aura = 0;
		self.is_malfunctioning = 0;

		// Preserve job purchase + extras across CleanUpEverything (which is
		// safe but the job-bit dance matches 2604's pattern and is robust to
		// any future change in CleanUpEverything).
		tmpjob = self.job;
		self.job = 0;

		CleanUpEverything(#FALSE);

		// Restore job identity + extras only. Drop runtime state bits:
		//   JOB_ACTIVE, JOB_TIRED, JOB_FULL_HIDE  -- per-life states
		//   JOB_BLOODY_KNIFE                       -- per-life Warlock state
		// (Per design: bloody knife resets to regular knife on re-customize.)
		self.job = tmpjob & (#JOB_ALL | #JOB_EXTRA1 | #JOB_EXTRA2);

		// Live ammo / in-hand weapon: always reset (player is in menu, not playing).
		self.ammo_rockets = 0;
		self.ammo_nails = 0;
		self.ammo_shells = 0;
		self.ammo_cells = 0;
		self.ammo_c4det = 0;
		self.currentammo = 0;
		self.current_weapon = 0;
		self.weaponmodel = "";

		// Re-OR HOOK if the map allows it (don't clobber preserved weapons_carried).
		if ((allow_hook) && (no_grapple != 1))
			self.weapons_carried = self.weapons_carried | #WEAP_HOOK;

		// Rebuild maxammo_* exactly from preserved weapons_carried + cutf/cutf2 items.
		// This guarantees maxammo matches the loadout even if it was inconsistent
		// before (stale state, prior bugs, etc.). The Buy* functions will then
		// adjust correctly on toggle inside the menu.
		RebuildMaxAmmoFromWeapons();

		// Clamp health/armor to preserved tier (max_health, maxarmor are preserved).
		TeamFortress_SetHealth();
		self.armorvalue = self.maxarmor;

		// Menu state: locked, no movement, no damage.
		self.solid = #SOLID_NOT;
		self.movetype = #MOVETYPE_NONE;
		self.takedamage = #DAMAGE_NO;
		self.maxspeed = 0;

		// NOTE: do NOT reset money to custom_money -- preserve what they had.
		// NOTE: do NOT reset custom_speed -- it's part of the preserved loadout.
		// NOTE: do NOT touch tf_items / cutf_items / cutf2_items / weapons_carried
		//       / tp_grenades_* / no_grenades_* / tf_items_flags / items
		//       / armor_allowed / armorclass / maxarmor / max_health -- all preserved.
		// NOTE: demon_one/two/three are already nulled by CleanUpEverything.
	}
	else
	{
		// === WIPE MODE (original behavior, unchanged) ===
		self.gravity = 1;
		self.aura = 0;

		//Remove everything he's carrying	
		self.job = 0;
		
		// This is the appropiate place to: (after clearing job due to armytimer stuff weirdness)
		CleanUpEverything(#FALSE);

		ResetStripedAndGiven(self);

		self.is_malfunctioning = 0;
		self.tf_items = 0;
		self.cutf_items = 0;
		self.cutf2_items = 0;
		self.tf_items_flags = 0;
		self.items = 0;
		self.ammo_rockets = 0;
		self.ammo_nails = 0;
		self.ammo_shells = 0;
		self.ammo_cells = 0;
		self.maxammo_rockets = 10; //Give em a minimal carrying capacity
		self.maxammo_nails = 10;
		self.maxammo_shells = 10;
		self.maxammo_cells = 10;
		self.maxammo_medikit = 0;
		self.maxammo_detpack = 0;
		self.ammo_c4det = 0;
		
		self.demon_one = world; //SB - this tells us who our demon is for easy reference
		self.demon_two = world; //- OfN-  Used for hacker job, target building and for timer (% on sbar)	self.demon_three = world;

		self.demon_blood = 0;

		self.all_active = 0; // OfN Number of mines set by the player

		self.no_grenades_1 = 0;
		self.no_grenades_2 = 0;
		self.tp_grenades_1 = 0;
		self.tp_grenades_2 = 0;

		self.armor_allowed = 0.3; //Red yellow or green
		self.armorclass = 0; //Red yellow or green
		self.armorvalue = 0; //200 etc
		self.maxarmor = 0;	//200 etc
		self.weapon = 0; // #WEAP_HOOK & #WEAP_SHOTGUN etc
		self.current_weapon = 0; // No current weapon
		
		if ((allow_hook) && (no_grapple != 1)) //If map allows it...
			self.weapons_carried = #WEAP_HOOK; // Start with grapple
		else
			self.weapons_carried = 0; // Or remove everything

		self.weaponmodel = ""; //Remove the model of a weapon in front

		self.solid = #SOLID_NOT;
		self.movetype = #MOVETYPE_NONE;
		self.takedamage = #DAMAGE_NO;

	//Ready to buy
		self.maxspeed = 0; //Can't move while buying
		self.max_health = 50;
		self.health = 50;
	}

	GiveFreeStuff(self);

#define PRICE_PER_FRAG 100
#define MAX_FRAGS_TO_SELL 50
//Calculate starting money
//This means the most someone can get is 50*100 = $5000
	if (self.done_custom & #CUSTOM_SELLING)
	{
		if (self.real_frags >= #MAX_FRAGS_TO_SELL)
			sell_no = #MAX_FRAGS_TO_SELL;
		else if (self.real_frags > 0)
			sell_no = self.real_frags;
		else {
			sell_no = 0;
			self.done_custom = self.done_custom - (self.done_custom & #CUSTOM_SELLING);
		}

		self.real_frags = self.real_frags - sell_no;
		self.frags = self.real_frags; //TODO: Make this work with TEAMFRAGS on
		// CUSTOM_SELLING forces do_preserve=0 above, so this is always wipe-mode behavior.
		self.money = custom_money + sell_no * #PRICE_PER_FRAG;
	}
	else
	{
		// STAL BACKPORT: in preserve mode, keep current money; in wipe mode, reset to custom_money.
		if (!do_preserve)
			self.money = custom_money;
	}

	// STAL BACKPORT: only reset custom_speed in wipe mode; preserve mode keeps it.
	if (!do_preserve)
		self.custom_speed = 250; //HWGUY Speed

	//Overrides the menu handler to always display my menu
	//Hack alert! This preserves the selling flag. :p
	// STAL: also preserve CUSTOM_MODIFY here so DropFromCustomClassGen
	// can suppress bonus_health for modify-originated builds. The flag is
	// consumed when DropFromCustomClassGen overwrites done_custom = CUSTOM_FINISHED.
	if (self.done_custom & #CUSTOM_SELLING)
		self.done_custom = #CUSTOM_BUILDING | #CUSTOM_SELLING; 
	else if (self.done_custom & #CUSTOM_MODIFY)
		self.done_custom = #CUSTOM_BUILDING | #CUSTOM_MODIFY;
	else
		self.done_custom = #CUSTOM_BUILDING; 
	
	  self.current_menu = #MENU_SNIPER_WEAPON;
	  Menu_SniperWeapon();
};

void(vector org) spawn_tfog;

void() DropFromCustomClassGen =
{
	// OfN
	self.is_killed = #FALSE;
    
	// STAL BACKPORT: capture the CUSTOM_MODIFY flag before we overwrite
	// done_custom on the next line. If this build originated from `modify`,
	// the leftover money is a partial refund of stock equipment cost, not
	// unspent budget -- so we suppress the bonus_health conversion below.
	local float was_modify;
	was_modify = self.done_custom & #CUSTOM_MODIFY;
    
	// STAL DEBUG: dropfrom-entry state
/* 	bprint(#PRINT_HIGH, "DEBUG dropfrom-entry: was_modify=");
	bprint(#PRINT_HIGH, ftos(was_modify));
	bprint(#PRINT_HIGH, " done_custom=");
	bprint(#PRINT_HIGH, ftos(self.done_custom));
	bprint(#PRINT_HIGH, " max_health=");
	bprint(#PRINT_HIGH, ftos(self.max_health));
	bprint(#PRINT_HIGH, " maxarmor=");
	bprint(#PRINT_HIGH, ftos(self.maxarmor));
	bprint(#PRINT_HIGH, " money=");
	bprint(#PRINT_HIGH, ftos(self.money));
	bprint(#PRINT_HIGH, "\n"); */

	self.done_custom = #CUSTOM_FINISHED;
	self.maxspeed = self.custom_speed;
	self.gravity = 1;

	if (self.cutf_items & #CUTF_TOSSABLEDET)
		self.maxammo_detpack = 1;

	//Make sure they have at least one axe-like weapon
	if (!(self.weapons_carried & (#WEAP_MEDIKIT | #WEAP_SPANNER)) || (self.cutf_items & #CUTF_KNIFE))
		self.weapons_carried = self.weapons_carried | #WEAP_AXE;

	//CH if you bought Guerilla, you get 20 rockets :)
	if (self.job & #JOB_GUERILLA)
		self.maxammo_rockets = self.maxammo_rockets + 20;

	//OfN if we got the holo we get extra cells ammo space
	if (self.cutf_items & #CUTF_HOLO)
		self.maxammo_cells = self.maxammo_cells + 40;

	//If they bought weapons, remove their basic ammo allotment
	if (self.maxammo_rockets > 10)
		self.maxammo_rockets = self.maxammo_rockets - 10;
	  if (self.maxammo_nails > 10)
		self.maxammo_nails = self.maxammo_nails - 10;
	  if (self.maxammo_shells > 10)
		self.maxammo_shells = self.maxammo_shells - 10;
	  if (self.maxammo_cells > 10)
		self.maxammo_cells = self.maxammo_cells - 10;

	//WK 4/27/7 $0 armor is now 50/50 green, since 0/50 is a completely pointless option
	if (self.maxarmor == 0) {
		self.armor_allowed = 0.3;
		self.armorvalue = 25;
		self.maxarmor = 50;
	}

	//WK 5/15/7 If they have money left over, put it into health.
	// STAL BACKPORT: suppress bonus_health for modify-originated builds.
	// Stock-class equipment is partially refunded as leftover money during
	// the snap; converting that leftover to HP would inflate health beyond
	// what the player explicitly bought.
	if (self.money > 0)
	if (!was_modify) {
		local float bonus_health;
		if (self.money < 100) bonus_health = 0;
		else if (self.money <= 200) bonus_health = 5;
		else if (self.money <= 300) bonus_health = 10;
		else if (self.money <= 500) bonus_health = 15;
		else if (self.money <= 800) bonus_health = 20;
		else if (self.money <= 1200) bonus_health = 25;
		else if (self.money <= 1600) bonus_health = 30;
		else if (self.money <= 2000) bonus_health = 35;
		else if (self.money <= 2400) bonus_health = 40;
		else if (self.money <  3000) bonus_health = 45;
		else bonus_health = 50;

		self.max_health = self.max_health + bonus_health;
	}

	//Increase their supply if they bought a backpack or bandolier
	if (self.tf_items & #NIT_AMMO_BACKPACK) {
		self.maxammo_rockets = self.maxammo_rockets + 30;
		self.maxammo_nails	 = self.maxammo_nails	+ 100;
		self.maxammo_shells  = self.maxammo_shells	+ 100;
		if (self.weapons_carried & #WEAP_SPANNER)
			self.maxammo_cells	 = self.maxammo_cells	+ 170;
		else
			self.maxammo_cells	 = self.maxammo_cells	+ 50;
		if (self.maxammo_medikit > 0) //Only increase their medical supplies when...
			self.maxammo_medikit = self.maxammo_medikit + 70;
		if (self.maxammo_detpack > 0)
			self.maxammo_detpack = self.maxammo_detpack + 0.5;
	}
	if (self.tf_items & #NIT_AMMO_BANDOLIER) {
		self.maxammo_rockets = self.maxammo_rockets + 10;
		self.maxammo_nails	 = self.maxammo_nails	+ 50;
		self.maxammo_shells  = self.maxammo_shells	+ 50;
		self.maxammo_cells	 = self.maxammo_cells	+ 30;
		if (self.maxammo_medikit > 0)
			self.maxammo_medikit = self.maxammo_medikit + 50;
		if (self.maxammo_detpack > 1) //Only give extra det if they bought both
			self.maxammo_detpack = 2;
	}

	//Clean up detpack fraction
	if (self.maxammo_detpack > 1 && self.maxammo_detpack < 2) 
		self.maxammo_detpack = 1;

	if (self.cutf_items & #CUTF_SENSOR) // SB
		self.maxammo_cells = self.maxammo_cells + 70;
	if (self.cutf_items & #CUTF_DISPENSER) // SB
		self.maxammo_cells = self.maxammo_cells + 100;
	if (self.cutf_items & #CUTF_FIELDGEN) // SB
		self.maxammo_cells = self.maxammo_cells + 140;

	//- OfN
	if (self.weapons_carried & #WEAP_LASERCANNON) self.maxammo_cells = self.maxammo_cells + 70;
	if (self.weapons_carried & #WEAP_SNG) self.maxammo_nails = self.maxammo_nails + 70;
	if (self.weapons_carried & #WEAP_AIRF) self.maxammo_cells = self.maxammo_cells + 60;

	//Now cap the max ammo
	if (self.maxammo_rockets > 100)
		self.maxammo_rockets = 100;
	  if (self.maxammo_nails > 350)
		self.maxammo_nails = 350;
	  if (self.maxammo_shells > 300)
		self.maxammo_shells = 300;
	  if (self.maxammo_cells > #MAXAMMO_CELLS || self.weapons_carried & #WEAP_SPANNER) //WK 2-2-09 Aw, hell, just give engineers max cells already... =)
		self.maxammo_cells = #MAXAMMO_CELLS;

/* WK 1/7/7 We don't need all this complication
	  //- ofn
	  if (self.tf_items & #NIT_AMMO_BANDOLIER && self.tf_items & #NIT_AMMO_BACKPACK)
	  {
		if (self.maxammo_cells > #MAXAMMO_CELLS + 100) 
			self.maxammo_cells = #MAXAMMO_CELLS + 100;
	  }
	  else if (self.tf_items & #NIT_AMMO_BACKPACK)
	  {
		if (self.maxammo_cells > #MAXAMMO_CELLS + 50) // was 360
			self.maxammo_cells = #MAXAMMO_CELLS + 50;
	  } 	 
	  else
	  {
		if (self.maxammo_cells > #MAXAMMO_CELLS) // was 320
			self.maxammo_cells = #MAXAMMO_CELLS;
	  }
*/

	//- OFN HERE FRONTLIN HELI BUG FIX ---//
	local entity spot;
	spot = SelectSpawnPoint ();

	self.observer_list = spot;
	self.origin = spot.origin + '0 0 1';
	self.angles = spot.angles;
	self.fixangle = #TRUE;		// turn this way immediately

	makevectors(self.angles);
	spawn_tfog (self.origin + v_forward*20);
	//------------------------------------//
	
	//Telefrag anyone sitting on top of us
	spawn_tdeath(self.origin,self);
	
	//Remove observer-like mode
	self.takedamage = #DAMAGE_AIM;
	//Prevent bad movetype errors, or something
	if (self.classname != "player") {
		RPrint("BUG BUG BUG BUG BUG BUG BUG BUG BUG\n");
		RPrint("Non-player was in custom class generation!\n");
		return;
	}
	self.movetype = #MOVETYPE_WALK;
	self.flags = #FL_CLIENT | #FL_ONGROUND;
	self.waterlevel = 0;
	self.air_finished = time + 12;
	self.solid = #SOLID_SLIDEBOX;
	self.pausetime = 0;

	//Remove invisibility
	//setmodel (self, "progs/eyes.mdl");
	//setmodel (self, "progs/player.mdl");
	self.modelindex = modelindex_player;

	// Stock him up
	// Display the Player's Class
	TeamFortress_PrintJobName(self,self.job);
	// Set the weapons and ammo for the player based on class
	TeamFortress_SetEquipment();
	// Set the health for the player based on class
	TeamFortress_SetHealth();
	// Set the speed for the player based on class
	TeamFortress_SetSpeed(self);
	// Set the skin for the player based on class
	TeamFortress_SetSkin(self);
	stuffcmd(self, "v_idlescale 0\n");
	stuffcmd(self, "v_cshift 0 0 0 0\n");
	stuffcmd(self, "bf\n");

	ResetMenu();		
	self.impulse = 0;

	//Make them invincible if they bought respawn protection
	if (self.tf_items & #NIT_RESPAWN_GUARD) {
		self.items = self.items + #IT_INVULNERABILITY;
		self.invincible_time = 1;
		self.invincible_finished = time + #RESPAWN_GUARD_TIME;
		if (self.custom_speed > 300)
			self.invincible_finished = self.invincible_finished - 1;			
		if (self.custom_speed > 400)
			self.invincible_finished = self.invincible_finished - 1;			
	}

	//Come again!
	sprint(self,#PRINT_HIGH,"Type ¢custom¢ at the console to build a new class.\n");
	return;
};

void() PrintMoney =
{
	CuTFMenuSound(#MENUSOUND_BUY);
	
	if (pay_msgs != 1)
		return;

	local string as;
	sprint(self,#PRINT_HIGH,"You have ");
	as = ftos(self.money);
	sprint(self,#PRINT_HIGH,as);
	sprint(self,#PRINT_HIGH," dollars left.\n");
	return;
};


void(float in) PrintRefund=
{
	CuTFMenuSound(#MENUSOUND_SELL);

	local string as;

	if (pay_msgs == 1)
	{
		sprint(self,#PRINT_HIGH,"You sell it back for ");
		as = ftos(in);
		sprint(self,#PRINT_HIGH,as);
		sprint(self,#PRINT_HIGH," dollars.\n");
	}

	self.money = self.money + in; //Give em a refund

	if (pay_msgs == 1)
	{
		sprint(self,#PRINT_HIGH,"You now have ");
		as = ftos(self.money);
		sprint(self,#PRINT_HIGH,as);
		sprint(self,#PRINT_HIGH," dollars available.\n");
	}

	return;
};

void(float in) PrintNotEnoughMoney =
{
	CuTFMenuSound(#MENUSOUND_WRONG);

	self.tfstate = self.tfstate | #TFSTATE_NOTENOUGHMONEY;

	if (pay_msgs != 1)
	{
		sprint(self,#PRINT_HIGH,"Not enough money!\n");
		return;
	}

	local string as;
	
	sprint(self,#PRINT_HIGH,"Sorry, that costs ");
	as = ftos(in);
	sprint(self,#PRINT_HIGH,as);
	sprint(self,#PRINT_HIGH," dollars.\n");

	sprint(self,#PRINT_HIGH,"You only have ");
	as = ftos(self.money);
	sprint(self,#PRINT_HIGH,as);
	sprint(self,#PRINT_HIGH," dollars left.\n");
	return;
};

//Functions for determining ammo carrying capacity
float (float item) countshells =
{
	if (item == #WEAP_SHOTGUN) return 25;
	if (item == #WEAP_SPANNER) return 40;
	if (item == #WEAP_SUPER_SHOTGUN) return 50;
	if (item == #WEAP_ASSAULT_CANNON) return 100;
	return 0;
};
float (float item) countnails =
{
	if (item == #WEAP_MAUSER) return 30;
	if (item == #WEAP_TRANQ) return 30;
	if (item == #WEAP_RAILGUN) return 50;
	if (item == #WEAP_NAILGUN) return 100;
	if (item == #WEAP_LIGHT_ASSAULT) return 150;
	return 0;
};
float (float item) countrockets =
{
	if (item == #WEAP_SPANNER) return 30;
	if (item == #WEAP_ROCKET_LAUNCHER) return 30;
	if (item == #WEAP_GRENADE_LAUNCHER) return 50;
	return 0;
};
float (float item) countcells =
{
	if (item == #WEAP_ASSAULT_CANNON) return 50;
	if (item == #WEAP_DAEDALUS) return 100;
	if (item == #WEAP_LIGHTNING) return 100;
	if (item == #WEAP_SPANNER) return 150;
	return 0;
};

void(float cost, float item) BuyWeapon =
{
	if (item == 0) //Make sure we don't buy a null weapon
		return;
	
	if (self.weapons_carried & item) //We are selling
	{
		//WK 6/1/7 We No Longer Sync Rocket Launcher with laser guided or clusters
		self.maxammo_shells = self.maxammo_shells - countshells(item);
		self.maxammo_nails = self.maxammo_nails - countnails(item);
		self.maxammo_rockets = self.maxammo_rockets - countrockets(item);
		self.maxammo_cells = self.maxammo_cells - countcells(item);
		PrintRefund(cost);
		self.weapons_carried = self.weapons_carried - item;
		return;
	}
	if (cost > self.money)
	{
		PrintNotEnoughMoney(cost);
		return;
	}
	//Add to max ammo
	self.maxammo_shells = self.maxammo_shells + countshells(item);
	self.maxammo_nails = self.maxammo_nails + countnails(item);
	self.maxammo_rockets = self.maxammo_rockets + countrockets(item);
	self.maxammo_cells = self.maxammo_cells + countcells(item);

	self.weapons_carried = self.weapons_carried | item;
	self.money = self.money - cost;
	PrintMoney();
};


void(float cost, float item) BuyCuTF =
{
	if (item == 0) //Make sure we don't buy a null weapon
		return;
	
	/* WK 6/1/7 Replaced with new HelpString func
	if (item == #CUTF_HOLO && !(self.cutf_items & #CUTF_HOLO)) {
		if (!(cost > self.money))
			sprint(self,#PRINT_HIGH,"Use the 'holo' command to activate/deactivate the holograph\n");
	}
	*/

	if (self.cutf_items & item) //We are selling
	{
		if (item & #CUTF_SENTRYGUN) {
			self.maxammo_shells = self.maxammo_shells - 130;
			self.maxammo_cells	= self.maxammo_cells  - 130;
		}
		PrintRefund(cost);
		self.cutf_items = self.cutf_items - item;
		return;
	}
	if (cost > self.money)
	{
		PrintNotEnoughMoney(cost);
		return;
	}
	//Add to max ammo if sentrygun purchase
	if (item & #CUTF_SENTRYGUN) {
		self.maxammo_shells = self.maxammo_shells + 130;
		self.maxammo_cells	= self.maxammo_cells  + 130;
	}

	self.cutf_items = self.cutf_items | item;
	self.money = self.money - cost;
	PrintMoney();
};

// WK 6/1/7 Add in support for all the new CUTF2 items
void(float cost, float item) BuyCuTF2 =
{
	if (item == 0) //Make sure we don't buy a null weapon
		return;
	
	if (self.cutf2_items & item) //We are selling
	{
		//Remove from max ammo if Shinigami sale
		if (item & #CUTF2_SHINIGAMI) self.maxammo_shells = self.maxammo_shells - 75;
		PrintRefund(cost);
		self.cutf2_items = self.cutf2_items - item;
		return;
	}
	if (cost > self.money)
	{
		PrintNotEnoughMoney(cost);
		return;
	}
	//Add to max ammo if Shinigami purchase
	if (item & #CUTF2_SHINIGAMI) self.maxammo_shells = self.maxammo_shells + 75;

	self.cutf2_items = self.cutf2_items | item;
	self.money = self.money - cost;
	PrintMoney();
};

//CH gives ammo for items
void(float item) Apply_Item_Ammo =
{
	local float cellsfoo,rocketsfoo;
	cellsfoo = rocketsfoo = 0;

	if (item == #NIT_TESLA)
		cellsfoo = 150;
	if (item == #NIT_SECURITY_CAMERA)
		cellsfoo = 60;
	if (item == #NIT_TELEPORTER)
		cellsfoo = 100;

	if (item == #NIT_RL_LASER_SIGHT)
		rocketsfoo = 10;
	if (item == #NIT_CLUSTER_ROCKETS)
		rocketsfoo = 20;

	if (self.tf_items & item) { //we selling
		self.maxammo_cells = self.maxammo_cells - cellsfoo;
		self.maxammo_rockets = self.maxammo_rockets - rocketsfoo;
	}
	else {
		self.maxammo_cells = self.maxammo_cells + cellsfoo;
		self.maxammo_rockets = self.maxammo_rockets + rocketsfoo;
	}
};
void(float cost, float item) BuyItem =
{
	if (item == 0) //Make sure we don't buy a null item
		return;

	Apply_Item_Ammo(item); //CH

	if (self.tf_items & item) //We are selling
	{
		if (item == #NIT_HOVER_BOOTS && self.tf_items & #NIT_HOVER_BOOTS_UPGRADE) {
			self.money = self.money + #COST_BOOTUPGRADE; //sync with buying of upgrade
			item = item + #NIT_HOVER_BOOTS_UPGRADE;
		}

		PrintRefund(cost);
		self.tf_items = self.tf_items - item;
		return;
	}
	//Special rules
	if (item == #NIT_AUTOSCANNER && !(self.tf_items & #NIT_SCANNER)) {
		sprint(self,#PRINT_HIGH,"Sorry, you have to buy the scanner first!\n");
		CuTFMenuSound(#MENUSOUND_WRONG);
		return;
	}

	if (item == #NIT_HOVER_BOOTS_UPGRADE && !(self.tf_items & #NIT_HOVER_BOOTS)) {
		sprint(self,#PRINT_HIGH,"Sorry, you have to buy the hover boots first!\n");
		CuTFMenuSound(#MENUSOUND_WRONG);
		return;
	}
	if (cost > self.money)
	{
		PrintNotEnoughMoney(cost);
		return;
	}

	self.tf_items = self.tf_items | item;
	self.money = self.money - cost;
	PrintMoney();
};

void(float cost, float type) BuyJob =
{
	if (type == 0) //Make sure we don't buy a null grenade
		return;
	
	if (type == self.job) //We are selling
	{
		PrintRefund(cost);
		self.job = 0;
		return;
	}
	if (cost > self.money)
	{
		PrintNotEnoughMoney(cost);
		return;
	}
	if (self.job) { //Make sure we haven't bought another kind already
		sprint(self,#PRINT_HIGH,"You already have a job. Leave your other one first.\n");
		CuTFMenuSound(#MENUSOUND_WRONG);
		return;
	}
	//Special rules for buying jobs
	if (type == #JOB_WARLOCK && !(self.cutf_items & #CUTF_KNIFE)) {
		sprint(self,#PRINT_HIGH,"Every Warlock needs a good bloody knife. Buy one.\n");
		CuTFMenuSound(#MENUSOUND_WRONG);
		return;
	}
		
	//Ok we buy it
	self.job = type;
	self.money = self.money - cost;
	PrintMoney();
};

void (float cost1, float cost2) BuyExtra =
{
	local float allcost;
	allcost = 0;
	
	if (self.job & #JOB_EXTRA1) // we have extra1
	{
		if (self.money < cost2) // not enough money for extra2, sell back job and extra1 then..
		{
			if (self.job & #JOB_WARLOCK)
			{
				allcost = #COST_WARLOCK + cost1;
			}
			else if (self.job & #JOB_ARMY)
			{
				allcost = #COST_ARMY + cost1;
			}
			else if (self.job & #JOB_GUERILLA)
			{
				allcost = #COST_GUERILLA + cost1;
			}
			else if (self.job & #JOB_PSION)
			{
				allcost = #COST_PSION + cost1;
			}
			else if (self.job & #JOB_THIEF)
			{
				allcost = #COST_THIEF + cost1;
			}

			self.job = 0;
		PrintNotEnoughMoney(cost1);
			PrintRefund(allcost);
			return;
		}
		else // ok, buy second extra
		{
			self.job = self.job - (self.job & #JOB_EXTRA1);
			self.job = self.job | #JOB_EXTRA2;
			
			// decrease our money
			self.money = self.money - cost2;	
		}
	}
	else if (self.job & #JOB_EXTRA2) // we have extra2, so sell back everything..
	{
		if (self.job & #JOB_WARLOCK)
		{
			allcost = (cost1+cost2)+#COST_WARLOCK;
		}
		else if (self.job & #JOB_ARMY)
		{
			allcost = (cost1+cost2)+#COST_ARMY;
		}
		else if (self.job & #JOB_GUERILLA)
		{
			allcost = (cost1+cost2)+#COST_GUERILLA;
		}
		else if (self.job & #JOB_PSION)
		{
			allcost = (cost1+cost2)+#COST_PSION;
		}
		else if (self.job & #JOB_THIEF)
		{
			allcost = (cost1+cost2)+#COST_THIEF;
		}
			
		self.job = 0;
		PrintRefund(allcost);
		return;
	}
	else // we dont have any extra
	{
		if (self.money < cost1) // not enough money for 1st extra, so sell back job
		{
			if (self.job & #JOB_WARLOCK)
			{
				allcost = #COST_WARLOCK;
			}
			else if (self.job & #JOB_ARMY)
			{
				allcost = #COST_ARMY;
			}
			else if (self.job & #JOB_GUERILLA)
			{
				allcost = #COST_GUERILLA;
			}
			else if (self.job & #JOB_PSION)
			{
				allcost = #COST_PSION;
			}
			else if (self.job & #JOB_THIEF)
			{
				allcost = #COST_THIEF;
			}

		self.job = 0;
		PrintNotEnoughMoney(cost1);
		PrintRefund(allcost);
			return;
		}
		else // ok, buy 1st extra
		{
			self.job = self.job | #JOB_EXTRA1;

			// decrease our money
			self.money = self.money - cost1;
		}
	}

	// Print money
	PrintMoney();
};

//WK 6/1/7 Cut out a lot of the commented out stuff here.
void (float cost, float type) BuyGren =
{
	//local string talk;
	///local float level; // This is the level of legs we have.
	
	if (type == 0) // if type is 0 we are buying the NULL GRENADE(tm)
	{
		sprint(self, #PRINT_HIGH, "Congratulations. You have just attempted to buy a null grenade.\n");
		RPrint("WARNING: Attempted purchase of NULL GRENADE. BUG BUG BUG BUG BUG BUG BUG\n");
		return;
	}

	// Check whether we're allowing gren purchase.
	if (!self.tp_grenades_1 && cost <= self.money) // if we don't have gren1s, make it a gren1
	{
		self.tp_grenades_1 = type;
	}
	else if (!self.tp_grenades_2 && cost <= self.money) // We already have gren1s, can we buy gren2s?
	{
		self.tp_grenades_2 = type;
	}
	else	// We have both gren1s and gren2s so now we need to try to sell some
	{		// If our type matches gren1 AND gren2s we want to sell both
		if (self.tp_grenades_1 == type && self.tp_grenades_2 == type)
		{
			PrintRefund(cost * 2);
			self.tp_grenades_1 = 0;
			self.tp_grenades_2 = 0;
		}
		else if (self.tp_grenades_1 == type) // otherwise if our gren1s are the type
		{
			PrintRefund(cost);
			self.tp_grenades_1 = 0;
		}
		else if (self.tp_grenades_2 == type) // otherwise if we have gren2s as the type..
		{
			PrintRefund(cost);
			self.tp_grenades_2 = 0;
		}
		else if (cost <= self.money)
		{
			CuTFMenuSound(#MENUSOUND_WRONG);
			sprint(self,#PRINT_HIGH,"You already have a full set of grenades. Sell some back first.\n");
		}
		else
			PrintNotEnoughMoney(cost);
		
		return;
	}
	self.money = self.money - cost;
	PrintMoney();
};
/*

void(float cost, float type) BuyGren1 =
{
	if (type == 0) //Make sure we don't buy a null grenade
		return;
	
	if (type == self.tp_grenades_1) //We are selling
	{
		PrintRefund(cost);
		self.tp_grenades_1 = 0;
		return;
	}
	if (cost > self.money)
	{
		PrintNotEnoughMoney(cost);
		return;
	}
	if (self.tp_grenades_1) { //Make sure we haven't bought another kind already
		sprint(self,#PRINT_HIGH,"You already have grenades. Sell back the ones you bought first.\n");
		return;
	}
	//Ok we buy it
	self.tp_grenades_1 = type;
	self.money = self.money - cost;
	PrintMoney();
};

void(float cost, float type) BuyGren2 =
{
	if (type == 0) //Make sure we don't buy a null grenade
		return;
	
	if (type == self.tp_grenades_2) //We are selling
	{
		PrintRefund(cost);
		self.tp_grenades_2 = 0;
		return;
	}
	if (cost > self.money)
	{
		PrintNotEnoughMoney(cost);
		return;
	}
	if (self.tp_grenades_2) { //Make sure we haven't bought another kind already
		sprint(self,#PRINT_HIGH,"You already have grenades. Sell back the ones you bought first.\n");
		return;
	}

	//Ok we buy it
	self.tp_grenades_2 = type;
	self.money = self.money - cost;
	PrintMoney();
};
*/

//Functions for our new grenades
//WK6-27-7 Frag spikes now reflect off walls, ala Hipnotic Laser Cannon Shots
#define FRAG_VELOCITY 1000
void() fragspike_touch =
{
	local vector spot1,spot2;
	local vector oldvel;

	//if (pointcontents(self.origin) == #CONTENT_SKY)
	if (pointcontents(self.origin) != #CONTENT_EMPTY)
	{
		dremove(self);
		return;
	}

	// hit something that bleeds
	if (other.takedamage && other.last_frag_gren_time < time)
	{
		deathmsg = #DMSG_GREN_FRAG;

		TF_T_Damage (other, self, self.real_owner, 150, #TF_TD_NOTTEAM, #TF_TD_NAIL);
		other.last_frag_gren_time = time + 1;
		dremove(self);
	}
	else
	{
		//We bounce off world since we are fragments
		if (self.heat > 0) {
/*
			local string temps;
			bprint(#PRINT_HIGH,"Bounce ");
			temps = ftos(self.heat);
			bprint(#PRINT_HIGH,temps);
			bprint(#PRINT_HIGH,": ");
			temps = vtos(self.neworigin);
			bprint(#PRINT_HIGH,temps);
			bprint(#PRINT_HIGH,", TPN: ");
*/
			self.heat = self.heat - 1;
			oldvel = normalize(self.neworigin);
			spot1 = self.origin - (16*oldvel);
			spot2 = self.origin + (16*oldvel);
			traceline (spot1, spot2, #TL_BSP_ONLY, self);  // see through other monsters
//			temps = vtos(trace_plane_normal);
//			bprint(#PRINT_HIGH,temps);
//			bprint(#PRINT_HIGH,"\n");
			if (vlen(trace_plane_normal) < 1) { //Didn't find any wall, repeat with wider search
				spot1 = self.origin - (300*oldvel);
				spot2 = self.origin + (300*oldvel);
				traceline (spot1, spot2, #TL_BSP_ONLY, self);  // see through other monsters
				//bprint(#PRINT_HIGH,"Wider Search: ");
				//temps = vtos(trace_plane_normal);
				//bprint(#PRINT_HIGH,temps);
				//bprint(#PRINT_HIGH,"\n");
			}
			if (vlen(trace_plane_normal) < 1) { //Still didn't find any wall, so simply reflect
				self.origin_z = self.origin_z + 20; //Lift up off the ground
				self.velocity = -1*oldvel;
			} else { //Reflect off a wall
				//self.origin = trace_endpos;
				self.velocity = normalize(oldvel+(2*trace_plane_normal));
			}
			if (self.flags & #FL_ONGROUND) self.flags = self.flags - #FL_ONGROUND;
			self.velocity = #FRAG_VELOCITY * self.velocity;
			self.neworigin = self.velocity; //WK Note: Save our current velocity
			//self.nextthink = time + 0.5+random();
		}
		else {
			if (other.classname == "force_field") //- OfN - Makes field explosion b4 removing it
				FieldEvent(other,self.origin,self);
			else
			{
				WriteByte (#MSG_BROADCAST, #SVC_TEMPENTITY);
				WriteByte (#MSG_BROADCAST, #TE_SUPERSPIKE);
				WriteCoord (#MSG_BROADCAST, self.origin_x);
				WriteCoord (#MSG_BROADCAST, self.origin_y);
				WriteCoord (#MSG_BROADCAST, self.origin_z);
				#ifdef QUAKE_WORLD
					multicast (self.origin, #MULTICAST_PHS);
				#endif
			}
			dremove(self);
		}
	}
};
void() FragSpikeThink =
{
	//We service the fragspike every 0.1 seconds, but only readjust it's vector after attack_finished has elapsed
	//Essentially, we're forcing it to the velocity it's supposed to have every 0.1 seconds
	if (time < self.attack_finished) {
		if (self.flags & #FL_ONGROUND) self.flags = self.flags - #FL_ONGROUND;
		self.velocity = self.neworigin;
		self.angles = vectoangles(self.velocity);
		self.nextthink = time + 0.1;
		return;
	}

	if (self.heat > 0) {
		self.heat = self.heat - 2; //WK 8/4/7 Was 1. Will stop those long duration fragments

		self.angles_y = random() * 360;
		self.angles_x = 0;
		self.angles_z = 0;
		makevectors(self.angles);
		//if (self.velocity = '0 0 0')
		self.origin_z = self.origin_z + 10;

		self.velocity = v_forward * #FRAG_VELOCITY;
		self.velocity_z = (0.5-random()) * 10;
		self.neworigin = self.velocity; //Save our current velocity

		self.attack_finished = time + 0.3 + random(); //Holds time to redo speed //WK 8/4/7 0.3 was 1
		self.nextthink = time + 0.1;
	}
	else {
		WriteByte (#MSG_BROADCAST, #SVC_TEMPENTITY);
		WriteByte (#MSG_BROADCAST, #TE_SUPERSPIKE);
		WriteCoord (#MSG_BROADCAST, self.origin_x);
		WriteCoord (#MSG_BROADCAST, self.origin_y);
		WriteCoord (#MSG_BROADCAST, self.origin_z);
	#ifdef QUAKE_WORLD
		multicast (self.origin, #MULTICAST_PHS);
	#endif						
		dremove(self);
	}
};

void() FragGrenadeTouch =
{
	if (other == self.owner)
		return; 	// don't explode on owner

	// Thrown grenades don't detonate when hitting an enemy

	sound (self, #CHAN_WEAPON, "weapons/bounce.wav", 1, #ATTN_NORM);	// bounce sound
	if (self.velocity == '0 0 0')
		self.avelocity = '0 0 0';
};

void() FragGrenadeExplode =
{
	local float shraps;
	local entity newmis;

//Small explosive radius
	deathmsg = #DMSG_GREN_HAND;
	T_RadiusDamage (self, self.owner, 80, world);

	WriteByte (#MSG_BROADCAST, #SVC_TEMPENTITY);
	WriteByte (#MSG_BROADCAST, #TE_EXPLOSION);
	WriteCoord (#MSG_BROADCAST, self.origin_x);
	WriteCoord (#MSG_BROADCAST, self.origin_y);
	WriteCoord (#MSG_BROADCAST, self.origin_z);
#ifdef QUAKE_WORLD
	multicast (self.origin, #MULTICAST_PHS);
#endif

	//shraps = rint(6 * random()) + 6; //Pieces of shrapmetal;
	shraps = 12; //WK 6-27-7 We can handle the lag now
	//shraps = 1; //WK DELETETHIS
	while (shraps > 0) {
		self.angles_y = random() * 360;
		self.angles_x = 0;
		self.angles_z = 0;
		makevectors(self.angles);

		deathmsg = #DMSG_GREN_NAIL;
		newmis = spawn ();
		//WK Make shraps hit owner newmis.owner = self.owner;
		newmis.real_owner = self.owner;
		newmis.movetype = #MOVETYPE_FLYMISSILE;
		newmis.solid = #SOLID_BBOX;

		newmis.angles = '0 0 0';
		newmis.classname = "spike";
		newmis.think = FragSpikeThink;
		newmis.nextthink = time + 0.1;
		newmis.attack_finished = time + 0.3 + random(); //Holds time to redo speed //WK 8/4/7 0.3 was 1
		setmodel (newmis, "progs/spike.mdl");
//		setsize (newmis, #VEC_ORIGIN, #VEC_ORIGIN); 	
		setsize (newmis, '0 0 0', '0 0 0');
		setorigin (newmis, self.origin);

		//Start it over the ground
		newmis.origin_z = newmis.origin_z + 10;

		newmis.velocity = v_forward * #FRAG_VELOCITY;
		if (random() < 0.5) 
			newmis.velocity_z = 10;
		else
			newmis.velocity_z = (0.5 - random()) * 100;
		newmis.neworigin = newmis.velocity; //Save our current velocity
		newmis.avelocity = '100 100 100';
		newmis.touch = fragspike_touch;
		newmis.weapon = #DMSG_GREN_NAIL;

		//Make it bounce 8 times / last for 8 seconds
		newmis.heat = 8; //WK 8/4/7 10
		shraps = shraps - 1;
	}
#ifdef QUAKE_WORLD
	WriteByte (#MSG_BROADCAST, #SVC_TEMPENTITY);
	WriteByte (#MSG_BROADCAST, #TE_EXPLOSION);
	WriteCoord (#MSG_BROADCAST, self.origin_x);
	WriteCoord (#MSG_BROADCAST, self.origin_y);
	WriteCoord (#MSG_BROADCAST, self.origin_z);
	multicast (self.origin, #MULTICAST_PHS);
	dremove(self);
#else
	BecomeExplosion();
#endif

};

void() KracGrenadeTouch =
{
	//WK Have it detonate on impact
	if (other == self.owner)
		return; 	// don't explode on owner

	sound (self, #CHAN_WEAPON, "weapons/bounce.wav", 1, #ATTN_NORM);	// bounce sound
	
	KracGrenadeExplode();
};

void() KracGrenadeExplode =
{
	local entity te,newmis;
	local entity oldself;
	local float damage;
	te = findradius(self.origin, 150);
	while (te)
	{	
		if (te != world) {
		//WK 1/7/7 Krac nerf
		//Deals 200, tapers off linearly with radius (min 75)
		damage = 200 - vlen(te.origin - self.origin);
		//WK 6/1/7 Krac fix: it wasn't doing full damage even on direct hits.
		damage = damage + 25; //Hitting a target's lower part can still be some distance away.
		if (damage > 200) damage = 200;
		if (damage < 75) damage = 75;
		if (te.armorclass & #AT_SAVEMELEE) damage = floor(damage / 2);
		// Player?
		if (te.classname == "player" && te.health > 0)
		{
			//WW: Kracs disable detpack
			oldself = self;
			self = te;
			TeamFortress_DetpackStop(#TRUE);
			self = oldself;
	
			te.armorvalue = te.armorvalue - damage;
			if (te.armorvalue < 10) te.armorvalue = 10;

			//Damage is now dealt to cells instead of killing it all at once.
			//Do this before we adjust for armor damage
			te.ammo_cells = te.ammo_cells - damage; 
			if (te.ammo_cells < 0) te.ammo_cells = 0;

			//WK 1/7/7 Fix the "dead thunderbolt" bug when you get kraced.
			//This should force a weapon switch on the next frame.
			if (te.current_weapon == #WEAP_LIGHTNING || te.current_weapon == #WEAP_LASERCANNON ||
				te.current_weapon == #WEAP_DAEDALUS || te.current_weapon == #WEAP_AIRF ||
				te.current_weapon == #WEAP_FLAMETHROWER)
				te.currentammo = te.ammo_cells;

			/* WK 1/7/7 Old damage code:
			//Gel armor makes kracs do less damage
			if (te.armorclass & #AT_SAVEMELEE) {
				if (te.armorvalue > 75)
					te.armorvalue = 75;
			} else {
				if (te.armorvalue > 10)
					te.armorvalue = 10;
			}
			te.ammo_cells = 0; //Kill their metal supply too
			*/
		}
		else if (te.classname == "pipebomb")
			te.nextthink = time + 0.1 + random() / 4; //WK 1/7/7 Speed up kracs breaking pipebombs, since a 1.1 second delay is too long
		else if (te.classname == "grenade" && te.netname == "land_mine")
		{
			te.think = GuerillaExplode;
			te.nextthink = time + 0.1;
		}
		else if (te.classname == "building_sentrygun")
			TF_T_Damage(te, self, self.owner, damage, 0, 0); //WK 1/7/7 Teslas and sentries take less now
		else if (te.classname == "building_tesla")
			TF_T_Damage(te, self, self.owner, damage, 0, 0);
		else if (te.classname == "building_dispenser")
			TF_T_Damage(te, self, self.owner, 500, 0, 0);
		else if (te.classname == "building_camera")
			TF_T_Damage(te, self, self.owner, 400, 0, 0);
		else if (te.classname == "building_teleporter")
			TF_T_Damage(te, self, self.owner, 200, 0, 0);
		else if (te.classname == "building_sensor") //- Often - needed?
			TF_T_Damage(te, self, self.owner, 200, 0, 0);
		else if (te.classname == "building_fieldgen") //- Often - needed?
			TF_T_Damage(te, self, self.owner, 200, 0, 0);
		else if (te.classname == "item_armor1" || te.classname == "item_armor2" || te.classname == "item_armorInv") {
			te.solid = #SOLID_NOT;
			te.model = string_null;
			te.nextthink = time + 45; //WK 20
			te.think = SUB_regen;
			//SUB_UseTargets(); 
		}
		else if (te.classname == "detpack") {
			if (te.owner.netname != self.owner.netname) {
				bprint (#PRINT_MEDIUM, te.owner.netname);
				bprint (#PRINT_MEDIUM, "'s detpack was Kraced by ");
				bprint (#PRINT_MEDIUM, self.owner.netname);
				bprint (#PRINT_MEDIUM, "\n");
			} else {
				sprint (te.owner, #PRINT_MEDIUM, "You Kraced your own detpack!\n");
			}
			// This code handles disarming a detpack
			if (te.weaponmode == 1) // Detpack was being disarmed
			{
				te.enemy.tfstate = te.enemy.tfstate - (te.enemy.tfstate & #TFSTATE_CANT_MOVE);
		#ifdef QUAKE_WORLD
				TeamFortress_SetSpeed(te.enemy);
		#else
				te.enemy.pausetime = time;		
		#endif

				dremove(te.oldenemy);	 // CountDown
				dremove(te.observer_list); //	Disarm timer
			}
			else { //Not being disarmed
				dremove(te.oldenemy);	 // CountDown
			}
			te.think = BecomeExplosion;
			te.nextthink = time + 0.1;
		}
		}
		te = te.chain;
	}

#ifdef QUAKE_WORLD
	WriteByte (#MSG_BROADCAST, #SVC_TEMPENTITY);
	WriteByte (#MSG_BROADCAST, #TE_EXPLOSION);
	WriteCoord (#MSG_BROADCAST, self.origin_x);
	WriteCoord (#MSG_BROADCAST, self.origin_y);
	WriteCoord (#MSG_BROADCAST, self.origin_z);
	multicast (self.origin, #MULTICAST_PHS);
	dremove(self);
#else
	BecomeExplosion();
#endif
};

//WK 5-15-08 Timer to warn and then reteam players who connected most recently
//The Reteamer is only for standard maps like Well not specialty maps like Hunted
//Todo: Give out +10 frags for their trouble
void() ReteamTimer =
{
	local entity candidate,te;
	local float candidate_time, team1count, team2count, wrong_team, result;
	local string foo;

/*
	DebugSprint("Neo:");
	DebugSprintFloat(neo);
	DebugSprint("Number_of_teams:");
	DebugSprintFloat(number_of_teams);
	DebugSprint("Team1maxplayers:");
	DebugSprintFloat(team1maxplayers);
	DebugSprint("Team2maxplayers:");
	DebugSprintFloat(team2maxplayers);
*/
	
	//Disable the Reteamer if this is a special map (like hunted or whatever) or we're in neo mode
	if (!teamplay || neo || number_of_teams != 2 || (team1maxplayers > 0 && team1maxplayers < 32) || (team2maxplayers > 0 && team2maxplayers < 32)) {	
		bprint (#PRINT_MEDIUM, "Reteam Timer Disabled Due to Nonstandard Map\n");
		dremove(self);
		return;
	}

	self.nextthink = time + 30;

	team1count = TeamFortress_TeamGetNoPlayers(1);
	team2count = TeamFortress_TeamGetNoPlayers(2);
	wrong_team = 0;
	if (team1count > team2count + 1) wrong_team = 1;
	if (team2count > team1count + 1) wrong_team = 2;

	if (wrong_team) {
		//Now we find the newest player to connect who is on the wrong team
		candidate = world;
		candidate_time = -1;
		te = find (world, classname, "player");
		while (te)
		{
			if (te.team_no == wrong_team) { //Found someone on wrong team
				if (te.connect_time > candidate_time) {
					candidate = te;
					candidate_time = te.connect_time;
				}
			}
			te = find(te, classname, "player");
		}
		if (candidate != world) {
			self.heat = 1 - self.heat; //First we warn, then we reteam
			if (self.heat) {
				bprint (#PRINT_MEDIUM, "Reteam Timer: ");
				bprint (#PRINT_MEDIUM, candidate.netname);
				bprint (#PRINT_MEDIUM, " will switch teams in 30 seconds!\n");
				BroadcastSound("misc/basekey"); //Play warning sound to everyone
			} else {
				//WK 12-4-08 Don't reteam people who are in the class building menu
				if (candidate.done_custom & #CUSTOM_BUILDING) {
					result = 0;
				} else {
					local entity oself;
					oself = self;
					self = candidate;
					result = TeamFortress_TeamPutPlayerInTeam();
					self = oself;
				}
				if (!result) //Reteaming failed for some reason, so delay
					self.nextthink = time + 60;
				else {
					bprint (#PRINT_MEDIUM, "Reteam Timer: ");
					bprint (#PRINT_MEDIUM, candidate.netname);
					bprint (#PRINT_MEDIUM, " HAS SWITCHED TEAMS!\n");
					BroadcastSound("doors/basetry.wav");
				}
			}
		}
	} else //Teams are balanced, so clear warning flag
		self.heat = 0;
};

//Stops us from lowering the time immunity
void(entity immuner,float timeimmune) makeImmune =
{
	if (immuner == world) return;
	if (immuner.immune_to_chec > timeimmune) return;
	immuner.immune_to_chec = timeimmune;
};

void() BastardTimer =
{
	local entity te;
	local string st;
	te = self.owner;

	//makeImmune(te,time+5);

	if (te.penance_time < time)
	{
		stuffcmd(te, "cl_yawspeed 140;-right;-left\n");
		//stuffcmd(te, "name \"");
		//stuffcmd(te, te.old_netname);
		//stuffcmd(te, "\"\n");

		//Reset their color
		// PZ: We are no longer using stuffcmd() to set team, color, or skin. Players will no longer be able to change these things,
		//     themselves, to keep from having to kick them when they do.
		//stuffcmd(te, "color ");
		st = ftos(TeamFortress_TeamGetColor(te.team_no) - 1);
		//- OfN - Nice colors
		if (nicecolors==1) st =TeamGetNiceColor(te.team_no);
		setinfo(te, "topcolor", st);    // PZ
		setinfo(te, "bottomcolor", st); // PZ
		//stuffcmd(te, st);
		//stuffcmd(te, "\n");

		bprint (#PRINT_MEDIUM, te.netname);
		bprint (#PRINT_MEDIUM, " has his teamkill curse removed\n");

		//Don't let up on them. Two more teamkills and its back into the tarpit for them
		te.ff_count = self.frags - 1.9;
		if (te.ff_count < 0) te.ff_count = 0;
		
		TF_T_Damage(te, world, world, te.health + 300, #TF_TD_IGNOREARMOUR, #TF_TD_OTHER);
		
		remove(self);
		return;
	}

	// PZ NOTE: *sigh* It took me forever to figure out where a teamkiller's color is set to pink.
	if (random() > 0.5) 
		stuffcmd(te, "cl_yawspeed 500;-left;+right;color 8 8\n");
	else
		stuffcmd(te, "cl_yawspeed 500;-right;+left;color 8 8\n"); // <-- was 9 9
	// PZ: Players can no longer change their color, team, or skin manually, via console/script/stuffcmd(). Created setinfo()
	//     for this purpose. This keeps players from accidentally changing these things and getting kicked from the server, probably
	//     usually due to autoexecution of .cfg files by their client.
	setinfo(te, "topcolor", "8");
	setinfo(te, "bottomcolor", "8");
	//te.immune_to_check = time + 5;
	te.ammo_rockets = 0;
	te.ammo_cells = 0;
	te.ammo_nails = 0;
	te.ammo_shells = 0;
	te.ammo_detpack = 0;
	te.ammo_c4det = 0;
	  te.no_grenades_1 = 0;
	  te.no_grenades_2 = 0;
	if (te.health > 50) te.health = 50;
	if (te.armorvalue > 10) te.armorvalue = 10;

	self.nextthink = time + 2;
};

void(entity bastard,float threshold) createBastard =
{
	//if (mapname == "border1" || mapname == "border1r") // dont curse ppl on these maps, thay use a bug
	// done - TODO: Make triggers ignore cursed persons instead..
	//	  return;
	
	local entity te;

	if (bastard == world) return;

	// Neo Mode
	if (neo) if (neoLives == bastard)
	{
		Neo_removeNeo(bastard);
		bprint(#PRINT_HIGH, "\n Îåï Íïäå \n");
		bprint(#PRINT_HIGH, "Kill someone to become Neo!\n");
		bprint(#PRINT_HIGH, "\n");
		BroadcastSound("boss1/sight1.wav");
		Neo_centerPrint();
	}

	if (bastard.penance_time > time) {
		bastard.ff_count = bastard.ff_count - 1; //Dont count it
		bastard.penance_time = time + 60; //Just reset the clock
		makeImmune(bastard,time+65);
		return;
	}

	//---------------------------------------------------------------------------//
	// Why do I not like MegaTF? ------------------------------------------------//
	// Look at http://www.planetfortress.com/history/people/shaka.html ----------//
	if (bastard.ff_count == threshold + 0.1 || bastard.ff_count == threshold + 0.6) {
		//- OfN - lol
		//bprint(#PRINT_HIGH,"ÔÉÍÅ ÔÏ ËÉÃË ÈÉM\n");
		bprint(#PRINT_HIGH,"ok, lets send ");
		bprint(#PRINT_HIGH,bastard.netname);
		bprint(#PRINT_HIGH," to a nice megaTF server...\n");
		stuffcmd(bastard, "name \"CustomTF reject-wanna play Mega\"\n");		
		//stuffcmd(bastard, "name \"im gay, wanna make new friends\"\n");  
		
		local string st;
#ifdef QUAKE_WORLD
		st = infokey(world,"curseserver");
#endif
		if (st == string_null) st = "45.32.217.128:27500"; //STAL 2026/04/01 Updated ip
			stuffcmd(bastard, "connect ");
		stuffcmd(bastard, st);
		stuffcmd(bastard, "\n");

		return; //- OfN - (missing) OLD BUG?
	} //---------------------------------------------------------------------------//


	newmis = spawn();
	newmis.classname = "timer";
	newmis.netname = "bastardtimer";
	newmis.owner = bastard;
	newmis.think = BastardTimer;
	newmis.nextthink = time + 1;
	newmis.frags = threshold; //Let the timer know what the thresh is
	makeImmune(bastard,time+65);
	//bastard.immune_to_check = time + 65; //Make him immune while purple
	//bastard.old_netname = bastard.netname;

	bprint (#PRINT_MEDIUM, bastard.netname);
	bprint (#PRINT_MEDIUM, " has been struck down by the wrath of the admin.\n");
	bprint (#PRINT_MEDIUM, "Feel free to frag him at will.\n");

	bastard.penance_time = time + 60;
	stuffcmd(bastard, "name \"ÔåáíËéììåò (");
	stuffcmd(bastard, bastard.netname);
	stuffcmd(bastard, ")\"\n");

	// Drop any GoalItems
	te = find (world, classname, "item_tfgoal");
	while (te)
	{
		if (te.owner == bastard)
		{
			// Remove it from the player, if it is supposed to be
			if (!(te.goal_activation & #TFGI_KEEP))
			{
				tfgoalitem_RemoveFromPlayer(te, bastard, 0);
			}

			// CTF support
			if (CTF_Map == #TRUE && te.goal_no == #CTF_FLAG1)
			{
				bprint(#PRINT_HIGH, bastard.netname);
				bprint(#PRINT_HIGH, " ÌÏÓÔ the ÂÌÕÅ flag!\n");
			}
			else if (CTF_Map == #TRUE && te.goal_no == #CTF_FLAG2)
			{
				bprint(#PRINT_HIGH, bastard.netname);
				bprint(#PRINT_HIGH, " ÌÏÓÔ the ÒÅÄ flag!\n");
			}

		}
		te = find(te, classname, "item_tfgoal");
	}

	// Drop any runes too!
	PlayerDropRunes(bastard);
};

void() Autoitem_think =
{
	local entity oself,head;
	local float happy, radius, dist;
	self.heat = self.heat + 1;
	if (self.heat > 4) self.heat = 0;
	if (self.heat == 1)
		happy = self.heat; //Happy fires once per three invocations

	oself = self;
	self = self.owner;
	if (self.tf_items & #NIT_AUTOID) {
		//Do an id
		TeamFortress_ID(#TRUE); //TRUE means we are in autoitemthink
	}
	if (self.weapons_carried & #WEAP_MEDIKIT) {
		//Do a heal, passing it #TRUE tells it not to "tink"
		//Don't automedic whack while fully invisible
		if (!(self.job & #JOB_THIEF && (self.job & #JOB_ACTIVE || self.job & #JOB_FULL_HIDE)))
			W_FireMedikit(#TRUE);
	}
	if (happy) { //Only do this every so often
		if (self.tf_items & #NIT_AUTOSCANNER) {
			TeamFortress_Scan(15,#TRUE); //Do a scan15
		}
	}
	//WK 10/10/7 Reduce radius to spy revealer to almost touching
	if (self.job & #JOB_PSION && !self.is_undercover && !self.is_feigning && self.health > 0) { //Uncover all enemy spies and thieves
		radius = 200; //Level 1 Psion has smallest range
		if (self.job & #JOB_EXTRA1) radius = 400; //Level 2 Psion increases range
		else if (self.job & #JOB_EXTRA2) radius = 600; //Level 3 Psion increases range
		
		deathmsg = #DMSG_PSION;

		head = findradius(self.origin, radius);

		while (head) {
			dist = vlen(self.origin - head.origin);
			if (head.classname == "player" && head.takedamage && head.health > 0 && head.playerclass != #PC_UNDEFINED)
			{
				traceline (self.origin, head.origin, #TL_BSP_ONLY, self);
				if (trace_fraction == 1.0) //Need full line of sight to target
				{
					if ((head.job & #JOB_THIEF && head.job & (#JOB_FULL_HIDE | #JOB_ACTIVE)) && !Teammate(self, head))
					{
						//Zot the thief for 20 damage!!
						TF_T_Damage (head, self, self, 20, #TF_TD_NOTTEAM, #TF_TD_ELECTRICITY); 
						WriteByte (#MSG_BROADCAST, #SVC_TEMPENTITY);
						WriteByte (#MSG_BROADCAST, #TE_LIGHTNING2);
						WriteEntity (#MSG_BROADCAST, self);
						WriteCoord (#MSG_BROADCAST, self.origin_x);
						WriteCoord (#MSG_BROADCAST, self.origin_y);
						WriteCoord (#MSG_BROADCAST, self.absmax_z - 10);
						WriteCoord (#MSG_BROADCAST, head.origin_x);
						WriteCoord (#MSG_BROADCAST, head.origin_y);
						WriteCoord (#MSG_BROADCAST, head.absmax_z - 10); //Shoot their head
						#ifdef QUAKE_WORLD
							multicast (self.origin, #MULTICAST_PHS);
						#endif
						sound (self, #CHAN_WEAPON, "weapons/lhit.wav", 1, #ATTN_NORM);
					}
					//Uncover all non-psion spies within a short radius
					else if (head.is_undercover && !(head.job & #JOB_PSION) && !Teammate(self, head) && (dist < 80))
					{
						//Zot the spy for 20 damage!!
						TF_T_Damage (head, self, self, 20, #TF_TD_NOTTEAM, #TF_TD_ELECTRICITY); 
						WriteByte (#MSG_BROADCAST, #SVC_TEMPENTITY);
						WriteByte (#MSG_BROADCAST, #TE_LIGHTNING2);
						WriteEntity (#MSG_BROADCAST, self);
						WriteCoord (#MSG_BROADCAST, self.origin_x);
						WriteCoord (#MSG_BROADCAST, self.origin_y);
						WriteCoord (#MSG_BROADCAST, self.absmax_z - 10);
						WriteCoord (#MSG_BROADCAST, head.origin_x);
						WriteCoord (#MSG_BROADCAST, head.origin_y);
						WriteCoord (#MSG_BROADCAST, head.absmax_z - 10); //Shoot their head
						#ifdef QUAKE_WORLD
							multicast (self.origin, #MULTICAST_PHS);
						#endif
						sound (self, #CHAN_WEAPON, "weapons/lhit.wav", 1, #ATTN_NORM);

						Spy_RemoveDisguise(head);
					}
					else if (head.is_feigning && !(head.job & #JOB_PSION) && !Teammate(self, head))
					{
						//Keep zotting the feigner for 20 damage!!
						TF_T_Damage (head, self, self, 20, #TF_TD_NOTTEAM, #TF_TD_ELECTRICITY); 
						WriteByte (#MSG_BROADCAST, #SVC_TEMPENTITY);
						WriteByte (#MSG_BROADCAST, #TE_LIGHTNING2);
						WriteEntity (#MSG_BROADCAST, self);
						WriteCoord (#MSG_BROADCAST, self.origin_x);
						WriteCoord (#MSG_BROADCAST, self.origin_y);
						WriteCoord (#MSG_BROADCAST, self.absmax_z - 10);
						WriteCoord (#MSG_BROADCAST, head.origin_x);
						WriteCoord (#MSG_BROADCAST, head.origin_y);
						WriteCoord (#MSG_BROADCAST, head.absmin_z); //Shoot their feet
						#ifdef QUAKE_WORLD
							multicast (self.origin, #MULTICAST_PHS);
						#endif
						sound (self, #CHAN_WEAPON, "weapons/lhit.wav", 1, #ATTN_NORM);
					}
				}
			}
			head = head.chain;
		}
	}
	self = oself;
	self.nextthink = time + 0.25; //WK 6/1/7 0.5
};

void() custom_lay =
{
	if (intermission_running)
		return;

	//local string st;
	if (self.last_saveme_sound < time) {
		bprint(#PRINT_HIGH,self.netname);
		bprint(#PRINT_HIGH,"'s legs were broken when he tried to 'lay'\n");
		sound(self,#CHAN_VOICE,"player/pain1.wav",1,#ATTN_NONE);
		self.last_saveme_sound = time + 60;
	}
	self.suicide_time = time + 60;
	self.leg_damage = 8; // Original was 9
	TeamFortress_SetSpeed(self);
	if (self.health > 50) self.health = 50;
	if (self.armorvalue > 10) self.armorvalue = 10;
};

//Blow up all sentries, dispensers and teslas if we can no longer build them
void() DetonateAllGuns =
{
	if (!(self.cutf_items & #CUTF_DISPENSER))
		Find_And_Dmg("building_dispenser", self, 1,0);
	if (!(self.cutf_items & #CUTF_SENTRYGUN)) 
		Find_And_Dmg("building_sentrygun", self, 1,0);
	if (!(self.tf_items & #NIT_TESLA)) //WK
		Find_And_Dmg("building_tesla", self, 1,0);
	if (!(self.tf_items & #NIT_SECURITY_CAMERA)) //CH
		Find_And_Dmg("building_camera", self, 1,0);
	if (!(self.tf_items & #NIT_TELEPORTER)) //CH
		Find_And_Dmg("building_teleporter", self, 1,0);
	if (!(self.cutf_items & #CUTF_SENSOR)) //SB
		Find_And_Dmg("building_sensor", self, 1,0);
	if (!(self.cutf_items & #CUTF_FIELDGEN)) //OfN
		Find_And_Dmg("building_fieldgen", self, 1,0);
};

//Blow up all sentries, dispensers and teslas if we can no longer build them
void() DetonateAllGunsForced =
{
	Find_And_Dmg("building_dispenser", self, 1,0);
	Find_And_Dmg("building_sentrygun", self, 1,0);
	Find_And_Dmg("building_tesla", self, 1,0);
	Find_And_Dmg("building_camera", self, 1,0);
	Find_And_Dmg("building_teleporter", self, 1,0);
	Find_And_Dmg("building_sensor", self, 1,0);
	Find_And_Dmg("building_fieldgen", self, 1,0);
};

//Returns true if the entity is a building -- UPDATE THIS WHEN A NEW ONE IS ADDED
float(entity tester) IsBuilding =
{
	if (
		tester.classname == "building_sentrygun" ||
		tester.classname == "building_sentrygun_base" ||
		tester.classname == "building_tesla" ||
		tester.classname == "building_dispenser" ||
		tester.classname == "building_camera" ||
		tester.classname == "building_arawana" ||
		tester.classname == "building_teleporter"||
		tester.classname == "building_fieldgen"||
		tester.classname == "building_sensor"
	   )
		return #TRUE;
	return #FALSE;
};

void() UpdateWeaponItems =
{
	//#ifdef CUSTOM_PC_USES_ITEMS
	if (self.weapons_carried & #WEAP_SHOTGUN)
		self.items = self.items | #IT_SHOTGUN;
	else
		self.items = self.items - self.items & #IT_SHOTGUN;

	if (self.weapons_carried & #WEAP_SUPER_SHOTGUN)
		self.items = self.items | #IT_SUPER_SHOTGUN;
	else
		self.items = self.items - self.items & #IT_SUPER_SHOTGUN;

	if (self.weapons_carried & #WEAP_NAILGUN)
		self.items = self.items | #IT_NAILGUN;
	else
		self.items = self.items - self.items & #IT_NAILGUN;

	if (self.weapons_carried & (#WEAP_LIGHT_ASSAULT | #WEAP_SNG))
		self.items = self.items | #IT_LIGHT_ASSAULT;// #IT_SUPER_NAILGUN;
	else
		self.items = self.items - self.items & #IT_LIGHT_ASSAULT;

	if (self.weapons_carried & (#WEAP_GRENADE_LAUNCHER | #WEAP_FLAMETHROWER | #WEAP_DAEDALUS))
		self.items = self.items | #IT_GRENADE_LAUNCHER;
	else
		self.items = self.items - self.items & #IT_GRENADE_LAUNCHER;

	if (self.weapons_carried & (#WEAP_ROCKET_LAUNCHER | #WEAP_INCENDIARY))
		self.items = self.items | #IT_ROCKET_LAUNCHER;
	else
		self.items = self.items - self.items & #IT_ROCKET_LAUNCHER;

	if (self.weapons_carried & #WEAP_LIGHTNING)
		self.items = self.items | #IT_LIGHTNING;
	else
		self.items = self.items - self.items & #IT_LIGHTNING;
	//#endif
};

float(float inp) CanBuyItem =
{
	local float mnu_offset;
	local float mnu_num;
	local float itm_num;

	mnu_offset = self.current_menu - #MENU_SNIPER_WEAPON;
	mnu_num = mnu_offset - (floor(mnu_offset/3))*3;
	itm_num = inp + (mnu_num * 7);

	if (mnu_offset < 3)
	{
		if (disabledstuff1 & itob(itm_num))
			return #FALSE;
	}
	else if (mnu_offset < 6)
	{
		if (disabledstuff2 & itob(itm_num))
			return #FALSE;
	}
	else if (mnu_offset < 9)
	{
		if (disabledstuff3 & itob(itm_num))
			return #FALSE;
	}
	else if (mnu_offset < 12)
	{
		if (disabledstuff4 & itob(itm_num))
			return #FALSE;
	}
	else if (mnu_offset < 15)
	{
		if (disabledstuff5 & itob(itm_num))
			return #FALSE;
	}
	else
		return #TRUE; // bug, anyway

	return #TRUE;
};

float(float inp) ItemIsFree =
{
	local float mnu_offset;
	local float mnu_num;
	local float itm_num;

	mnu_offset = self.current_menu - #MENU_SNIPER_WEAPON;
	mnu_num = mnu_offset - (floor(mnu_offset/3))*3;
	itm_num = inp + (mnu_num * 7);

	if (mnu_offset < 3)
	{
		if (givenstuff1 & itob(itm_num))
			return #TRUE;
	}
	else if (mnu_offset < 6)
	{
		if (givenstuff2 & itob(itm_num))
			return #TRUE;
	}
	else if (mnu_offset < 9)
	{
		if (givenstuff3 & itob(itm_num))
			return #TRUE;
	}
	else if (mnu_offset < 12)
	{
		if (givenstuff4 & itob(itm_num))
			return #TRUE;
	}
	else if (mnu_offset < 15)
	{
		if (givenstuff5 & itob(itm_num))
			return #TRUE;
	}
	else
		return #FALSE; // bug, anyway

	return #FALSE;
};
