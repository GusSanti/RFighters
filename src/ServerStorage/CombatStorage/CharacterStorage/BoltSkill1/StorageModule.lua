local module = {}

local KnockbackProfiles = require(game.ServerStorage.CombatStorage.GlobalStorage.KnockbackProfiles)

local EffectStorage = game.ReplicatedStorage.CombatStorage.Bolt.Effects

local AnimationStorage = game.ReplicatedStorage.CombatStorage.Bolt.Animations
local GlobalAnimationStorage = game.ReplicatedStorage.CombatStorage.GlobalAnimations
local GlobalSFX = game.ReplicatedStorage.CombatStorage.GlobalSFX
local CharacterStorageSFX = game.ReplicatedStorage.CombatStorage.Bolt.Sounds
local ServerStorageFolder = game.ServerStorage.CombatStorage.CharacterStorage.Bolt
local SkillStorage = game.ServerStorage.SkillStorage

module.Visuals = {
	Animations = {
		AnimateScript = AnimationStorage.Animate,

		BasicInputs = {
			CROUCH = AnimationStorage.crouch,
			BACK_DASH = AnimationStorage.backdash,
			FORWARD_DASH = AnimationStorage.dash,
			GRAB = AnimationStorage.grab,
			DOUBLE_JUMP = AnimationStorage.Jump,

			BLOCK = {
				Normal = AnimationStorage.blockmid,
				Parry = AnimationStorage.blocklow
			},

			CHARGEATK = {
				Charge = AnimationStorage.ChargeKi,
				Release = AnimationStorage.HeavyHit2
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
				[1] = AnimationStorage.Hit1,
				[2] = AnimationStorage.Hit2,
				[3] = AnimationStorage.Hit3,
				[4] = AnimationStorage.Hit4
			},

			HardAtks = {
				Standing = {
					[1] = AnimationStorage.HeavyHit1,
					[2] = AnimationStorage.HeavyHit2,
					[3] = AnimationStorage.HeavyHit3,
					[4] = AnimationStorage.HeavyHit4
				},

				Crouching = {
					[1] = AnimationStorage.Hit1,
					[2] = AnimationStorage.Hit2,
					[3] = AnimationStorage.Hit3,
					[4] = AnimationStorage.Hit4
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
				[2] = GlobalAnimationStorage.mid,
				[3] = GlobalAnimationStorage.low,
				[4] = GlobalAnimationStorage.high
			},

			HardAtks = {
				Standing = {
					[1] = GlobalAnimationStorage.mid,
					[2] = GlobalAnimationStorage.low,
					[3] = GlobalAnimationStorage.mid,
					[4] = GlobalAnimationStorage.high
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
					Effect = EffectStorage.Parry
				},

				Parry = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.Parry
				},
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
					Effect = EffectStorage.Slash
				}
			}
		},

		CompoundInputs = {
			AIRLIGHTATK = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'HumanoidRootPart',
				TargetCharacter = 'Self',
				Delay = 0,
				Effect = EffectStorage.Slash
			},

			AIRHARDATK = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'HumanoidRootPart',
				TargetCharacter = 'Self',
				Delay = 0,
				Effect = EffectStorage.Slash
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
					Effect = nil
				},
				[2] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'HumanoidRootPart',
					TargetCharacter = 'Self',
					Delay = 0,
					Effect = nil
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
					Effect = nil
				},
			},

			HardAtks = {
				Standing = {
					[1] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'HumanoidRootPart',
						TargetCharacter = 'Self',
						Delay = 0,
						Effect = nil
					},
					[2] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'HumanoidRootPart',
						TargetCharacter = 'Self',
						Delay = 0,
						Effect = nil
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
						Effect = nil
					}
				},

				Crouching = {
					[1] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'HumanoidRootPart',
						TargetCharacter = 'Self',
						Delay = 0,
						Effect = nil
					},
					[2] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'HumanoidRootPart',
						TargetCharacter = 'Self',
						Delay = 0,
						Effect = nil
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
						Effect = nil
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
				Effect = EffectStorage.HitUpLightning
			},

			AIRHARDATK = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.HitUpLightning
			},

			CROUCHLIGHTATK = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.HitUpLightning
			},

			CHARGEATK = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.HitUpLightning
			},

			BURST = {
				Type = 'Emit',
				TargetCharacterBodyPart = 'Torso',
				TargetCharacter = 'Enemy',
				Delay = 0,
				Effect = EffectStorage.HitUpLightning
			},


			Combos = {
				Uppercut = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUpLightning
				},
				HardPunch = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUpLightning
				},
				DownSlide = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUpLightning
				},
				SpinKick = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUpLightning
				}
			},

			LightAtks = {
				[1] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUpLightning
				},

				[2] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUpLightning
				},

				[3] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUpLightning
				},

				[4] = {
					Type = 'Emit',
					TargetCharacterBodyPart = 'Torso',
					TargetCharacter = 'Enemy',
					Delay = 0,
					Effect = EffectStorage.HitUpLightning
				},
			},

			HardAtks = {
				Standing = {
					[1] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.HitUpLightning
					},

					[2] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.HitUpLightning
					},

					[3] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.HitUpLightning
					},

					[4] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.HitUpLightning
					}
				},

				Crouching = {
					[1] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.HitUpLightning
					},

					[2] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.HitUpLightning
					},

					[3] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.HitUpLightning
					},

					[4] = {
						Type = 'Emit',
						TargetCharacterBodyPart = 'Torso',
						TargetCharacter = 'Enemy',
						Delay = 0,
						Effect = EffectStorage.HitUpLightning
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
					Sound = CharacterStorageSFX.Fist.swing4,
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
				Sound = CharacterStorageSFX.Fist.swing3,
				TargetCharacterBodyPart = "Torso"
			},
			CROUCHLIGHTATK = {
				Sound = CharacterStorageSFX.Fist.swing4,
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
					Sound = CharacterStorageSFX.Fist.swing4,
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
						Sound = CharacterStorageSFX.Fist.swing2,
						TargetCharacterBodyPart = "Torso"
					},
					[3] = {
						Sound = CharacterStorageSFX.Fist.swing3,
						TargetCharacterBodyPart = "Torso"
					},
					[4] = {
						Sound = CharacterStorageSFX.Fist.swing4,
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
			ParryTime = 0.12,        -- antes: 0.2
			IFrameTime = 0.18,       -- antes: 0.4
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
			Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
			RelativeHitboxPos = Vector3.new(0, -0, -3),
			HitboxSpawnTimeOffset = 0.12, -- antes: 0.07
			HitboxLifetime = 0.08,        -- antes: 0.10
			Damage = 13,
			HitStun = 1,
			DoingCombatTime = 0.55,      -- antes: 3

			GrabInfo = {
				DamageTime = 0.35, -- antes: 0.4
				ThrowAnimation = AnimationStorage.throw,
				VictimGrabbedAnimation = GlobalAnimationStorage.grabbed,

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
					C0 = CFrame.new(0, 0, -2),
					C1 = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi, 0),
					AttackerBodyPart = 'HumanoidRootPart',
					VictimBodyPart = 'HumanoidRootPart',
					Lifetime = 0.7,
				},
			},

			Knockback = {
				Enemy = {
					Profile = KnockbackProfiles.None,

					KnockdownInfo = {
						Duration = 1.5,
						CanContinueCombo = false,
						InAirAnim = GlobalAnimationStorage.airlow,
						FallAnim = GlobalAnimationStorage.fall,
						WakeUpAnim = GlobalAnimationStorage.wakeup
					}
				}
			}
		},

		CHARGEATK = {
			Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
			RelativeHitboxPos = Vector3.new(0, -0, -3),
			HitboxSpawnTimeOffset = 0.15, -- antes: 0.07
			HitboxLifetime = 0.12,        -- antes: 0.10
			MinDamage = 13,
			MaxDamage = 25,
			HitStun = 1,
			DoingCombatTime = 0.55,      -- antes: 0.35
			ChargeTime = 0.9,            -- antes: 1

			Knockback = {
				Enemy = {
					Profile = KnockbackProfiles.LauncherHeavy,

					KnockdownInfo = {
						Duration = 1.5,
						CanContinueCombo = false,
						InAirAnim = GlobalAnimationStorage.airlow,
						FallAnim = GlobalAnimationStorage.fall,
						WakeUpAnim = GlobalAnimationStorage.wakeup
					}
				}
			}
		}
	},

	CompoundInputs = {
		BURST = {
			Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
			RelativeHitboxPos = Vector3.new(0, 0, -3),
			HitboxSpawnTimeOffset = 0.12, -- antes: 0.09
			HitboxLifetime = 0.10,        -- antes: 0.12
			Damage = 16,
			HitStun = 1,
			DoingCombatTime = 0.65,      -- antes: 0.38

			Knockback = {
				Enemy = {
					Profile = KnockbackProfiles.LauncherLight,

					KnockdownInfo = {
						Duration = 1.5,
						CanContinueCombo = false,
						InAirAnim = GlobalAnimationStorage.airlow,
						FallAnim = GlobalAnimationStorage.fall,
						WakeUpAnim = GlobalAnimationStorage.wakeup
					}
				}
			}
		},

		CROUCHLIGHTATK = {
			Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
			RelativeHitboxPos = Vector3.new(0, -0, -3),
			HitboxSpawnTimeOffset = 0.09, -- antes: 0.07
			HitboxLifetime = 0.08,        -- antes: 0.10
			Damage = 9,
			HitStun = 0.5,
			DoingCombatTime = 0.9,      -- antes: 0.35
			Knockback = {}
		}, 

		AIRLIGHTATK = {
			Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
			RelativeHitboxPos = Vector3.new(0, -6, -3),
			HitboxSpawnTimeOffset = 0.10, -- antes: 0.07
			HitboxLifetime = 0.09,        -- antes: 0.10
			Damage = 13,
			HitStun = 1,
			DoingCombatTime = 0.30,      -- antes: 0.35
			Knockback = {}
		}, 

		AIRHARDATK = {
			Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
			RelativeHitboxPos = Vector3.new(0, -6, -3),
			HitboxSpawnTimeOffset = 0.14, -- antes: 0.07
			HitboxLifetime = 0.10,
			Damage = 13,
			HitStun = 1,
			DoingCombatTime = 0.45,      -- antes: 0.35
			Knockback = {
				Enemy = {
					Profile = KnockbackProfiles.None,

					KnockdownInfo = {
						Duration = 1.5,
						CanContinueCombo = false,
						InAirAnim = GlobalAnimationStorage.airlow,
						FallAnim = GlobalAnimationStorage.fall,
						WakeUpAnim = GlobalAnimationStorage.wakeup
					}
				}
			}
		}
	},

	Sequences = {
		LightAtks = {
			[1] = {
				Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
				RelativeHitboxPos = Vector3.new(0, 0, -3),
				HitboxSpawnTimeOffset = 0.09, -- antes: 0.06
				HitboxLifetime = 0.08,
				Damage = 12,
				HitStun = 1,
				DoingCombatTime = 0.24,      -- antes: 0.28
				Knockback = {}
			},

			[2] = {
				Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
				RelativeHitboxPos = Vector3.new(0, 0, -3),
				HitboxSpawnTimeOffset = 0.10, -- antes: 0.07
				HitboxLifetime = 0.08,
				Damage = 13,
				HitStun = 1,
				DoingCombatTime = 0.26,      -- antes: 0.30
				Knockback = {}
			},

			[3] = {
				Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
				RelativeHitboxPos = Vector3.new(0, 0, -3),
				HitboxSpawnTimeOffset = 0.11, -- antes: 0.08
				HitboxLifetime = 0.09,
				Damage = 14,
				HitStun = 1,
				DoingCombatTime = 0.28,      -- antes: 0.33
				Knockback = {}
			},

			[4] = {
				Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
				RelativeHitboxPos = Vector3.new(0, 0, -3),
				HitboxSpawnTimeOffset = 0.15, -- antes: 0.35 (excessivo)
				HitboxLifetime = 0.10,
				Damage = 16,
				HitStun = 1,
				DoingCombatTime = 0.38,

				Knockback = {
					Enemy = {
						Profile = KnockbackProfiles.LauncherLight,

						KnockdownInfo = {
							Duration = 1.5,
							CanContinueCombo = false,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							WakeUpAnim = GlobalAnimationStorage.wakeup
						}
					}
				}
			},
		},

		HardAtks = {
			Standing = {
				[1] = {
					Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.18, -- antes: 0.11
					HitboxLifetime = 0.10,        -- antes: 0.12
					Damage = 30,
					HitStun = 1,
					DoingCombatTime = 0.45,      -- antes: 0.48
					Knockback = {}
				},

				[2] = {
					Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.21, -- antes: 0.13
					HitboxLifetime = 0.12,        -- antes: 0.14
					Damage = 33,
					HitStun = 1,
					DoingCombatTime = 0.55,
					Knockback = {}
				},

				[3] = {
					Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.24, -- antes: 0.15
					HitboxLifetime = 0.14,        -- antes: 0.16
					Damage = 36,
					HitStun = 1,
					DoingCombatTime = 0.65,      -- antes: 0.62
					Knockback = {}
				},

				[4] = {
					Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.28, -- antes: 0.18
					HitboxLifetime = 0.16,        -- antes: 0.18
					Damage = 42,
					HitStun = 1,
					DoingCombatTime = 0.85,      -- antes: 0.75

					Knockback = {
						Enemy = {
							Profile = KnockbackProfiles.LauncherHeavy,

							KnockdownInfo = {
								Duration = 1.5,
								CanContinueCombo = false,
								InAirAnim = GlobalAnimationStorage.airlow,
								FallAnim = GlobalAnimationStorage.fall,
								WakeUpAnim = GlobalAnimationStorage.wakeup
							}
						}
					}
				}
			},

			Crouching = {
				[1] = {
					Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.18, -- antes: 0.11
					HitboxLifetime = 0.10,        -- antes: 0.12
					Damage = 30,
					HitStun = 1,
					DoingCombatTime = 0.45,
					Knockback = {}
				},

				[2] = {
					Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.21, -- antes: 0.13
					HitboxLifetime = 0.12,        -- antes: 0.14
					Damage = 33,
					HitStun = 1,
					DoingCombatTime = 0.55,
					Knockback = {}
				},

				[3] = {
					Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.24, -- antes: 0.15
					HitboxLifetime = 0.12,        -- antes: 0.5 (bug/abuso)
					Damage = 36,
					HitStun = 1,
					DoingCombatTime = 0.65,

					Knockback = {
						-- Self / Enemy mantidos comentados conforme original
					}
				},

				[4] = {
					Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
					RelativeHitboxPos = Vector3.new(0, 0, -3),
					HitboxSpawnTimeOffset = 0.28, -- antes: 0.18
					HitboxLifetime = 0.16,        -- antes: 0.18
					Damage = 42,
					HitStun = 1,
					DoingCombatTime = 0.85,

					Knockback = {
						Enemy = {
							Profile = KnockbackProfiles.LauncherHeavy,

							KnockdownInfo = {
								Duration = 1.5,
								CanContinueCombo = false,
								InAirAnim = GlobalAnimationStorage.airlow,
								FallAnim = GlobalAnimationStorage.fall,
								WakeUpAnim = GlobalAnimationStorage.wakeup
							}
						}
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
				Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
				RelativeHitboxPos = Vector3.new(0, -0, -3),
				HitboxSpawnTimeOffset = 0.12, -- antes: 0.07
				HitboxLifetime = 0.10,
				Damage = 30,
				HitStun = 1,
				DoingCombatTime = 0.55,      -- antes: 0.35
				ChargeTime = 0.9,            -- antes: 1

				Knockback = {
					Enemy = {
						Profile = KnockbackProfiles.LauncherHeavy,

						KnockdownInfo = {
							Duration = 1.5,
							CanContinueCombo = false,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							WakeUpAnim = GlobalAnimationStorage.wakeup
						}
					}
				}
			}
		},

		HardPunch = {
			Combo = {'LEFT', 'RIGHT', 'HARDATK'},
			ComboType = 'CombatAttack',

			ComboAttack = {
				Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
				RelativeHitboxPos = Vector3.new(0, -0, -3),
				HitboxSpawnTimeOffset = 0.12, -- antes: 0.07
				HitboxLifetime = 0.10,
				Damage = 30,
				HitStun = 1,
				DoingCombatTime = 0.55,      -- antes: 0.35
				ChargeTime = 0.9,            -- antes: 1

				Knockback = {
					Enemy = {
						Profile = KnockbackProfiles.LauncherHeavy,

						KnockdownInfo = {
							Duration = 1.5,
							CanContinueCombo = false,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							WakeUpAnim = GlobalAnimationStorage.wakeup
						}
					}
				}
			}
		},

		DownSlide = {
			Combo = {'LEFT', 'CROUCH', 'CROUCH', 'LIGHTATK'},
			ComboType = 'CombatAttack',

			ComboAttack = {
				Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
				RelativeHitboxPos = Vector3.new(0, -0, -3),
				HitboxSpawnTimeOffset = 0.12, -- antes: 0.07
				HitboxLifetime = 0.10,
				Damage = 30,
				HitStun = 1,
				DoingCombatTime = 0.55,      -- antes: 0.35
				ChargeTime = 0.9,            -- antes: 1

				Knockback = {
					Enemy = {
						Profile = KnockbackProfiles.LauncherHeavy,

						KnockdownInfo = {
							Duration = 1.5,
							CanContinueCombo = false,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							WakeUpAnim = GlobalAnimationStorage.wakeup
						}
					}
				}
			}
		},

		SpinKick = {
			Combo = {'LIGHTATK', 'CROUCH', 'LEFT', 'RIGHT', 'LIGHTATK'},
			ComboType = 'CombatAttack',

			ComboAttack = {
				Hitbox = ServerStorageFolder.Hitboxes.LightAtks['1'],
				RelativeHitboxPos = Vector3.new(0, -0, -3),
				HitboxSpawnTimeOffset = 0.12, -- antes: 0.07
				HitboxLifetime = 0.10,
				Damage = 30,
				HitStun = 1,
				DoingCombatTime = 0.55,      -- antes: 0.35
				ChargeTime = 0.9,            -- antes: 1

				Knockback = {
					Enemy = {
						Profile = KnockbackProfiles.LauncherHeavy,

						KnockdownInfo = {
							Duration = 1.5,
							CanContinueCombo = false,
							InAirAnim = GlobalAnimationStorage.airlow,
							FallAnim = GlobalAnimationStorage.fall,
							WakeUpAnim = GlobalAnimationStorage.wakeup
						}
					}
				}
			}
		},
	},

	Skills = {
		Ultimate = {
			ModuleLocation = SkillStorage.Bolt.Ultimate
		},
		Skill1 = {
			InputType = 'Ended',
			ModuleLocation = SkillStorage.Bolt.Skill4,
			Cooldown = 8
		},
		Skill2 = {
			InputType = 'Ended',
			ModuleLocation = SkillStorage.Bolt.Skill2,
			Cooldown = 8
		},
		Skill3 = {
			InputType = 'Ended',
			ModuleLocation = SkillStorage.Bolt.Skill3,
			Cooldown = 8
		},
		Skill4 = {
			InputType = 'Ended',
			ModuleLocation = SkillStorage.Bolt.Skill4,
			Cooldown = 8
		}
	}
}

return module