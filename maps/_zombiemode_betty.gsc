#include common_scripts\utility; 
#include maps\_utility;
#include maps\_zombiemode_utility;


/*------------------------------------
BOUNCING BETTY STUFFS -
a rough prototype for now, needs a bit more polish

------------------------------------*/
init()
{
	trigs = getentarray("betty_purchase","targetname");
	for(i=0; i<trigs.size; i++)
	{
		model = getent( trigs[i].target, "targetname" );
		model hide();
	}

	array_thread(trigs,::buy_bouncing_betties);
	level thread give_betties_after_rounds();
}

buy_bouncing_betties()
{
	self.zombie_cost = 1000;
	self UseTriggerRequireLookAt();
	self sethintstring( &"ZOMBIE_BETTY_PURCHASE" );
	self setCursorHint( "HINT_NOICON" );

	level thread set_betty_visible();
	self.betties_triggered = false;

	while(1)
	{
		self waittill("trigger",who);
		if( who in_revive_trigger() )
		{
			continue;
		}

		if( is_player_valid( who ) )
		{

			if( who.score >= self.zombie_cost )
			{
				if ( !who is_player_placeable_mine( "mine_bouncing_betty" ) )
				{
					play_sound_at_pos( "purchase", self.origin );

					//set the score
					who maps\_zombiemode_score::minus_to_player_score( self.zombie_cost );
					who maps\_zombiemode_weapons::check_collector_achievement( "mine_bouncing_betty" );
					who thread bouncing_betty_setup();
					who thread show_betty_hint("betty_purchased");

					// JMA - display the bouncing betties
					if( self.betties_triggered == false )
					{
						model = getent( self.target, "targetname" );
						model thread maps\_zombiemode_weapons::weapon_show( who );
						self.betties_triggered = true;
					}

					trigs = getentarray("betty_purchase","targetname");
					for(i = 0; i < trigs.size; i++)
					{
						trigs[i] SetInvisibleToPlayer(who);
					}
				}
				else
				{
					//who thread show_betty_hint("already_purchased");

				}
			}
		}
	}
}

set_betty_visible()
{
	players = getplayers();
	trigs = getentarray("betty_purchase","targetname");

	while(1)
	{
		for(j = 0; j < players.size; j++)
		{
			if( !players[j] is_player_placeable_mine( "mine_bouncing_betty" ) )
			{
				for(i = 0; i < trigs.size; i++)
				{
					trigs[i] SetInvisibleToPlayer(players[j], false);
				}
			}
		}

		wait(1);
		players = getplayers();
	}
}

bouncing_betty_watch()
{
	self endon("death");

	while(1)
	{
		self waittill("grenade_fire",betty,weapname);
		if(weapname == "mine_bouncing_betty")
		{
			betty.owner = self;
			betty thread betty_think();
			self thread betty_death_think();
			betty thread pickup_betty();
		}
	}
}

betty_death_think()
{
	self waittill("death");

	if(is_in_array(self.owner.mines,self))
	{
		self.owner.mines = array_remove_nokeys(self.owner.mines,self);
	}

	if(isDefined(self.trigger))
	{
		self.trigger delete();
	}

	self delete();

}

bouncing_betty_setup()
{
	self thread bouncing_betty_watch();

	self giveweapon("mine_bouncing_betty");
	self set_player_placeable_mine("mine_bouncing_betty");
	self setactionslot(4,"weapon","mine_bouncing_betty");
	self setweaponammostock("mine_bouncing_betty",5);
}

betty_think()
{
	if(!isdefined(self.owner.mines))
		self.owner.mines = [];
	self.owner.mines = array_add( self.owner.mines, self );

	if( self.owner.mines.size > 20 )
	{
		self.owner.mines[0].trigger notify("trigger");
		self.owner.mines = array_remove_nokeys( self.owner.mines, self.owner.mines[0] );
	}

	self waittill_not_moving();

	trigger = spawn("trigger_radius",self.origin,9,80,64);//9
	self.trigger = trigger;

	wait(1);

	while(1)
	{
		trigger waittill( "trigger", ent );

		if ( isdefined( self.owner ) && ent == self.owner )
			continue;

		if( isDefined( ent.pers ) && isDefined( ent.pers["team"] ) && ent.pers["team"] != "axis" )
			continue;

		break;
	}

	self.activated = true;
	self playsound("betty_activated");
	wait(.1);
	fake_model = spawn("script_model",self.origin);
	fake_model setmodel(self.model);
	self hide();
	tag_origin = spawn("script_model",self.origin);
	tag_origin setmodel("tag_origin");
	tag_origin linkto(fake_model);
	playfxontag(level._effect["betty_trail"], tag_origin,"tag_origin");
	fake_model moveto (fake_model.origin + (0,0,32),.2);
	fake_model waittill("movedone");
	playfx(level._effect["betty_explode"], fake_model.origin);
	earthquake(1, .4, fake_model.origin, 512);

	if ( isdefined( self.owner ) )
	{
		self detonate( self.owner );
	}
	else
	{
		self detonate( undefined );
	}

	if ( isdefined( trigger ) )
	{
		trigger delete();
	}
	if ( isdefined( fake_model ) )
	{
		fake_model delete();
	}
	if ( isdefined( tag_origin ) )
	{
		tag_origin delete();
	}
	if ( isdefined( self ) )
	{
		self delete();
	}
}

