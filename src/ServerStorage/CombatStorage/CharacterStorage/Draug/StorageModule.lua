local module = {}

local KnockbackProfiles = require(game.ServerStorage.CombatStorage.GlobalStorage.KnockbackProfiles)

local EffectStorage = game.ReplicatedStorage.CombatStorage.Draug.Effects

local AnimationStorage = game.ReplicatedStorage.CombatStorage.GlobalAnimations.CombatAnimationsTemplates.SwordsmanAnimations
local GlobalAnimationStorage = game.ReplicatedStorage.CombatStorage.GlobalAnimations
local GlobalSFX = game.ReplicatedStorage.CombatStorage.GlobalSFX
local CharacterStorageSFX = game.ReplicatedStorage.CombatStorage.Draug.Sounds
local ServerStorageFolder = game.ServerStorage.CombatStorage.CharacterStorage.Draug
local SkillStorage = game.ServerStorage.SkillStorage

module.Visuals = {
	Animations = {
		AnimateScript = AnimationStorage.Animate,

		BasicInputs = {
			CROUCH = AnimationStorage.crouch,
			BACK_DASH = AnimationStorage.backdash,
			FORWARD_DASH = AnimationStorage.dash,
			GRAB = AnimationStorage.GrabTry,
			DOUBLE_JUMP = AnimationStorage.Jump,
			
			BLOCK = {
				Holding = GlobalAnimationStorage.Blocking,
				Normal = AnimationStorage.blockair,
				Parry = AnimationStorage.blocklow,
			},
			
			CHARGEATK = {
				Charge = AnimationStorage.ChargeKi,	
				Release = AnimationStorage.Hit2
			}
		},

		CompoundInputs = { 
			AIRLIGHTATK = AnimationStorage.Hit1,
			AIRHARDATK = AnimationStorage.LowAttack,
			CROUCHLIGHTATK = AnimationStorage.Hit2,
			BURST = AnimationStorage.burst
		},

		Sequences = {
			LightAtks = {
				[1] = {
					OnGroundAnimation = AnimationStorage.Hit1,
					InAirAnimation = AnimationStorage.HeavyHit4Air
				},
				
				[2] = { 
					OnGroundAnimation = AnimationStorage.Hit2,
					InAirAnimation = AnimationStorage.Hit6,
				},
				
				[3] = {
					OnGroundAnimation = AnimationStorage.Hit3,
					InAirAnimation = AnimationStorage.HeavyHit2Air
				},
				
				[4] = {
					OnGroundAnimation = AnimationStorage.Hit4,
					InAirAnimation = AnimationStorage.HeavyHit1Air
				},
				
				[5] = {
					InAirAnimation = AnimationStorage.Hit5,
					OnGroundAnimation = AnimationStorage.Hit4
				},
				
				[6] = {
					InAirAnimation = AnimationStorage.Hit6,
					OnGroundAnimation = AnimationStorage.Hit4
				},
				
				[7] = {
					InAirAnimation = AnimationStorage.Hit7,
					OnGroundAnimation = AnimationStorage.Hit1
				}
			},

			HardAtks = {
				Standing = {
					[1] = {
						OnGroundAnimation = AnimationStorage.HeavyHit1,
						InAirAnimation = AnimationStorage.HeavyHit1Air
					},
					
					[2] = {
						OnGroundAnimation = AnimationStorage.HeavyHit2,
						InAirAnimation = AnimationStorage.HeavyHit2Air
					},
					
					[3] = {
						OnGroundAnimation = AnimationStorage.HeavyHit3,
						InAirAnimation = AnimationStorage.HeavyHit3Air
					},
					
					[4] = {
						OnGroundAnimation = AnimationStorage.HeavyHit4,
						InAirAnimation = AnimationStorage.HeavyHit4Air
					},
				},
				
				Crouching = {
					[1] = {
						OnGroundAnimation = AnimationStorage.Hit3,
						InAirAnimation = AnimationStorage.HeavyHit2Air
					},

					[2] = {
						OnGroundAnimation = AnimationStorage.HeavyHit3,
						InAirAnimation = AnimationStorage.HeavyHit3Air
					},

					[3] = {
						OnGroundAnimation = AnimationStorage.HeavyHit4,
						InAirAnimation = AnimationStorage.HeavyHit4Air
					},

					[4] = {
						OnGroundAnimation = AnimationStorage.HeavyHit5,
						InAirAnimation = AnimationStorage.HeavyHit5Air
					}
				}
			}
		},
		
		Combos = {
			Uppercut = GlobalAnimationStorage.Uppercut,
			HardPunch = GlobalAnimationStorage.HardPunch,
			DownSlide = GlobalAnimationStorage.DownSlide,
			SpinKick = GlobalAnimationStorage.SpinKick
		},

		Hits = {
			AIRLIGHTATK = GlobalAnimationStorage.high,
			AIRHARDATK = GlobalAnimationStorage.high,
			CROUCHLIGHTATK = GlobalAnimationStorage.low,
			CHARGEATK = GlobalAnimationStorage.high,
			BURST = GlobalAnimationStorage.high,
			
			Combos = {
				Uppercut = GlobalAnimationStorage.mid,
				HardPunch = GlobalAnimationStorage.mid,
				DownSlide = GlobalAnimationStorage.mid,
				SpinKick = GlobalAnimationStorage.mid
			},

			LightAtks = {
				[1] = GlobalAnimationStorage.mid,
				[2] = GlobalAnimationStorage.extramid2,
				[3] = GlobalAnimationStorage.mid,
				[4] = GlobalAnimationStorage.high,
				[5] = GlobalAnimationStorage.mid,
				[6] = GlobalAnimationStorage.high,
				[7] = GlobalAnimationStorage.low
			},

			HardAtks = {
				Standing = {
					[1] = GlobalAnimationStorage.mid,
					[2] = GlobalAnimationStorage.low,
					[3] = GlobalAnimationStorage.mid,
					[4] = GlobalAnimationStorage.high,
				},
				
				Crouching = {
					[1] = GlobalAnimationStorage.high,
					[2] = GlobalAnimationStorage.mid,
					[3] = GlobalAnimationStorage.low,
					[4] = GlobalAnimationStorage.mid
				}
			}
		},
	},
	
	Effects = {	
		BasicInputs = {
			BLOCK = {
				Normal = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Self',
					Delay = 0,
					Effect = EffectStorage.Block
				},
				
				Parry = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.Parry
				},
				
				Break = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.Break
				}
			},
			
			DOUBLE_JUMP = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Self',
				Delay = 0,
				Effect = nil
			},
			
			FORWARD_DASH = {
				Type = 'Emit', 
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Self',
				Delay = 0,
				Effect = nil
			},
			
			BACK_DASH = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Self',
				Delay = 0,
				Effect = nil
			},
			
			GRAB = {
				
				
			},
			
			CHARGEATK = {
				Charge = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Self',
					Delay = 0,
					Effect = EffectStorage.Punch
				},
				
				Release = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Self',
					Delay = 0,
					Effect = EffectStorage.SlashDown
				}
			}
		},
		
		CompoundInputs = {
			AIRLIGHTATK = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'HumanoidRootPart',
				TargetCharacter = 'Self',
				Delay = 0,
				Effect = EffectStorage.SlashDown
			},
			
			AIRHARDATK = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'HumanoidRootPart',
				TargetCharacter = 'Self',
				Delay = 0,
				Effect = EffectStorage.SlashDown
			},
			
			CROUCHLIGHTATK = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'HumanoidRootPart',
				TargetCharacter = 'Self',
				Delay = 0,
				Effect = EffectStorage.Punch
			},
			
			BURST = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'HumanoidRootPart',
				TargetCharacter = 'Self',
				Delay = 0,
				Effect = nil
			}
		},
		
		Sequences = {
			LightAtks = {
				[1] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'HumanoidRootPart',
					TargetCharacter = 'Self',
					Delay = 0,
					Effect = EffectStorage.SlashLeft
				},
				[2] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'HumanoidRootPart',
					TargetCharacter = 'Self',
					Delay = 0,
					Effect = EffectStorage.SlashLeft2
				},
				[3] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'HumanoidRootPart',
					TargetCharacter = 'Self',
					Delay = 0,
					Effect = EffectStorage.SlashRight2
				},
				[4] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'HumanoidRootPart',
					TargetCharacter = 'Self',
					Delay = 0,
					Effect = EffectStorage.SlashUp
				},
				[5] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'HumanoidRootPart',
					TargetCharacter = 'Self',
					Delay = 0,
					Effect = EffectStorage.SlashLeft
				},
				[6] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'HumanoidRootPart',
					TargetCharacter = 'Self',
					Delay = 0,
					Effect = EffectStorage.SlashUp
				},
				[7] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'HumanoidRootPart',
					TargetCharacter = 'Self',
					Delay = 0,
					Effect = EffectStorage.SlashDown
				}
			},
			
			HardAtks = {
				Standing = {
					[1] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'HumanoidRootPart',
						TargetCharacter = 'Self',
						Delay = 0.3,
						Effect = EffectStorage.SlashLeft2
					},
					[2] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'HumanoidRootPart',
						TargetCharacter = 'Self',
						Delay = 0,
						Effect = EffectStorage.SlashRight
					},
					[3] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'HumanoidRootPart',
						TargetCharacter = 'Self',
						Delay = 0,
						Effect = EffectStorage.SlashUp
					},
					[4] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'HumanoidRootPart',
						TargetCharacter = 'Self',
						Delay = 0,
						Effect = EffectStorage.SlashLeft
					}
				},
				
				Crouching = {
					[1] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'HumanoidRootPart',
						TargetCharacter = 'Self',
						Delay = 0,
						Effect = EffectStorage.SlashRight2
					},
					[2] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'HumanoidRootPart',
						TargetCharacter = 'Self',
						Delay = 0,
						Effect = EffectStorage.SlashLeftDown
					},
					[3] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'HumanoidRootPart',
						TargetCharacter = 'Self',
						Delay = 0,
						Effect = nil
					},
					[4] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'HumanoidRootPart',
						TargetCharacter = 'Self',
						Delay = 0,
						Effect = EffectStorage.SlashRightDown
					}
				},		
			}
		},
		
		Combos = {
			Uppercut = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.GrabCatch
			},
			HardPunch = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.GrabCatch
			},
			DownSlide = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.GrabCatch
			},
			SpinKick = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.GrabCatch
			}
		},
		
		Hits = {
			PARRY = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.Parry
			},
			
			AIRLIGHTATK = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.HitUp
			},
			
			AIRHARDATK = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.HitUp
			},
			
			CROUCHLIGHTATK = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.HitUp
			},
			
			CHARGEATK = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.HitUp
			},
			
			BURST = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.HitUp
			},

			Combos = {
				Uppercut = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUp
				},
				HardPunch = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUp
				},
				DownSlide = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUp
				},
				SpinKick = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUp
				}
			},

			LightAtks = {
				[1] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUp
				},
				
				[2] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUp
				},
				
				[3] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.SlashHit
				},
				
				[4] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.SlashHitUp
				},
				
				[5] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.SlashHit
				},
				
				[6] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.SlashHitUp
				},
				
				[7] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUp
				}
			},

			HardAtks = {
				Standing = {
					[1] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.SlashHit
					},
					
					[2] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.SlashHitUp
					},
					
					[3] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.SlashHit
					},
					
					[4] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.HitUp
					}
				},

				Crouching = {
					[1] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.SlashHitUp
					},
					
					[2] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.SlashHit
					},
					
					[3] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.HitUp
					},
					
					[4] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.SlashHit
					}
				}
			}
		}
	},
	
	Sounds = {
		BasicInputs = {
			BLOCK = {
				Normal = {
					Sound = GlobalSFX.Block,
					TargetCharacterBodyPart = "Torso"
				},
				Parry = {
					Sound = GlobalSFX.Parry,
					TargetCharacterBodyPart = "Torso"
				},
				Break = {
					Sound = GlobalSFX.BlockBreak,
					TargetCharacterBodyPart = "Torso"
				}
			},
			
			BACK_DASH = {
				Sound = CharacterStorageSFX.dash,
				TargetCharacterBodyPart = "Torso"
			},
			
			FORWARD_DASH = {
				Sound = CharacterStorageSFX.dash,
				TargetCharacterBodyPart = "Torso"
			},
			
			DOUBLE_JUMP = {
				Sound = CharacterStorageSFX.basejump,
				TargetCharacterBodyPart = "Torso"
			},
			
			GRAB = {
				Sound = CharacterStorageSFX.Grab,
				TargetCharacterBodyPart = "Torso"
			},

			CHARGEATK = {
				Charge = {
					Sound = CharacterStorageSFX.charge,
					TargetCharacterBodyPart = "Torso"
				},
				Release = {
					Sound = CharacterStorageSFX.Fist.swing,
					TargetCharacterBodyPart = "Torso"
				}
			}
		},

		CompoundInputs = {
			AIRLIGHTATK = {
				Sound = CharacterStorageSFX.Fist.swing,
				TargetCharacterBodyPart = "Torso"
			},
			AIRHARDATK = {
				Sound = CharacterStorageSFX.Fist.swing,
				TargetCharacterBodyPart = "Torso"
			},
			CROUCHLIGHTATK = {
				Sound = CharacterStorageSFX.Fist.swing,
				TargetCharacterBodyPart = "Torso"
			},
			BURST = {
				Sound = CharacterStorageSFX.burst,
				TargetCharacterBodyPart = "Torso"
			}
		},

		Sequences = {
			LightAtks = {
				[1] = {
					Sound = CharacterStorageSFX.Fist.swing,
					TargetCharacterBodyPart = "Torso"
				},
				[2] = {
					Sound = CharacterStorageSFX.Fist.swing2,
					TargetCharacterBodyPart = "Torso"
				},
				[3] = {
					Sound = CharacterStorageSFX.Fist.swing3,
					TargetCharacterBodyPart = "Torso"
				},
				[4] = {
					Sound = CharacterStorageSFX.Fist.swing3,
					TargetCharacterBodyPart = "Torso"
				},
				[5] = {
					Sound = CharacterStorageSFX.Fist.swing2,
					TargetCharacterBodyPart = "Torso",
				},
				[6] = {
					Sound = CharacterStorageSFX.Fist.swing,
					TargetCharacterBodyPart = "Torso"
				},
				[7] = {
					Sound = CharacterStorageSFX.Fist.swing3,
					TargetCharacterBodyPart = "Torso"
				}
			},

			HardAtks = {
				Standing = {
					[1] = {
						Sound = CharacterStorageSFX.Fist.swing,
						TargetCharacterBodyPart = "Torso"
					},
					[2] = {
						Sound = CharacterStorageSFX.Fist.swing,
						TargetCharacterBodyPart = "Torso"
					},
					[3] = {
						Sound = CharacterStorageSFX.Fist.swing,
						TargetCharacterBodyPart = "Torso"
					},
					[4] = {
						Sound = CharacterStorageSFX.Fist.swing,
						TargetCharacterBodyPart = "Torso"
					}
				},

				Crouching = {
					[1] = {
						Sound = CharacterStorageSFX.Fist.swing,
						TargetCharacterBodyPart = "Torso"
					},
					[2] = {
						Sound = CharacterStorageSFX.Fist.swing,
						TargetCharacterBodyPart = "Torso"
					},
					[3] = {
						Sound = CharacterStorageSFX.Fist.swing,
						TargetCharacterBodyPart = "Torso"
					},
					[4] = {
						Sound = CharacterStorageSFX.Fist.swing,
						TargetCharacterBodyPart = "Torso"
					}
				}
			}
		},

		Combos = {
			Uppercut = {
				Sound = CharacterStorageSFX.Fist.swing,
				TargetCharacterBodyPart = "Torso"
			},
			HardPunch = {
				Sound = CharacterStorageSFX.Fist.swing,
				TargetCharacterBodyPart = "Torso"
			},
			DownSlide = {
				Sound = CharacterStorageSFX.Fist.swing,
				TargetCharacterBodyPart = "Torso"
			},
			SpinKick = {
				Sound = CharacterStorageSFX.Fist.swing,
				TargetCharacterBodyPart = "Torso"
			}
		},

		Hits = {
			PARRY = {
				Sound = GlobalSFX.Parry,
				TargetCharacterBodyPart = "Torso"
			},
			AIRLIGHTATK = {
				Sound = CharacterStorageSFX.hit,
				TargetCharacterBodyPart = "Torso"
			},
			AIRHARDATK = {
				Sound = CharacterStorageSFX.hit2,
				TargetCharacterBodyPart = "Torso"
			},
			CROUCHLIGHTATK = {
				Sound = CharacterStorageSFX.hit3,
				TargetCharacterBodyPart = "Torso"
			},
			CHARGEATK = {
				Sound = CharacterStorageSFX.hit3,
				TargetCharacterBodyPart = "Torso"
			},
			BURST = {
				Sound = CharacterStorageSFX.hit4,
				TargetCharacterBodyPart = "Torso"
			},

			Combos = {
				Uppercut = {
					Sound = CharacterStorageSFX.hit,
					TargetCharacterBodyPart = "Torso"
				},
				HardPunch = {
					Sound = CharacterStorageSFX.hit,
					TargetCharacterBodyPart = "Torso"
				},
				DownSlide = {
					Sound = CharacterStorageSFX.hit,
					TargetCharacterBodyPart = "Torso"
				},
				SpinKick = {
					Sound = CharacterStorageSFX.hit,
					TargetCharacterBodyPart = "Torso"
				}
			},

			LightAtks = {
				[1] = {
					Sound = CharacterStorageSFX.hit,
					TargetCharacterBodyPart = "Torso"
				},
				[2] = {
					Sound = CharacterStorageSFX.hit2,
					TargetCharacterBodyPart = "Torso"
				},
				[3] = {
					Sound = CharacterStorageSFX.hit3,
					TargetCharacterBodyPart = "Torso"
				},
				[4] = {
					Sound = CharacterStorageSFX.hit4,
					TargetCharacterBodyPart = "Torso"
				},
				[5] = {
					Sound = CharacterStorageSFX.hit2,
					TargetCharacterBodyPart = "Torso"
				},
				[6] = {
					Sound = CharacterStorageSFX.hit3,
					TargetCharacterBodyPart = "Torso"
				},
				[7] = {
					Sound = CharacterStorageSFX.hit4,
					TargetCharacterBodyPart = "Torso"
				}
			},

			HardAtks = {
				Standing = {
					[1] = {
						Sound = CharacterStorageSFX.hit2,
						TargetCharacterBodyPart = "Torso"
					},
					[2] = {
						Sound = CharacterStorageSFX.hit,
						TargetCharacterBodyPart = "Torso"
					},
					[3] = {
						Sound = CharacterStorageSFX.hit3,
						TargetCharacterBodyPart = "Torso"
					},
					[4] = {
						Sound = CharacterStorageSFX.hit4,
						TargetCharacterBodyPart = "Torso"
					}
				},

				Crouching = {
					[1] = {
						Sound = CharacterStorageSFX.hit,
						TargetCharacterBodyPart = "Torso"
					},
					[2] = {
						Sound = CharacterStorageSFX.hit4,
						TargetCharacterBodyPart = "Torso"
					},
					[3] = {
						Sound = CharacterStorageSFX.hit2,
						TargetCharacterBodyPart = "Torso"
					},
					[4] = {
						Sound = CharacterStorageSFX.hit3,
						TargetCharacterBodyPart = "Torso"
					}
				}
			}
		}
	}
}

