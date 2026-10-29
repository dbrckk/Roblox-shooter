local WeaponConfig = {}

WeaponConfig.Order = {
	"AssaultRifle",
	"Pistol",
	"Shotgun",
	"Sniper",
	"Knife",
}

WeaponConfig.Definitions = {
    AssaultRifle = {
        displayName = "AR-24 | Assault Rifle", kind = "Raycast", automatic = true, magazineSize = 30, reloadSeconds = 2.15,
        fireCooldown = 0.115, damage = 24, headshotDamage = 38,
        range = 440, spreadDegrees = 1.1,
        fireSoundId = "rbxasset://sounds/snap.wav", fireVolume = 0.44,
        soundLayers = {
            { soundId = "rbxasset://sounds/snap.wav", volume = 0.54, playbackSpeed = 0.92 },
            { soundId = "rbxasset://sounds/electronicpingshort.wav", volume = 0.16, playbackSpeed = 0.53 },
        },
        recoilKick = 0.085,
    },
    Shotgun = {
        displayName = "B-8 | Tactical Shotgun", kind = "Pellet", automatic = false, magazineSize = 6, reloadSeconds = 2.55,
        fireCooldown = 0.84, damage = 13, headshotDamage = 16,
        pellets = 8, spreadDegrees = 5.1, range = 115,
        fireSoundId = "rbxasset://sounds/snap.wav", fireVolume = 0.85,
        soundLayers = {
            { soundId = "rbxasset://sounds/snap.wav", volume = 0.9, playbackSpeed = 0.67 },
            { soundId = "rbxasset://sounds/bass.wav", volume = 0.34, playbackSpeed = 1.65 },
        },
        recoilKick = 0.2,
    },
	Pistol = {
		displayName = "Pistol",
        magazineSize = 14,
        reloadSeconds = 1.45,
		kind = "Raycast",
		fireCooldown = 0.22,
		damage = 36,
		headshotDamage = 100,
		range = 700,
		fireSoundId = "rbxasset://sounds/electronicpingshort.wav",
		fireVolume = 0.55,
		firePlaybackSpeed = 0.68,
		soundLayers = {
			{ soundId = "rbxasset://sounds/electronicpingshort.wav", volume = 0.62, playbackSpeed = 0.58 },
			{ soundId = "rbxasset://sounds/snap.wav", volume = 0.18, playbackSpeed = 1.35 },
		},
		recoilKick = 0.1,
	},

	Sniper = {
		displayName = "Sniper",
        magazineSize = 5,
        reloadSeconds = 2.7,
		kind = "Raycast",
		fireCooldown = 1.15,
		damage = 82,
		headshotDamage = 150,
		range = 1500,
		zoomFieldOfView = 32,
		fireSoundId = "rbxasset://sounds/bass.wav",
		fireVolume = 0.75,
		firePlaybackSpeed = 1.15,
		soundLayers = {
			{ soundId = "rbxasset://sounds/bass.wav", volume = 0.82, playbackSpeed = 1.08 },
			{ soundId = "rbxasset://sounds/electronicpingshort.wav", volume = 0.28, playbackSpeed = 0.42 },
		},
		recoilKick = 0.18,
	},

	Knife = {
		displayName = "Throwing Knife",
		kind = "Projectile",
		fireCooldown = 0.78,
		damage = 100,
		headshotDamage = 100,
		range = 290,
		projectileSpeed = 190,
		projectileLifetime = 2.1,
		fireSoundId = "rbxasset://sounds/snap.wav",
		fireVolume = 0.5,
		firePlaybackSpeed = 1.2,
		soundLayers = {
			{ soundId = "rbxasset://sounds/snap.wav", volume = 0.5, playbackSpeed = 1.15 },
			{ soundId = "rbxasset://sounds/electronicpingshort.wav", volume = 0.12, playbackSpeed = 1.8 },
		},
		recoilKick = 0.08,
	},
}

function WeaponConfig.get(weaponId)
	return WeaponConfig.Definitions[weaponId]
end

function WeaponConfig.isValid(weaponId)
	return WeaponConfig.Definitions[weaponId] ~= nil
end

return WeaponConfig