betty_smoke_trail()
{
	self.tag_origin = spawn("script_model",self.origin);
	self.tag_origin setmodel("tag_origin");
	playfxontag(level._effect["betty_trail"],self.tag_origin,"tag_origin");
	self.tag_origin moveto(self.tag_origin.origin + (0,0,100),.15);
}

give_betties_after_rounds()
{
	while(1)
	{
		level waittill( "between_round_over" );
		{
			players = get_players();
			for(i=0;i<players.size;i++)
			{
				if ( players[i] is_player_placeable_mine( "mine_bouncing_betty" ) )
				{
					players[i]  giveweapon("mine_bouncing_betty");
					players[i]  set_player_placeable_mine("mine_bouncing_betty");
					players[i]  setactionslot(4,"weapon","mine_bouncing_betty");
					players[i]  setweaponammoclip("mine_bouncing_betty",2);
				}
			}
		}
	}
}

//betty hint stuff
init_hint_hudelem(x, y, alignX, alignY, fontscale, alpha)
{
	self.x = x;
	self.y = y;
	self.alignX = alignX;
	self.alignY = alignY;
	self.fontScale = fontScale;
	self.alpha = alpha;
	self.sort = 20;
	//self.font = "objective";
}

setup_client_hintelem()
{
	self endon("death");
	self endon("disconnect");

	if(!isDefined(self.hintelem))
	{
		self.hintelem = newclienthudelem(self);
	}
	self.hintelem init_hint_hudelem(320, 220, "center", "bottom", 1.6, 1.0);
}


show_betty_hint(string)
{
	self endon("death");
	self endon("disconnect");

	if(string == "betty_purchased")
		text = &"ZOMBIE_BETTY_HOWTO";
	else
		text = &"ZOMBIE_BETTY_ALREADY_PURCHASED";

	self setup_client_hintelem();
	self.hintelem setText(text);
	wait(3.5);
	self.hintelem settext("");
}

//self = betty
pickup_betty()
{
	self endon("death");
	self endon("picked_up");

	//self waittill_not_moving();

	while(!IsDefined(self.trigger))
	{
		wait .05;
	}

	players = get_players();
	for(i=0;i<players.size;i++)
	{
		if(players[i] != self.owner)
		{
			self.trigger SetInvisibleToPlayer(players[i]);
		}
	}

	self.trigger SetHintString("Hold ^3[{+activate}]^7 to Pick Up Bouncing Betty");
	self.trigger setCursorHint( "HINT_NOICON" );

	if(!IsDefined(self.owner.already_picking_up))
	{
		self.owner.already_picking_up = false;
	}

	//fix being able to pick up 2 betties at the same time
	while(1)
	{
		if(IsDefined(self.activated) && self.activated)
		{
			self.trigger SetInvisibleToPlayer(self.owner);
			return;
		}
		if(self.owner.already_picking_up && !self.owner UseButtonPressed())
		{
			self.owner.already_picking_up = false;
		}
		if(self.owner maps\_laststand::player_is_in_laststand() || self.owner GetWeaponAmmoClip("mine_bouncing_betty") == 2)
		{
			self.trigger SetInvisibleToPlayer(self.owner);
			wait .05;
			continue;
		}

		/*closest = self.owner.mines[0];
		distance = DistanceSquared(self.owner.origin, self.owner.mines[0].origin);
		for(i=1;i<self.owner.mines.size;i++)
		{
			if(DistanceSquared(self.owner.origin[2], self.owner.mines[i].origin[2]) > 64*64 || Distance2D(self.owner.origin, self.owner.mines[i].origin) > 64)
			{
				continue;
			}
			new_distance = DistanceSquared(self.owner.origin, self.owner.mines[i].origin);
			if(new_distance < distance)
			{
				distance = new_distance;
				closest = self.owner.mines[i];
			}
		}*/

		if(abs(self.owner.origin[2] - self.origin[2]) <= 16 && Distance2D(self.owner.origin, self.origin) <= 64)
		{
			self.trigger SetVisibleToPlayer(self.owner);
			if(self.owner UseButtonPressed() && !self.owner.already_picking_up)//&& self == closest
			{
				self.owner.already_picking_up = true;
				self give_betty();
			}
		}
		else
		{
			self.trigger SetInvisibleToPlayer(self.owner);
		}
		wait .05;
	}
}

give_betty()
{
	wait .05;

	if ( !self.owner hasweapon( "mine_bouncing_betty" ) )
	{
		self.owner thread bouncing_betty_watch();

		self.owner giveweapon("mine_bouncing_betty");
		self.owner set_player_placeable_mine("mine_bouncing_betty");
		self.owner setactionslot(4,"weapon","mine_bouncing_betty");
		self.owner setweaponammoclip("mine_bouncing_betty",1);
	}
	else
	{
		self.owner SetWeaponAmmoClip("mine_bouncing_betty", self.owner GetWeaponAmmoClip("mine_bouncing_betty") + 1);
	}

	if(is_in_array(self.owner.mines,self))
	{
		self.owner.mines = array_remove_nokeys(self.owner.mines,self);
	}

	if(isDefined(self.trigger))
	{
		self.trigger delete();
	}

	self delete();

	self notify("picked_up");
}