module.Logic = {
	BasicInputs = {
		BLOCK = {
			CanParryTime = 0.26,        -- antes: 0.2
			IFrameTimeAfterBlock = 0.18,       -- antes: 0.4
			ParryIFrameTime = 0.25, -- antes: 0.7
			DefensePercentage = 80
		},

		DOUBLE_JUMP = {
			Knockback = {
				Self = {
					Profile = KnockbackProfiles.DoubleJump
				}
			}
		},

		GRAB = {
			Hitbox = Vector3.new(12, 4, 8),
			RelativeHitboxPos = Vector3.new(0, -0, -3),
			HitboxSpawnTimeOffset = 0.12, -- antes: 0.07
			HitboxLifetime = 0.08,        -- antes: 0.10
			Damage = 13,
			HitStun = 0.55,
			DoingCombatTime = 0.55,      -- antes: 3

			GrabInfo = {
				DamageTime = 0.35, -- antes: 0.4
				ThrowAnimation = AnimationStorage.GrabThrow,
				VictimGrabbedAnimation = AnimationStorage.GrabVictmin,

				Effects = {
					Try = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Self',
						Delay = 0,
						Effect = EffectStorage.GrabTry
					},
					Catch = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.GrabCatch
					}
				},

				Weld = {
					C0 = CFrame.new(0, 0, 0),
					C1 = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
					AttackerBodyPart = 'HumanoidRootPart',
					VictimBodyPart = 'HumanoidRootPart',
					Lifetime = 2.3,
				},
			},

			Knockback = {
				Enemy = {
					Profile = KnockbackProfiles.None,

					KnockdownInfo = {
						Duration = 0.35,
						CanContinueCombo = false,
						WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
						InAirAnim = GlobalAnimationStorage.airlow,
						FallAnim = GlobalAnimationStorage.fall,
						GroundAnim = GlobalAnimationStorage.falled,
						WakeUpAnim = GlobalAnimationStorage.backroll
					}
				}
			}
		},

		CHARGEATK = {
			Hitbox = Vector3.new(12, 4, 8),
			RelativeHitboxPos = Vector3.new(0, -0, -3),
			HitboxSpawnTimeOffset = 0.15, -- antes: 0.07
			HitboxLifetime = 0.12,        -- antes: 0.10
			MinDamage = 13,
			MaxDamage = 25,
			HitStun = 0.55,
			DoingCombatTime = 0.55,      -- antes: 0.35
			ChargeTime = 0.9,            -- antes: 1

			Knockback = {
				Enemy = {
					Profile = KnockbackProfiles.LauncherHeavy,

					KnockdownInfo = {
						Duration = 0.35,
						CanContinueCombo = false,
						WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
						InAirAnim = GlobalAnimationStorage.airlow,
						FallAnim = GlobalAnimationStorage.fall,
						GroundAnim = GlobalAnimationStorage.falled,
						WakeUpAnim = GlobalAnimationStorage.backroll
					}
				}
			}
		}
	},

	CompoundInputs = {
		BURST = {
			Hitbox = Vector3.new(12, 4, 8),
			RelativeHitboxPos = Vector3.new(0, 0, -3),
			HitboxSpawnTimeOffset = 0.12, -- antes: 0.09
			HitboxLifetime = 0.10,        -- antes: 0.12
			Damage = 16,
			HitStun = 0.55,
			DoingCombatTime = 0.65,      -- antes: 0.38

			Knockback = {
				Enemy = {
					Profile = KnockbackProfiles.LauncherLight,

					KnockdownInfo = {
						Duration = 0.35,
						CanContinueCombo = false,
						WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
						InAirAnim = GlobalAnimationStorage.airlow,
						FallAnim = GlobalAnimationStorage.fall,
						GroundAnim = GlobalAnimationStorage.falled,
						WakeUpAnim = GlobalAnimationStorage.backroll
					}
				}
			}
		},

		CROUCHLIGHTATK = {
			Hitbox = Vector3.new(12, 4, 8),
			RelativeHitboxPos = Vector3.new(0, -0, -3),
			HitboxSpawnTimeOffset = 0.09, -- antes: 0.07
			HitboxLifetime = 0.08,        -- antes: 0.10
			Damage = 9,
			HitStun = 0.5,
			DoingCombatTime = 0.9,      -- antes: 0.35
			Knockback = {}
		},

		AIRLIGHTATK = {
			Hitbox = Vector3.new(12, 4, 8),
			RelativeHitboxPos = Vector3.new(0, -3, -3),
			HitboxSpawnTimeOffset = 0.10, -- antes: 0.07
			HitboxLifetime = 0.25,        -- antes: 0.10
			Damage = 13,
			HitStun = 0.55,
			DoingCombatTime = 0.50,      -- antes: 0.35
			Knockback = {}
		}, 

		AIRHARDATK = {
			Hitbox = Vector3.new(12, 4, 8),
			RelativeHitboxPos = Vector3.new(0, -3, -3),
			HitboxSpawnTimeOffset = 0.14, -- antes: 0.07
			HitboxLifetime = 0.25,
			Damage = 13,
			HitStun = 0.55,
			DoingCombatTime = 0.65,      -- antes: 0.35
			Knockback = {
				Enemy = {
					Profile = KnockbackProfiles.None,

					KnockdownInfo = {
						Duration = 0.35,
						CanContinueCombo = false,
						WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
						InAirAnim = GlobalAnimationStorage.airlow,
						FallAnim = GlobalAnimationStorage.fall,
						GroundAnim = GlobalAnimationStorage.falled,
						WakeUpAnim = GlobalAnimationStorage.backroll
					}
				}
			}
		}
	},

	Sequences = {
		LightAtks = {
			[1] = {
				Hitbox = Vector3.new(12, 4, 8),
				RelativeHitboxPos = Vector3.new(0, 0, -3),
				HitboxSpawnTimeOffset = 0.2, -- antes: 0.06
				HitboxLifetime = 0.08,
				Damage = 12,
				HitStun = 0.55,
				DoingCombatTime = 0.4,      -- antes: 0.28
				Knockback = {
					Enemy = {
						Profile = KnockbackProfiles.HitPush,
					},
					
					SelfAir = {
						Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackPushFront,
						HitOnly = true,
						WeldVictmin = true,
						WeldDuration = 0.6
					},
					
					Self = {
						Profile = KnockbackProfiles.None
					},

					EnemyAir = {
						Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackPushFront,

						KnockdownInfo = {
							Duration = 0.35,
							CanContinueCombo = false,
							WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							GroundAnim = GlobalAnimationStorage.falled,
							WakeUpAnim = GlobalAnimationStorage.backroll
						}
					},
				}
			},

			[2] = {
				Hitbox = Vector3.new(12, 4, 8),
				RelativeHitboxPos = Vector3.new(0, 0, -3),
				HitboxSpawnTimeOffset = 0.2, -- antes: 0.07
				HitboxLifetime = 0.08,
				Damage = 13,
				HitStun = 0.55,
				DoingCombatTime = 0.4,      -- antes: 0.30
				Knockback = {
					SelfAir = {
						Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackPushFrontUp,
						HitOnly = true,
						WeldVictmin = true,
						WeldDuration = 0.6
					},
					
					Self = {
						Profile = KnockbackProfiles.None
					},

					EnemyAir = {
						Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackPushFrontUp,

						KnockdownInfo = {
							Duration = 0.35,
							CanContinueCombo = false,
							WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							GroundAnim = GlobalAnimationStorage.falled,
							WakeUpAnim = GlobalAnimationStorage.backroll
						}
					},
					
					Enemy = {
						Profile = KnockbackProfiles.HitPush,
					}
				}
			},

			[3] = {
				Hitbox = Vector3.new(12, 4, 8),
				RelativeHitboxPos = Vector3.new(0, 0, -3),
				HitboxSpawnTimeOffset = 0.2, -- antes: 0.08
				HitboxLifetime = 0.09,
				Damage = 14,
				HitStun = 0.55,
				DoingCombatTime = 0.4,      -- antes: 0.33
				
				Knockback = {
					SelfAir = {
						Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackPushFrontDown,
						HitOnly = true,
						WeldVictmin = true,
						WeldDuration = 0.6
					},
					
					Self = {
						Profile = KnockbackProfiles.None
					},

					EnemyAir = {
						Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackPushFrontDown,

						KnockdownInfo = {
							Duration = 0.35,
							CanContinueCombo = false,
							WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							GroundAnim = GlobalAnimationStorage.falled,
							WakeUpAnim = GlobalAnimationStorage.backroll
						}
					},
					
					Enemy = {
						Profile = KnockbackProfiles.HitPull,
					}
				}
			},

			[4] = {
				Hitbox = Vector3.new(12, 4, 8),
				RelativeHitboxPos = Vector3.new(0, 0, -3),
				HitboxSpawnTimeOffset = 0.2, -- antes: 0.35 (excessivo)
				HitboxLifetime = 0.25,
				Damage = 16,
				HitStun = 0.55,	
				DoingCombatTime = 0.44,

				Knockback = {
					SelfAir = {
						Profile = KnockbackProfiles.AirCombatMaintainAirKnockback,
						HitOnly = true
					},

					EnemyAir = {
						Profile = KnockbackProfiles.AirCombatMaintainAirKnockback,

						KnockdownInfo = {
							Duration = 0.35,
							CanContinueCombo = false,
							WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							GroundAnim = GlobalAnimationStorage.falled,
							WakeUpAnim = GlobalAnimationStorage.backroll
						}
					},
					
					Enemy = {
						Profile = KnockbackProfiles.AirCombatUpKnockback,

						KnockdownInfo = {
							Duration = 0.35,
							CanContinueCombo = false,
							WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							GroundAnim = GlobalAnimationStorage.falled,
							WakeUpAnim = GlobalAnimationStorage.backroll
						}
					},
					
					Self = {
						Profile = KnockbackProfiles.AirCombatUpKnockback,
						HitOnly = true,
						WeldVictmin = true,
						WeldDuration = 0.6
					}
				}
			},
			
			[5] = {
				Hitbox = Vector3.new(12, 4, 8),
				RelativeHitboxPos = Vector3.new(0, 0, -3),
				HitboxSpawnTimeOffset = 0.25, -- antes: 0.35 (excessivo)
				HitboxLifetime = 0.25,
				Damage = 16,
				HitStun = 0.55,	
				DoingCombatTime = 0.44,

				Knockback = {
					Enemy = {
						Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackPushFrontUp,

						KnockdownInfo = {
							Duration = 0.1,
							CanContinueCombo = false,
							--WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							GroundAnim = GlobalAnimationStorage.falled,
							WakeUpAnim = nil
						}
					},

					Self = {
						Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackPushFrontUp,
						HitOnly = true
					}
				}
			},
			
			[6] = {
				Hitbox = Vector3.new(12, 4, 8),
				RelativeHitboxPos = Vector3.new(0, 0, -3),
				HitboxSpawnTimeOffset = 0.25, -- antes: 0.35 (excessivo)
				HitboxLifetime = 0.25,
				Damage = 16,
				HitStun = 0.7,	
				DoingCombatTime = 0.44,

				Knockback = {
					Enemy = {
						Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackPushFront,

						KnockdownInfo = {
							Duration = 0.1,
							CanContinueCombo = false,
							--WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							GroundAnim = GlobalAnimationStorage.falled,
							WakeUpAnim = nil
						}
					},

					Self = {
						Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackPushFront,
						HitOnly = true
					}
				}
			},
			
			[7] = {
				Hitbox = Vector3.new(12, 4, 8),
				RelativeHitboxPos = Vector3.new(0, 0, -3),
				HitboxSpawnTimeOffset = 0.24, -- antes: 0.35 (excessivo)
				HitboxLifetime = 0.25,
				Damage = 16,
				HitStun = 0.55,	
				DoingCombatTime = 0.44,

				Knockback = {
					Enemy = {
						Profile = KnockbackProfiles.LauncherDown,

						KnockdownInfo = {
							Duration = 0.35,
							CanContinueCombo = false,
							WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							GroundAnim = GlobalAnimationStorage.falled,
							WakeUpAnim = GlobalAnimationStorage.backroll
						}
					},
					
					Self = {
						Profile = KnockbackProfiles.AirCombatMaintainAirKnockback,
						HitOnly = true
					}
				}
			},
		},

		HardAtks = {
			Standing = {
				[1] = {
					Hitbox = Vector3.new(12, 4, 8),
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.35, -- antes: 0.11
					HitboxLifetime = 0.10,        -- antes: 0.12
					Damage = 20,
					HitStun = 0.55,
					DoingCombatTime = 0.7,      -- antes: 0.48
					
					
					Knockback = {					
						Enemy = {
							Profile = KnockbackProfiles.HitPush,
						},
						
						Self = {
							Profile = KnockbackProfiles.None,
						},

						SelfAir = {
							Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackExtended,
							HitOnly = true,
							WeldVictmin = true,
							WeldDuration = 0.6
						},
						
						EnemyAir = {
							Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackExtended,
	
							KnockdownInfo = {
								Duration = 0.35,
								CanContinueCombo = false,
								WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
								InAirAnim = GlobalAnimationStorage.airlow,
								FallAnim = GlobalAnimationStorage.fall,
								GroundAnim = GlobalAnimationStorage.falled,
								WakeUpAnim = GlobalAnimationStorage.backroll
							}
						}
					}
				},

				[2] = {
					Hitbox = Vector3.new(12, 4, 8),
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.15, -- antes: 0.13
					HitboxLifetime = 0.12,        -- antes: 0.14
					Damage = 23,
					HitStun = 0.55,
					DoingCombatTime = 0.5,
					
					Knockback = {
						EnemyAir = {
							Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackExtendedPushFront,

							KnockdownInfo = {
								Duration = 0.35,
								CanContinueCombo = false,
								WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
								InAirAnim = GlobalAnimationStorage.airlow,
								FallAnim = GlobalAnimationStorage.fall,
								GroundAnim = GlobalAnimationStorage.falled,
								WakeUpAnim = GlobalAnimationStorage.backroll
							}
						},

						Enemy = {
							Profile = KnockbackProfiles.HitPull,
						},

						Self = {
							Profile = KnockbackProfiles.None,
						},

						SelfAir = {
							Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackExtendedPushFront,
							HitOnly = true,
							WeldVictmin = true,
							WeldDuration = 0.6
						}
					}
				},

				[3] = {
					Hitbox = Vector3.new(12, 4, 8),
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.27, -- antes: 0.15
					HitboxLifetime = 0.14,        -- antes: 0.16
					Damage = 26,
					HitStun = 0.55,
					DoingCombatTime = 0.4,      -- antes: 0.62
					
					Knockback = {
						EnemyAir = {
							Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackExtendedPushFrontDown,
						},

						Enemy = {
							Profile = KnockbackProfiles.HitPush,
						},

						Self = {
							Profile = KnockbackProfiles.None,
						},

						SelfAir = {
							Profile = KnockbackProfiles.AirCombatMaintainAirKnockbackExtendedPushFrontDown,
							HitOnly = true,
							WeldVictmin = true,
							WeldDuration = 0.6
						}
					}
				},

				[4] = {
					Hitbox = Vector3.new(12, 4, 8),
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.25, -- antes: 0.18
					HitboxLifetime = 0.45,        -- antes: 0.18
					Damage = 32,
					HitStun = 0.55,
					DoingCombatTime = 0.7,      -- antes: 0.75

					Knockback = {
						EnemyAir = {
							Profile = KnockbackProfiles.LauncherDown,
							
							KnockdownInfo = {
								Duration = 0.35,
								CanContinueCombo = true,
								WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
								InAirAnim = GlobalAnimationStorage.airlow,
								FallAnim = GlobalAnimationStorage.fall,
								GroundAnim = GlobalAnimationStorage.falled,
								WakeUpAnim = GlobalAnimationStorage.backroll
							}
						}, 
						
						Enemy = {
							Profile = KnockbackProfiles.LauncherLight,
							
							KnockdownInfo = {
								Duration = 0.35,
								CanContinueCombo = true,
								WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
								InAirAnim = GlobalAnimationStorage.airlow,
								FallAnim = GlobalAnimationStorage.fall,
								GroundAnim = GlobalAnimationStorage.falled,
								WakeUpAnim = GlobalAnimationStorage.backroll
							}
						},
						
						Self = {
							Profile = KnockbackProfiles.None,
						},
						
						SelfAir = {
							Profile = KnockbackProfiles.AirCombatMaintainAirKnockback,
							HitOnly = true
						}
					}
				},
			},

			Crouching = {
				[1] = {
					Hitbox = Vector3.new(12, 4, 8),
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.2, -- antes: 0.13
					HitboxLifetime = 0.12,        -- antes: 0.14
					Damage = 23,
					HitStun = 0.55,
					DoingCombatTime = 0.40,

					KnockbackOnlyAir = true,

					Knockback = {
						Enemy = {
							Profile = KnockbackProfiles.AirCombatMaintainAirKnockback,

							KnockdownInfo = {
								Duration = 0.35,
								CanContinueCombo = false,
								WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
								InAirAnim = GlobalAnimationStorage.airlow,
								FallAnim = GlobalAnimationStorage.fall,
								GroundAnim = GlobalAnimationStorage.falled,
								WakeUpAnim = GlobalAnimationStorage.backroll
							}
						},

						Self = {
							Profile = KnockbackProfiles.AirCombatMaintainAirKnockback,
							HitOnly = true
						}
					}
				},

				[2] = {
					Hitbox = Vector3.new(12, 4, 8),
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.2, -- antes: 0.15
					HitboxLifetime = 0.14,        -- antes: 0.16
					Damage = 26,
					HitStun = 0.55,
					DoingCombatTime = 0.40,      -- antes: 0.62

					KnockbackOnlyAir = true,

					Knockback = {
						Enemy = {
							Profile = KnockbackProfiles.AirCombatMaintainAirKnockback,

							KnockdownInfo = {
								Duration = 0.35,
								CanContinueCombo = false,
								WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
								InAirAnim = GlobalAnimationStorage.airlow,
								FallAnim = GlobalAnimationStorage.fall,
								GroundAnim = GlobalAnimationStorage.falled,
								WakeUpAnim = GlobalAnimationStorage.backroll
							}
						},

						Self = {
							Profile = KnockbackProfiles.AirCombatMaintainAirKnockback,
							HitOnly = true
						}
					}
				},

				[3] = {
					Hitbox = Vector3.new(12, 4, 8),
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0, -- antes: 0.18
					HitboxLifetime = 0.45,        -- antes: 0.18
					Damage = 32,
					HitStun = 0.55,
					DoingCombatTime = 0.55,      -- antes: 0.75

					Knockback = {
						EnemyAir = {
							Profile = KnockbackProfiles.AirCombatMaintainAirKnockback,
						}, 

						Enemy = {
							Profile = KnockbackProfiles.SlideForwardEnemy,
						},

						Self = {
							Profile = KnockbackProfiles.SlideForward,
						},

						SelfAir = {
							Profile = KnockbackProfiles.AirCombatMaintainAirKnockback,
							HitOnly = true
						}
					}
				},

				[4] = {
					Hitbox = Vector3.new(12, 4, 8),
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.2, -- antes: 0.18
					HitboxLifetime = 0.14,        -- antes: 0.18
					Damage = 32,
					HitStun = 0.55,
					DoingCombatTime = 0.6,      -- antes: 0.75

					Knockback = {
						EnemyAir = {
							Profile = KnockbackProfiles.LauncherDown,

							KnockdownInfo = {
								Duration = 0.35,
								CanContinueCombo = true,
								WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
								InAirAnim = GlobalAnimationStorage.airlow,
								FallAnim = GlobalAnimationStorage.fall,
								GroundAnim = GlobalAnimationStorage.falled,
								WakeUpAnim = GlobalAnimationStorage.backroll
							}
						}, 

						Enemy = {
							Profile = KnockbackProfiles.None,

							KnockdownInfo = {
								Duration = 0.35,
								CanContinueCombo = true,
								WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
								InAirAnim = GlobalAnimationStorage.airlow,
								FallAnim = GlobalAnimationStorage.fall,
								GroundAnim = GlobalAnimationStorage.falled,
								WakeUpAnim = GlobalAnimationStorage.backroll
							}
						},
					}
				}
			}
		}
	},

	Combos = {
		Uppercut = {
			Combo = {'LEFT', 'CROUCH', 'RIGHT', 'LIGHTATK'},
			ComboType = 'CombatAttack',

			ComboAttack = {
				Hitbox = Vector3.new(12, 4, 8),
				RelativeHitboxPos = Vector3.new(0, -0, -3),
				HitboxSpawnTimeOffset = 0.12, -- antes: 0.07
				HitboxLifetime = 0.10,
				Damage = 30,
				HitStun = 0.55,
				DoingCombatTime = 0.2,      -- antes: 0.35
				ChargeTime = 0.9,            -- antes: 1

				Knockback = {
					Enemy = {
						Profile = KnockbackProfiles.AirCombatUpKnockback,

						--[[
						KnockdownInfo = {
							Duration = 0.25,
							CanContinueCombo = false,
							WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							WakeUpAnim = GlobalAnimationStorage.backroll
						}
						]]
					},
					
					Self = {
						Profile = KnockbackProfiles.AirCombatAttackerUpKnockback,
						HitOnly = true,
						WeldVictmin = true,
						WeldDuration = 0.6
					}
				}
			}
		},

		HardPunch = {
			Combo = {'LEFT', 'RIGHT', 'HARDATK'},
			ComboType = 'CombatAttack',

			ComboAttack = {
				Hitbox = Vector3.new(12, 4, 8),
				RelativeHitboxPos = Vector3.new(0, -0, -3),
				HitboxSpawnTimeOffset = 0.12, -- antes: 0.07
				HitboxLifetime = 0.10,
				Damage = 30,
				HitStun = 0.55,
				DoingCombatTime = 0.55,      -- antes: 0.35
				ChargeTime = 0.9,            -- antes: 1

				Knockback = {
					Enemy = {
						Profile = KnockbackProfiles.LauncherHeavy,

						KnockdownInfo = {
							Duration = 0.35,
							CanContinueCombo = false,
							WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							GroundAnim = GlobalAnimationStorage.falled,
							WakeUpAnim = GlobalAnimationStorage.backroll
						}
					}
				}
			}
		},

		DownSlide = {
			Combo = {'LEFT', 'CROUCH', 'LIGHTATK'},
			ComboType = 'CombatAttack',

			ComboAttack = {
				Hitbox = Vector3.new(12, 4, 8),
				RelativeHitboxPos = Vector3.new(0, -0, -3),
				HitboxSpawnTimeOffset = 0.12, -- antes: 0.07
				HitboxLifetime = 0.10,
				Damage = 30,
				HitStun = 0.55,
				DoingCombatTime = 0.55,      -- antes: 0.35
				ChargeTime = 0.9,            -- antes: 1

				Knockback = {
					Enemy = {
						Profile = KnockbackProfiles.AirCombatUpKnockback,

						KnockdownInfo = {
							Duration = 0.35,
							CanContinueCombo = false,
							WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							GroundAnim = GlobalAnimationStorage.falled,
							WakeUpAnim = GlobalAnimationStorage.backroll
						}
					}
				}
			}
		},

		SpinKick = {
			Combo = {'CROUCH', 'LEFT', 'RIGHT', 'LIGHTATK'},
			ComboType = 'CombatAttack',

			ComboAttack = {
				Hitbox = Vector3.new(12, 4, 8),
				RelativeHitboxPos = Vector3.new(0, -0, -3),
				HitboxSpawnTimeOffset = 0.12, -- antes: 0.07
				HitboxLifetime = 0.10,
				Damage = 30,
				HitStun = 0.55,
				DoingCombatTime = 0.55,      -- antes: 0.35
				ChargeTime = 0.9,            -- antes: 1

				Knockback = {
					Enemy = {
						Profile = KnockbackProfiles.LauncherLight,

						KnockdownInfo = {
							Duration = 0.35,
							CanContinueCombo = false,
							WakeUpKnockback = KnockbackProfiles.WakeUpBackKnockback,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							GroundAnim = GlobalAnimationStorage.falled,
							WakeUpAnim = GlobalAnimationStorage.backroll
						}
					}
				}
			}
		},
	},

	Skills = {
		Ultimate = {
			ModuleLocation = SkillStorage.Draug.Ultimate
		},
		Skill1 = {
			InputType = 'Ended',
			ModuleLocation = SkillStorage.Draug.Skill1,
			Cooldown = 8
		},
		Skill2 = {
			InputType = 'Ended',
			ModuleLocation = SkillStorage.Draug.Skill2,
			Cooldown = 8
		},
		Skill3 = {
			InputType = 'Ended',
			ModuleLocation = SkillStorage.Draug.Skill3,
			Cooldown = 8
		},
		Skill4 = {
			InputType = 'Ended',
			ModuleLocation = SkillStorage.Draug.Skill4,
			Cooldown = 8
		}
	}
}

return module